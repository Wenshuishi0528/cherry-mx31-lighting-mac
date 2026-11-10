import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class AppModel: ObservableObject {
    @Published var connected = false
    @Published var busy = false
    @Published var status = "正在读取键盘…"
    @Published var isError = false
    @Published var state: LightingState?
    @Published var mode: UInt8 = 3
    @Published var brightness: Double = 2
    @Published var speed: Double = 2
    @Published var color = Color(red: 1, green: 0.87, blue: 0.69)
    @Published var hex = "FFDDB0"
    @Published var rainbow = false
    @Published var profiles: [LightProfile] = []
    @Published var profileName = "我的配置"
    @Published var swapModifiers = false
    @Published var capsMode = 0
    @Published var keyStatus = "读取后可调整 Cmd / Option 和 Caps Lock。"
    @Published var undoState: LightingState?
    @Published var undoMappings: [KeyPair]?
    private var currentMappings: [KeyPair]?
    private let worker = DispatchQueue(label: "local.keyboard-lights.usb")
    private let profilesURL: URL
    private let backupURL: URL

    var effect: LightEffect? { LightEffect.all.first { $0.id == mode } }
    var canEditKeys: Bool { connected && currentMappings != nil && !busy }
    var displaysRainbow: Bool { rainbow || effect?.usesColor == false }
    var dirty: Bool {
        guard let state else { return false }
        return state.mode != mode || Int(state.brightness) != Int(brightness) || Int(state.speed) != 4 - Int(speed) || state.rainbow != rainbow || state.hex != hex.uppercased().replacingOccurrences(of: "#", with: "")
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("KeyboardLights", isDirectory: true)
        profilesURL = base.appendingPathComponent("profiles.json")
        backupURL = base.appendingPathComponent("last-lighting-backup.json")
        do { try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true) }
        catch { status = "无法创建配置目录：\(error.localizedDescription)"; isError = true }
        if let data = try? Data(contentsOf: profilesURL), let loaded = try? JSONDecoder().decode([LightProfile].self, from: data) {
            profiles = loaded.filter(\.valid)
        } else { profiles = LightProfile.examples }
        if let data = try? Data(contentsOf: backupURL), let saved = try? JSONDecoder().decode(LightingState.self, from: data), saved.bytes.count == 8 { undoState = saved }
    }

    private func adopt(_ state: LightingState) {
        self.state = state; connected = true
        mode = state.mode; brightness = Double(state.brightness); speed = Double(4 - state.speed)
        rainbow = state.rainbow
        setHex(state.hex)
    }
    func setHex(_ value: String) {
        guard let rgb = LightingState.rgb(value) else { return }
        hex = rgb.map { String(format: "%02X", $0) }.joined()
        color = Color(.sRGB, red: Double(rgb[0]) / 255, green: Double(rgb[1]) / 255, blue: Double(rgb[2]) / 255)
    }
    func colorChanged(_ value: Color) {
        guard let c = NSColor(value).usingColorSpace(.sRGB) else { return }
        hex = [c.redComponent, c.greenComponent, c.blueComponent].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }
    func selectEffect(_ value: UInt8) {
        mode = value
        if effect?.usesColor == false { rainbow = true }
        if mode == 3 { rainbow = false }
    }
    func setColorful(_ enabled: Bool) {
        guard !busy else { return }
        rainbow = enabled
        if enabled && (mode == 3 || effect == nil) { mode = 0 }
        if !enabled && effect?.usesColor == false { mode = 3 }
        isError = false
        status = enabled ? "已选择彩色灯光；点击「应用到键盘」生效。" : "已选择单色灯光；点击「应用到键盘」生效。"
    }
    func randomizeColor() {
        guard !busy else { return }
        let previous = hex.uppercased()
        var next: String
        repeat {
            let generated = NSColor(calibratedHue: Double.random(in: 0..<1), saturation: Double.random(in: 0.5...0.9), brightness: Double.random(in: 0.75...1), alpha: 1).usingColorSpace(.sRGB)!
            next = [generated.redComponent, generated.greenComponent, generated.blueComponent].map {
                String(format: "%02X", Int(($0 * 255).rounded()))
            }.joined()
        } while next == previous
        let changedMode = effect?.usesColor != true
        if changedMode { mode = 3 }
        rainbow = false
        setHex(next)
        isError = false
        status = "已随机选择单色 #\(next)\(changedMode ? "，并选择常亮灯效" : "")；点击「应用到键盘」生效。"
    }
    private func begin(_ message: String) -> Bool {
        guard !busy else { return false }
        busy = true; status = message; isError = false
        return true
    }
    private func fail(_ error: Error) {
        busy = false; isError = true; status = error.localizedDescription
    }

    func refresh() {
        guard begin("正在读取键盘当前设置…") else { return }
        worker.async {
            do {
                let session = try HIDSession()
                let state = try session.readLighting()
                let initialBackup = self.backupURL.deletingLastPathComponent().appendingPathComponent("board-lighting-initial.json")
                if !FileManager.default.fileExists(atPath: initialBackup.path) {
                    let pages = try session.readAllLightingPages()
                    try JSONEncoder().encode(pages).write(to: initialBackup, options: .atomic)
                }
                let mappings = try? KeyMapping.read()
                DispatchQueue.main.async {
                    self.adopt(state); self.busy = false; self.status = "已读取当前第 \(Int(state.profileIndex) + 1) 套板载配置"
                    self.currentMappings = mappings
                    if let mappings {
                        let base = KeyMapping.usageBase
                        self.swapModifiers = [UInt64(0xe2), 0xe3, 0xe6, 0xe7].allSatisfy { code in
                            mappings.contains(KeyPair(source: base + code, destination: base + (code ^ 1)))
                        }
                        let target = mappings.first { $0.source == base + 0x39 }?.destination
                        self.capsMode = target == base + 0x29 ? 1 : target == base + 0xe0 ? 2 : 0
                        self.keyStatus = mappings.isEmpty ? "当前没有 hidutil 自定义映射。" : "已读取 \(mappings.count) 条系统映射。"
                    } else { self.keyStatus = "现有映射读取失败，重新连接后再试。" }
                }
            } catch { DispatchQueue.main.async { self.connected = false; self.fail(error) } }
        }
    }

    func apply(off: Bool = false) {
        guard connected, let snapshot = state, begin(off ? "正在关闭背光…" : "正在应用并读回检查…") else { return }
        let mode = off ? snapshot.mode : self.mode
        let brightness = off ? 0 : Int(self.brightness)
        let speed = off ? Int(snapshot.speed) : 4 - Int(self.speed)
        let hex = off ? snapshot.hex : self.hex
        let rainbow = off ? snapshot.rainbow : self.rainbow
        worker.async {
            do {
                // Persist the latest known state before any change, including on a later failure.
                let session = try HIDSession()
                let before = try session.readLighting()
                guard before.profileIndex == snapshot.profileIndex else {
                    throw KeyboardError.message("板载配置已切换，未发送修改。请重新读取后再应用。")
                }
                try JSONEncoder().encode(before).write(to: self.backupURL, options: .atomic)
                DispatchQueue.main.async { self.undoState = before }
                let (_, after) = try session.writeLighting(mode: mode, brightness: brightness, speed: speed, hex: hex, rainbow: rainbow, expectedProfileIndex: snapshot.profileIndex)
                DispatchQueue.main.async {
                    self.adopt(after); self.busy = false
                    self.status = "\(off ? "关闭背光设置" : "灯光设置")已写入当前配置 · 读回一致，请核对实物"
                }
            } catch { DispatchQueue.main.async { self.fail(error) } }
        }
    }

    func undo() {
        guard let backup = undoState, begin("正在恢复上次灯光设置…") else { return }
        worker.async {
            do {
                let after = try HIDSession().restore(backup)
                DispatchQueue.main.async { self.adopt(after); self.busy = false; self.status = "已恢复上次灯光设置 · 已读回核对" }
            } catch { DispatchQueue.main.async { self.fail(error) } }
        }
    }

    func applyKeys() {
        guard connected, currentMappings != nil, begin("正在应用键盘映射…") else { return }
        let swap = swapModifiers; let caps = capsMode
        worker.async {
            do {
                let existing = try KeyMapping.read()
                let desired = KeyMapping.make(existing: existing, swap: swap, caps: caps)
                // Save the exact previous map before changing the OS, even if readback fails.
                DispatchQueue.main.async { self.undoMappings = existing }
                try KeyMapping.write(desired)
                DispatchQueue.main.async {
                    self.currentMappings = desired; self.busy = false; self.status = "按键映射已应用 · 已读回核对"
                    self.keyStatus = "作用于这把 CHERRY 键盘；拔插或重启后需重新应用。"
                }
            } catch { DispatchQueue.main.async { self.fail(error) } }
        }
    }
    func undoKeys() {
        guard let pairs = undoMappings, connected, begin("正在还原按键映射…") else { return }
        worker.async {
            do {
                try KeyMapping.write(pairs)
                DispatchQueue.main.async { self.busy = false; self.refresh() }
            } catch { DispatchQueue.main.async { self.fail(error) } }
        }
    }

    func load(_ profile: LightProfile) {
        mode = profile.mode; brightness = Double(profile.brightness); speed = Double(4 - profile.speed)
        rainbow = profile.rainbow
        setHex(profile.hex); status = "已载入「\(profile.name)」，点击应用写入键盘。"; isError = false
    }
    func saveProfile() {
        let profile = LightProfile(name: profileName.trimmingCharacters(in: .whitespacesAndNewlines), mode: mode, brightness: Int(brightness), speed: 4 - Int(speed), hex: hex, rainbow: rainbow)
        guard profile.valid else { fail(KeyboardError.message("请输入配置名称，并检查颜色值。")); return }
        var updated = profiles
        if let i = updated.firstIndex(where: { $0.name == profile.name }) { updated[i] = profile } else { updated.append(profile) }
        persistProfiles(updated)
    }
    func deleteProfile(_ profile: LightProfile) { persistProfiles(profiles.filter { $0.id != profile.id }) }
    private func persistProfiles(_ updated: [LightProfile]) {
        do { try JSONEncoder().encode(updated).write(to: profilesURL, options: .atomic); profiles = updated; status = "配置已保存到这台 Mac"; isError = false }
        catch { fail(error) }
    }
    func exportProfiles() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "键盘灯光配置.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(profiles).write(to: url, options: .atomic)
            status = "配置已导出"; isError = false
        } catch { fail(error) }
    }
    func importProfiles() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 1_000_000 else { throw KeyboardError.message("配置文件过大。") }
            let imported = try JSONDecoder().decode([LightProfile].self, from: Data(contentsOf: url))
            guard !imported.isEmpty, imported.count <= 200, imported.allSatisfy(\.valid) else { throw KeyboardError.message("配置文件包含不受支持的设置。") }
            var merged = profiles
            for var profile in imported { profile.id = UUID(); merged.append(profile) }
            persistProfiles(merged)
        } catch { fail(error) }
    }
    func openInputSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
}
