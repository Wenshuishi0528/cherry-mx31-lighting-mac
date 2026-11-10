import Foundation
import IOKit.hid

private final class HIDInbox {
    var replies: [[UInt8]] = []
}

private final class ReportBuffer {
    let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    deinit { pointer.deallocate() }
}

final class HIDSession {
    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let storage = ReportBuffer()
    private var buffer: UnsafeMutablePointer<UInt8> { storage.pointer }
    private let inbox = HIDInbox()
    private var opened = false
    private var scheduled = false
    private var transactionOpen = false

    init() throws {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x046a, kIOHIDProductIDKey: 0x01d7] as CFDictionary)
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        guard let control = devices.first(where: {
            (IOHIDDeviceGetProperty($0, kIOHIDMaxOutputReportSizeKey as CFString) as? NSNumber)?.intValue == 64
        }) else {
            throw KeyboardError.message("未找到 CHERRY MX 3.1 RGB，请检查 USB 连接后重新连接。")
        }
        device = control
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw KeyboardError.message(String(format: "无法打开键盘（0x%08X）。如系统要求，请在「系统设置 → 隐私与安全性 → 输入监控」允许键盘灯控，然后重启软件。", result))
        }
        opened = true
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, result, _, _, reportID, bytes, count in
            // Ignore keyboard and consumer input completely; collect vendor replies only.
            guard let context, result == kIOReturnSuccess, reportID == 4, count == 64 else { return }
            let inbox = Unmanaged<HIDInbox>.fromOpaque(context).takeUnretainedValue()
            inbox.replies.append(Array(UnsafeBufferPointer(start: bytes, count: count)))
        }, Unmanaged.passUnretained(inbox).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        scheduled = true
    }

    deinit {
        if scheduled {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, nil, nil)
        }
        if opened { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
    }

    @discardableResult private func exchange(_ op: UInt8, _ payload: [UInt8]) throws -> [UInt8] {
        inbox.replies.removeAll()
        let request = try CherryPacket.make(op: op, payload: payload)
        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 4, request, request.count)
        guard result == kIOReturnSuccess else {
            throw KeyboardError.message(String(format: "USB 写入失败（0x%08X）。请检查键盘连接。", result))
        }
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.01, true)
            while !inbox.replies.isEmpty {
                let reply = inbox.replies.removeFirst()
                guard reply[3] == op, Array(reply[4..<7]) == Array(request[4..<7]) else { continue }
                try CherryPacket.validate(reply, request: request)
                return reply
            }
        }
        throw KeyboardError.message("键盘应答超时，操作结果未确认。请重新读取后再操作。")
    }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        try exchange(1, CherryPacket.start)
        transactionOpen = true
        do {
            let result = try operation()
            // Clear before sending: a lost END acknowledgement must not cause a duplicate END.
            transactionOpen = false
            try exchange(2, CherryPacket.start)
            return result
        } catch {
            let original = error
            if transactionOpen {
                transactionOpen = false
                do { try exchange(2, CherryPacket.start) }
                catch { throw KeyboardError.message("\(original.localizedDescription)\n结束控制会话也失败，请拔插键盘后重新读取。") }
            }
            throw original
        }
    }

    private func activeProfile() throws -> UInt8 {
        let profile = try exchange(5, CherryPacket.activeProfile)[8]
        guard profile < 3 else { throw KeyboardError.message("无法确认键盘当前的板载配置。") }
        return profile
    }
    private func readInsideTransaction() throws -> LightingState {
        let profile = try activeProfile()
        let response = try exchange(5, CherryPacket.lightingHeader(profile: profile))
        guard try activeProfile() == profile else { throw KeyboardError.message("读取期间板载配置发生切换，请重新读取。") }
        return try LightingState(bytes: Array(response[8..<16]), profileIndex: profile)
    }
    func readLighting() throws -> LightingState { try transaction { try readInsideTransaction() } }

    func readAllLightingPages() throws -> [[UInt8]] {
        try transaction {
            let selected = try activeProfile()
            var pages: [[UInt8]] = []
            for profile in 0..<3 {
                var page: [UInt8] = []
                for offset in [0, 56] {
                    let count = min(56, 64 - offset)
                    let address = profile * 64 + offset
                    let reply = try exchange(5, [UInt8(count), UInt8(address), 0, 0])
                    page += reply[8..<(8 + count)]
                }
                pages.append(page)
            }
            guard try activeProfile() == selected else { throw KeyboardError.message("备份期间板载配置发生切换，请重新读取。") }
            return pages
        }
    }

    func writeLighting(mode: UInt8, brightness: Int, speed: Int, hex: String) throws -> (LightingState, LightingState) {
        // Read fresh state to preserve firmware-owned flags and obtain an undo snapshot.
        let before = try readLighting()
        let desired = try before.replacing(mode: mode, brightness: brightness, speed: speed, hex: hex)
        try transaction {
            guard try activeProfile() == before.profileIndex else { throw KeyboardError.message("板载配置已切换，未发送灯光修改，请重新读取。") }
            _ = try exchange(6, CherryPacket.lightingHeader(profile: before.profileIndex, writing: true) + desired.bytes)
        }
        let after = try readLighting()
        guard after == desired else {
            throw KeyboardError.message("已发送设置，但键盘读回值不一致。请重新读取；当前状态可能已部分改变。")
        }
        return (before, after)
    }

    func restore(_ state: LightingState) throws -> LightingState {
        try transaction {
            guard try activeProfile() == state.profileIndex else { throw KeyboardError.message("请先将键盘切回第 \(Int(state.profileIndex) + 1) 套板载配置，再恢复这份设置。") }
            _ = try exchange(6, CherryPacket.lightingHeader(profile: state.profileIndex, writing: true) + state.bytes)
        }
        let actual = try readLighting()
        guard actual == state else { throw KeyboardError.message("恢复后的读回值不一致，请重新读取。") }
        return actual
    }
}
