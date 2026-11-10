import SwiftUI

private struct PreviewKey {
    var label: String
    var x: Double
    var y: Double
    var width: Double = 1
    var height: Double = 1
}

struct KeyboardPreview: View {
    let color: Color
    let mode: UInt8
    let brightness: Double
    private var keys: [PreviewKey] {
        var keys = [PreviewKey(label: "esc", x: 0, y: 0)]
        for index in 0..<12 { keys.append(.init(label: "F\(index + 1)", x: Double(index) + 2 + Double(index / 4) * 0.5, y: 0)) }
        for (index, label) in ["Prt", "Scr", "Pau"].enumerated() { keys.append(.init(label: label, x: 15.5 + Double(index), y: 0)) }
        let rows: [[(String, Double)]] = [
            [("`",1),("1",1),("2",1),("3",1),("4",1),("5",1),("6",1),("7",1),("8",1),("9",1),("0",1),("−",1),("=",1),("delete",2)],
            [("tab",1.5),("Q",1),("W",1),("E",1),("R",1),("T",1),("Y",1),("U",1),("I",1),("O",1),("P",1),("[",1),("]",1),("\\",1.5)],
            [("caps",1.75),("A",1),("S",1),("D",1),("F",1),("G",1),("H",1),("J",1),("K",1),("L",1),(";",1),("'",1),("return",2.25)],
            [("shift",2.25),("Z",1),("X",1),("C",1),("V",1),("B",1),("N",1),("M",1),(",",1),(".",1),("/",1),("shift",2.75)],
            [("ctrl",1.25),("win",1.25),("alt",1.25),("",6.25),("alt",1.25),("win",1.25),("fn",1.25),("ctrl",1.25)]
        ]
        for (row, labels) in rows.enumerated() {
            var x = 0.0
            for (label, width) in labels { keys.append(.init(label: label, x: x, y: Double(row) + 1.4, width: width)); x += width }
        }
        for (row, labels) in [["ins", "home", "pg↑"], ["del", "end", "pg↓"]].enumerated() {
            for (index, label) in labels.enumerated() { keys.append(.init(label: label, x: 15.5 + Double(index), y: 1.4 + Double(row))) }
        }
        keys += [.init(label: "↑", x: 16.5, y: 4.4), .init(label: "←", x: 15.5, y: 5.4), .init(label: "↓", x: 16.5, y: 5.4), .init(label: "→", x: 17.5, y: 5.4)]
        for (row, labels) in [["num", "/", "*", "−"], ["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"]].enumerated() {
            for (index, label) in labels.enumerated() { keys.append(.init(label: label, x: 19 + Double(index), y: 1.4 + Double(row))) }
        }
        keys += [.init(label: "+", x: 22, y: 2.4, height: 2), .init(label: "enter", x: 22, y: 4.4, height: 2), .init(label: "0", x: 19, y: 5.4, width: 2), .init(label: ".", x: 21, y: 5.4)]
        return keys
    }
    var body: some View {
        Canvas { context, size in
            let unit = min((size.width - 32) / 23, (size.height - 24) / 6.4)
            let offset = CGPoint(x: (size.width - 23 * unit) / 2, y: (size.height - 6.4 * unit) / 2)
            for key in keys {
                let rect = CGRect(x: offset.x + key.x * unit + 1.8, y: offset.y + key.y * unit + 1.8, width: key.width * unit - 3.6, height: key.height * unit - 3.6)
                let path = Path(roundedRect: rect, cornerRadius: 3)
                let keyColor = [UInt8(0), 1, 0x0a].contains(mode) ? Color(hue: key.x / 26 + 0.03, saturation: 0.65, brightness: 1) : color
                context.fill(path, with: .color(Color(white: 0.16)))
                context.stroke(path, with: .color(keyColor.opacity(brightness == 0 ? 0.10 : 0.22 + brightness * 0.15)), lineWidth: 1)
                context.draw(Text(key.label).font(.system(size: max(6, unit * 0.25), weight: .medium, design: .rounded)).foregroundStyle(Color.white.opacity(brightness == 0 ? 0.35 : 0.8)), at: CGPoint(x: rect.midX, y: rect.midY))
            }
        }
        .frame(height: 218)
        .background(Color(red: 0.065, green: 0.073, blue: 0.09), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("全尺寸键盘布局示意，灯效预览")
    }
}
