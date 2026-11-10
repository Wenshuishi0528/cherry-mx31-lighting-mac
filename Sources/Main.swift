import SwiftUI
import AppKit

enum CommandLineTool {
    static func run() -> Bool {
        let args = CommandLine.arguments
        guard args.contains("--diagnose") || args.contains("--verify-roundtrip") else { return false }
        do {
            let session = try HIDSession()
            let initial = try session.readLighting()
            var report: [String: Any] = ["device": "CHERRY MX 3.1 RGB", "usb": "046A:01D7", "activeProfileIndex": Int(initial.profileIndex), "original": initial.bytes, "readVerified": true, "physicalColorVerified": false]
            if args.contains("--verify-roundtrip") {
                let backup = FileManager.default.temporaryDirectory.appendingPathComponent("keyboard-lights-roundtrip-backup.json")
                try JSONEncoder().encode(initial).write(to: backup, options: .atomic)
                do {
                    let (_, after) = try session.writeLighting(mode: 3, brightness: 1, speed: 2, hex: initial.hex == "663399" ? "336699" : "663399")
                    report["testSetting"] = after.bytes
                    report["writeReadbackVerified"] = true
                } catch {
                    do { _ = try session.restore(initial) }
                    catch { throw KeyboardError.message("测试失败且恢复失败，请使用备份 \(backup.path) 检查键盘。\(error.localizedDescription)") }
                    throw error
                }
                let restored = try session.restore(initial)
                report["restored"] = restored.bytes
                report["restoreVerified"] = restored == initial
            }
            report["keyMappings"] = try KeyMapping.read().map(\.dictionary)
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
            exit(0)
        } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
    }
}

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct KeyboardLightsApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var delegate
    @StateObject private var model: AppModel
    init() {
        _ = CommandLineTool.run()
        _model = StateObject(wrappedValue: AppModel())
    }
    var body: some Scene {
        WindowGroup("键盘灯控") { ContentView(model: model).preferredColorScheme(.light) }
            .defaultSize(width: 1120, height: 900)
            .commands {
                CommandGroup(replacing: .newItem) {}
                CommandGroup(after: .toolbar) { Button("重新读取键盘") { model.refresh() }.keyboardShortcut("r").disabled(model.busy) }
            }
    }
}
