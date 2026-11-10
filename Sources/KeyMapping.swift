import Foundation

struct KeyPair: Codable, Equatable {
    let source: UInt64
    let destination: UInt64
    var dictionary: [String: UInt64] {
        ["HIDKeyboardModifierMappingSrc": source, "HIDKeyboardModifierMappingDst": destination]
    }
}

enum KeyMapping {
    static let usageBase: UInt64 = 0x700000000
    static let managedSources: Set<UInt64> = [0x39, 0xe2, 0xe3, 0xe6, 0xe7].map { usageBase + $0 }.reduce(into: []) { $0.insert($1) }
    static let matching = "{\"VendorID\":1130,\"ProductID\":471}"

    static func run(_ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = arguments
        let output = Pipe(); let error = Pipe()
        task.standardOutput = output; task.standardError = error
        try task.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errors = error.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw KeyboardError.message("按键设置失败：\(String(data: errors, encoding: .utf8) ?? "hidutil 错误")")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func read() throws -> [KeyPair] {
        let text = try run(["property", "--matching", matching, "--get", "UserKeyMapping"])
        return try parse(text)
    }

    static func parse(_ text: String) throws -> [KeyPair] {
        let rows = try NSRegularExpression(pattern: "(?m)^\\s*[0-9a-fA-F]+\\s+UserKeyMapping\\s+").matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !rows.isEmpty else { throw KeyboardError.message("未找到键盘的系统映射，请重新连接。") }
        var serviceMappings: [[KeyPair]] = []
        for (index, row) in rows.enumerated() {
            let start = row.range.location + row.range.length
            let end = index + 1 < rows.count ? rows[index + 1].range.location : (text as NSString).length
            let section = (text as NSString).substring(with: NSRange(location: start, length: end - start))
            serviceMappings.append(try parseService(section))
        }
        guard let result = serviceMappings.first, serviceMappings.allSatisfy({ $0 == result }) else {
            throw KeyboardError.message("键盘接口的现有映射不同，请先在系统设置中统一后再调整。")
        }
        return result
    }

    private static func parseService(_ text: String) throws -> [KeyPair] {
        let regex = try NSRegularExpression(pattern: "HIDKeyboardModifierMapping(Src|Dst)\\\"?\\s*=\\s*(0[xX][0-9a-fA-F]+|[0-9]+)")
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        if matches.isEmpty {
            let compact = text.filter { !$0.isWhitespace }
            guard compact == "(null)" || compact == "()" else { throw KeyboardError.message("无法识别键盘现有的按键映射。") }
            return []
        }
        // hidutil prints an entry for each matching service. They must agree before editing.
        var sources: [UInt64] = [], destinations: [UInt64] = []
        for match in matches {
            let kind = String(text[Range(match.range(at: 1), in: text)!])
            let raw = String(text[Range(match.range(at: 2), in: text)!])
            let number = raw.lowercased().hasPrefix("0x") ? UInt64(raw.dropFirst(2), radix: 16) : UInt64(raw)
            guard let number else { throw KeyboardError.message("按键映射包含无法识别的值。") }
            if kind == "Src" { sources.append(number) } else { destinations.append(number) }
        }
        guard sources.count == destinations.count else { throw KeyboardError.message("按键映射数据不完整。") }
        var result: [KeyPair] = []
        for (source, destination) in zip(sources, destinations) {
            let pair = KeyPair(source: source, destination: destination)
            if let existing = result.first(where: { $0.source == source }) {
                guard existing == pair else { throw KeyboardError.message("键盘接口的现有映射不同，请先在系统设置中统一后再调整。") }
            } else { result.append(pair) }
        }
        return result.sorted { $0.source < $1.source }
    }

    static func make(existing: [KeyPair], swap: Bool, caps: Int) -> [KeyPair] {
        var result = existing.filter { !managedSources.contains($0.source) }
        if swap {
            result += [KeyPair(source: usageBase + 0xe2, destination: usageBase + 0xe3),
                       KeyPair(source: usageBase + 0xe3, destination: usageBase + 0xe2),
                       KeyPair(source: usageBase + 0xe6, destination: usageBase + 0xe7),
                       KeyPair(source: usageBase + 0xe7, destination: usageBase + 0xe6)]
        }
        if caps == 1 { result.append(KeyPair(source: usageBase + 0x39, destination: usageBase + 0x29)) }
        if caps == 2 { result.append(KeyPair(source: usageBase + 0x39, destination: usageBase + 0xe0)) }
        return result.sorted { $0.source < $1.source }
    }

    static func write(_ pairs: [KeyPair]) throws {
        let data = try JSONSerialization.data(withJSONObject: ["UserKeyMapping": pairs.map(\.dictionary)], options: [.sortedKeys])
        _ = try run(["property", "--matching", matching, "--set", String(decoding: data, as: UTF8.self)])
        guard try read() == pairs.sorted(by: { $0.source < $1.source }) else {
            throw KeyboardError.message("映射已发送，但系统读回值不一致。请重新读取后检查。")
        }
    }
}
