import Foundation

enum KeyboardError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

struct LightEffect: Identifiable, Hashable {
    let id: UInt8
    let name: String
    let symbol: String
    let detail: String
    var usesColor: Bool { ![0x01, 0x0a].contains(id) }
    var usesSpeed: Bool { id != 0x03 }
    static let all: [LightEffect] = [
        .init(id: 0x00, name: "波浪", symbol: "water.waves", detail: "让色彩沿键盘流动"),
        .init(id: 0x01, name: "光谱循环", symbol: "circle.lefthalf.filled", detail: "整个键盘缓缓变换色彩"),
        .init(id: 0x02, name: "呼吸", symbol: "wind", detail: "柔和地亮起与淡出"),
        .init(id: 0x03, name: "常亮", symbol: "sun.max", detail: "用一种颜色点亮键盘"),
        .init(id: 0x0a, name: "滚动", symbol: "arrow.right", detail: "连续滚动的动态光效"),
        .init(id: 0x0c, name: "曲线", symbol: "waveform.path", detail: "沿曲线变化的动态光效"),
        .init(id: 0x0f, name: "扫描", symbol: "viewfinder", detail: "扫描式背光"),
        .init(id: 0x12, name: "放射", symbol: "rays", detail: "由中心向外扩散"),
        .init(id: 0x13, name: "涟漪", symbol: "dot.radiowaves.left.and.right", detail: "按键触发扩散的光波"),
        .init(id: 0x15, name: "单键响应", symbol: "keyboard", detail: "随按键亮起的背光")
    ]
}

struct LightingState: Codable, Equatable {
    // Two undocumented bytes are preserved from the device on every write.
    var bytes: [UInt8]
    var profileIndex: UInt8
    init(bytes: [UInt8], profileIndex: UInt8 = 0) throws {
        guard bytes.count == 8, bytes[1] <= 4, bytes[2] <= 4, profileIndex < 3 else {
            throw KeyboardError.message("键盘返回的灯光数据不符合预期，已停止操作。")
        }
        self.bytes = bytes
        self.profileIndex = profileIndex
    }
    private enum CodingKeys: String, CodingKey { case bytes, profileIndex }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(bytes: container.decode([UInt8].self, forKey: .bytes), profileIndex: container.decodeIfPresent(UInt8.self, forKey: .profileIndex) ?? 0)
    }
    var mode: UInt8 { get { bytes[0] } set { bytes[0] = newValue } }
    var brightness: UInt8 { get { bytes[1] } set { bytes[1] = newValue } }
    var speed: UInt8 { get { bytes[2] } set { bytes[2] = newValue } }
    var hex: String { bytes[5...7].map { String(format: "%02X", $0) }.joined() }
    func replacing(mode: UInt8, brightness: Int, speed: Int, hex: String) throws -> LightingState {
        guard (mode == self.mode || LightEffect.all.contains(where: { $0.id == mode })), (0...4).contains(brightness),
              (0...4).contains(speed), let rgb = Self.rgb(hex) else {
            throw KeyboardError.message("请检查灯效、亮度、速度和六位颜色值。")
        }
        var value = self
        value.mode = mode; value.brightness = UInt8(brightness); value.speed = UInt8(speed)
        value.bytes.replaceSubrange(5...7, with: rgb)
        return value
    }
    static func rgb(_ text: String) -> [UInt8]? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard value.count == 6, value.allSatisfy({ $0.isASCII && $0.isHexDigit }), let number = UInt32(value, radix: 16) else { return nil }
        return [UInt8((number >> 16) & 255), UInt8((number >> 8) & 255), UInt8(number & 255)]
    }
}

enum CherryPacket {
    static let size = 64
    static func make(op: UInt8, payload: [UInt8]) throws -> [UInt8] {
        guard payload.count <= 60 else { throw KeyboardError.message("控制报文过长。") }
        var packet = [UInt8](repeating: 0, count: size)
        packet[0] = 4; packet[3] = op
        packet.replaceSubrange(4..<(4 + payload.count), with: payload)
        let sum = Int(op) + payload.reduce(0) { $0 + Int($1) }
        packet[1] = UInt8(sum & 255); packet[2] = UInt8((sum >> 8) & 255)
        return packet
    }
    static func validate(_ response: [UInt8], request: [UInt8]) throws {
        guard response.count == size, request.count == size,
              response[0] == 4, response[3] == request[3],
              Array(response[4..<7]) == Array(request[4..<7]) else {
            throw KeyboardError.message("键盘返回了不匹配的应答，操作未确认。")
        }
        guard response[7] != 0xfe, response[7] != 0xff else { throw KeyboardError.message("键盘拒绝了这条控制指令。") }
        guard response[7] == request[7] else { throw KeyboardError.message("键盘应答状态与请求不符，操作未确认。") }
        // Read replies include data but their checksum covers only the request header.
        let end = response[3] == 5 ? 8 : 64
        let sum = Int(response[3]) + response[4..<end].reduce(0) { $0 + Int($1) }
        guard Int(response[1]) | (Int(response[2]) << 8) == sum else {
            throw KeyboardError.message("键盘应答校验失败，操作未确认。")
        }
    }
    static let start: [UInt8] = [0, 0, 0, 0]
    static let mainLighting: [UInt8] = [8, 1, 0, 0x55]
    static let activeProfile: [UInt8] = [1, 0, 0, 0]
    static func lightingHeader(profile: UInt8, writing: Bool = false) throws -> [UInt8] {
        guard profile < 3 else { throw KeyboardError.message("键盘返回的板载配置编号超出范围。") }
        return [8, profile * 64 + 1, 0, writing ? 0x55 : 0]
    }
}

struct LightProfile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var mode: UInt8
    var brightness: Int
    var speed: Int
    var hex: String
    var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        LightEffect.all.contains { $0.id == mode } && (0...4).contains(brightness) &&
        (0...4).contains(speed) && LightingState.rgb(hex) != nil
    }
    static let examples: [LightProfile] = [
        .init(name: "暖白工作", mode: 3, brightness: 2, speed: 2, hex: "FFDDB0"),
        .init(name: "薄荷呼吸", mode: 2, brightness: 2, speed: 3, hex: "66E3C4"),
        .init(name: "彩虹流动", mode: 0, brightness: 3, speed: 2, hex: "FF6B91")
    ]
}
