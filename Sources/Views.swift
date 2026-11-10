import SwiftUI

enum Panel: String, CaseIterable, Identifiable {
    case lights = "灯光", profiles = "本机方案", keys = "按键", about = "使用说明"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .lights: return "lightbulb"; case .profiles: return "square.stack"; case .keys: return "command"; case .about: return "questionmark.circle" }
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var panel: Panel = .lights
    private let accent = Color(red: 0.68, green: 0.15, blue: 0.26)
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 25) {
                HStack(spacing: 9) {
                    Image(systemName: "keyboard.fill").font(.title2).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) { Text("键盘灯控").font(.headline); Text("为你的 Mac 而作").font(.caption).foregroundStyle(.secondary) }
                }.padding(.top, 28)
                VStack(spacing: 6) {
                    ForEach(Panel.allCases) { item in
                        Button { panel = item } label: {
                            Label(item.rawValue, systemImage: item.symbol).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 12)
                                .background(panel == item ? accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 9))
                                .foregroundStyle(panel == item ? accent : .primary)
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Circle().fill(model.connected ? Color.green : .orange).frame(width: 7, height: 7); Text(model.connected ? "USB 已连接" : "等待键盘连接").font(.caption) }
                    Text("CHERRY MX 3.1 RGB").font(.system(size: 11, weight: .medium))
                    Button("重新读取", systemImage: "arrow.clockwise") { model.refresh() }.disabled(model.busy)
                }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text("v\(AppMetadata.version) · 本机运行").font(.caption).fontWeight(.medium)
                    Text(AppMetadata.author).font(.caption2)
                }.foregroundStyle(.secondary)
            }.padding(.horizontal, 18).padding(.bottom, 20).frame(width: 195).background(Color(nsColor: .controlBackgroundColor))
            Divider()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        switch panel {
                        case .lights: lights
                        case .profiles: profiles
                        case .keys: keys
                        case .about: about
                        }
                    }.padding(28).frame(maxWidth: 1050)
                }
                Divider()
                HStack(alignment: .center, spacing: 10) {
                    if model.busy { ProgressView().controlSize(.small) }
                    else { Image(systemName: model.isError ? "exclamationmark.circle.fill" : "checkmark.circle").foregroundStyle(model.isError ? Color.orange : Color.secondary) }
                    Text(model.status).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 24).padding(.vertical, 13).frame(minHeight: 48).background(.bar)
            }.frame(maxWidth: .infinity)
        }
        .tint(accent)
        .frame(minWidth: 980, minHeight: 780)
        .onAppear { model.refresh() }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 28, weight: .semibold)); Text(subtitle).font(.callout).foregroundStyle(.secondary) }
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }
    private var lights: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("点亮你的桌面", "调整主键区背光。选择完成后，点击「应用到键盘」。")
            VStack(alignment: .leading, spacing: 9) {
                KeyboardPreview(color: model.color, mode: model.mode, rainbow: model.displaysRainbow, brightness: model.brightness)
                HStack { Text("CHERRY MX 3.1 RGB").font(.caption).fontWeight(.medium); if let state = model.state { Text("· 板载配置 \(Int(state.profileIndex) + 1)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("布局示意 · 颜色预览").font(.caption).foregroundStyle(.secondary) }
            }
            card {
                HStack { Text("灯效").font(.headline); Spacer(); Text(model.effect?.detail ?? "键盘当前为其他模式，选择下方灯效后可应用。").font(.caption).foregroundStyle(.secondary) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(LightEffect.all) { effect in
                        Button { model.selectEffect(effect.id) } label: {
                            VStack(spacing: 8) { Image(systemName: effect.symbol).font(.system(size: 19)); Text(effect.name).font(.callout) }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .foregroundStyle(model.mode == effect.id ? accent : .primary)
                                .background(model.mode == effect.id ? accent.opacity(0.09) : Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(model.mode == effect.id ? accent.opacity(0.55) : .clear))
                        }.buttonStyle(.plain).accessibilityAddTraits(model.mode == effect.id ? .isSelected : [])
                    }
                }
                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text("亮度"); Spacer(); Text(model.brightness == 0 ? "关闭" : "\(Int(model.brightness)) / 4").foregroundStyle(.secondary) }
                        Slider(value: $model.brightness, in: 0...4, step: 1).accessibilityLabel("亮度")
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text("速度"); Spacer(); Text("\(Int(model.speed) + 1) / 5").foregroundStyle(.secondary) }
                        Slider(value: $model.speed, in: 0...4, step: 1).disabled(model.effect?.usesSpeed == false).accessibilityLabel("灯效速度，从慢到快")
                    }
                }.padding(.top, 3)
                Divider()
                HStack {
                    Text("颜色模式").font(.headline)
                    Picker("颜色模式", selection: Binding(get: { model.displaysRainbow }, set: { model.setColorful($0) })) {
                        Text("单色").tag(false)
                        Text("彩色 · 彩虹").tag(true)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 240).disabled(model.busy)
                    Spacer()
                }
                if model.displaysRainbow {
                    Text("使用键盘内置的多彩灯效，可调亮度和速度。选择彩色时，常亮会切换为彩虹波浪。").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    ColorPicker("单色", selection: $model.color, supportsOpacity: false).fixedSize().disabled(model.displaysRainbow).onChange(of: model.color) { _, value in model.colorChanged(value) }
                    TextField("RRGGBB", text: $model.hex).font(.system(.body, design: .monospaced)).frame(width: 82).textFieldStyle(.roundedBorder).disabled(model.displaysRainbow).onSubmit { model.setHex(model.hex) }.accessibilityLabel("六位十六进制颜色")
                    Button("随机选色", systemImage: "shuffle") { model.randomizeColor() }.disabled(model.busy).help("随机挑选一种单色，点击应用后生效；彩色效果请使用上方的颜色模式。")
                    ForEach(["FFDDB0", "FFFFFF", "66E3C4", "67A8FF", "C4A0FF", "FF6B91"], id: \.self) { hex in
                        Button { model.setHex(hex) } label: { Circle().fill(swatch(hex)).frame(width: 21, height: 21).overlay(Circle().stroke(.gray.opacity(0.25))) }.buttonStyle(.plain).disabled(model.displaysRainbow).help("#\(hex)")
                    }
                    Spacer(minLength: 0)
                }
                if model.effect?.usesColor == false { Text("此灯效使用键盘内置彩色变化。").font(.caption).foregroundStyle(.secondary) }
            }
            HStack(spacing: 12) {
                Button("应用到键盘", systemImage: "checkmark") { model.apply() }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!model.connected || model.busy || model.effect == nil || LightingState.rgb(model.hex) == nil)
                Button("关闭背光", systemImage: "lightbulb.slash") { model.apply(off: true) }.disabled(!model.connected || model.busy)
                Spacer()
                Button("恢复上次设置", systemImage: "arrow.uturn.backward") { model.undo() }.disabled(model.undoState == nil || !model.connected || model.busy)
            }
            Text(model.state == nil ? "连接键盘后读取当前设置。" : model.dirty ? "有尚未应用的调整。" : "显示已读取的设置。启动和载入配置时不会自动更改灯光。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var profiles: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("留住喜欢的光", "将当前面板的灯效保存为配置，在不同场景间切换。")
            card {
                Text("保存当前灯光方案").font(.headline)
                HStack { TextField("配置名称", text: $model.profileName).textFieldStyle(.roundedBorder); Button("保存配置") { model.saveProfile() }.buttonStyle(.borderedProminent) }
                Text("这里保存和删除的是这台 Mac 上的灯光方案，不会删除键盘板载配置。载入后到灯光面板点击应用。").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(model.profiles) { profile in
                card {
                    HStack(spacing: 15) {
                        RoundedRectangle(cornerRadius: 9).fill(swatch(profile.hex)).frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(profile.name).font(.headline)
                            Text("\(LightEffect.all.first { $0.id == profile.mode }?.name ?? "其他") · 亮度 \(profile.brightness)/4 · \(profile.isColorful ? "彩色" : "#\(profile.hex)")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("载入") { model.load(profile); panel = .lights }
                        Button(role: .destructive) { model.deleteProfile(profile) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("仅删除 Mac 上的此方案")
                    }
                }
            }
            HStack { Button("导入 JSON", systemImage: "square.and.arrow.down") { model.importProfiles() }; Button("导出配置", systemImage: "square.and.arrow.up") { model.exportProfiles() } }
            Text("配置保存在本机，不包含键盘输入内容。").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var keys: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("让按键更顺手", "通过 macOS 调整这把 CHERRY 键盘的常用按键。")
            card {
                Label("Mac 修饰键", systemImage: "command").font(.headline)
                Toggle("交换左右两侧的 Win / Alt（Command / Option）", isOn: $model.swapModifiers)
                HStack(spacing: 20) {
                    keycap("Ctrl"); keycap(model.swapModifiers ? "⌥ Option" : "⌘ Command"); keycap(model.swapModifiers ? "⌘ Command" : "⌥ Option"); keycap("Space", width: 120)
                }.padding(.vertical, 6)
                Text("按键帽为常见 PC 布局的排列示意。若已使用键盘自身的 Mac 模式，可保留当前映射，避免重复交换。").font(.caption).foregroundStyle(.secondary)
            }
            card {
                Label("Caps Lock", systemImage: "capslock").font(.headline)
                Picker("按下 Caps Lock 时", selection: $model.capsMode) { Text("Caps Lock（默认）").tag(0); Text("Escape").tag(1); Text("左 Control").tag(2) }.pickerStyle(.menu).frame(maxWidth: 420)
            }
            HStack {
                Button("应用按键设置") { model.applyKeys() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!model.canEditKeys)
                Button("撤销本次映射") { model.undoKeys() }.disabled(model.undoMappings == nil || !model.connected || model.busy)
            }
            Text(model.keyStatus).font(.callout).foregroundStyle(.secondary)
            Text("这些设置修改当前 macOS 会话的映射，拔插键盘或重启后可能需要重新应用。应用会更新 Win、Alt 和 Caps Lock 的映射，保留其他 hidutil 映射。").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("键盘灯控", "为 CHERRY MX 3.1 RGB 制作的本地 Mac 控制工具。")
            card {
                HStack { Text("版本 / Version").font(.headline); Spacer(); Text("v\(AppMetadata.version)").font(.title3).fontWeight(.semibold).monospacedDigit() }
                Text("作者 / Author：\(AppMetadata.author)").textSelection(.enabled)
                Text("为 CHERRY MX 3.1 RGB 提供单色与彩色灯效、随机选色、本机方案和常用按键设置。\nNative macOS controls for CHERRY MX 3.1 RGB lighting, single-color and rainbow effects, random color selection, local profiles and key remapping.")
                HStack {
                    Link("GitHub 项目 / Project", destination: AppMetadata.repositoryURL)
                    Link("CC BY-NC 4.0", destination: AppMetadata.licenseURL)
                }
                Text("原创内容采用署名—非商业性使用许可；第三方材料保留各自许可。\nOriginal material: attribution and noncommercial use. Third-party material retains its own licenses.").font(.caption).foregroundStyle(.secondary)
            }
            card {
                Text("从这里开始").font(.headline)
                Text("1. 用 USB 连接键盘，左下角应显示「USB 已连接」。\n\n2. 选择灯效、亮度、速度和颜色，然后点击「应用到键盘」。\n\n3. 在「本机方案」保存常用方案；在「按键」调整 Mac 修饰键。")
                Text("软件会读取设备当前设置，并在写入后读回核对。界面预览用于展示颜色和布局，实际动画以键盘为准。").foregroundStyle(.secondary)
                Text("「随机选色」每次生成一种新颜色，仍需点击应用。它不会持续自动写入或循环换色。").font(.caption).foregroundStyle(.secondary)
            }
            card {
                Text("连接与权限").font(.headline)
                Text("如果键盘无法打开，检查数据线或 USB 扩展坞。如果 macOS 提示权限，在输入监控中允许本应用，再退出并重新打开。")
                Button("打开输入监控设置") { model.openInputSettings() }
                Text("本应用仅处理控制通道应答，不记录按键。灯光控制无需安装系统扩展。").font(.caption).foregroundStyle(.secondary)
            }
            card {
                Text("当前版本的范围").font(.headline)
                Text("支持主键区的 10 种内置灯效、亮度、速度、RGB 颜色、本机配置和常用按键映射。侧边灯、逐键配色和硬件宏尚未开放。断电后设置是否保留仍需实测。")
                Text("首次成功连接会备份三套板载灯光配置。灯光修改只更新当前配置的灯光参数，保留其他设置。软件不提供删除板载配置、恢复出厂或刷固件操作；本机方案的删除只影响 Mac 文件。").font(.caption).foregroundStyle(.secondary)
                Text("兼容设备：USB 046A:01D7 · macOS 14 或更新版本 · Apple Silicon\n版本 \(AppMetadata.version) · 非 CHERRY 官方软件").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Link("灯光协议参考", destination: URL(string: "https://github.com/AlexBongers/cherry-mx-lighting-mac/blob/main/PROTOCOL.md")!)
                Link("Cherry RGB 协议研究", destination: URL(string: "https://github.com/skraus-dev/cherryrgb-rs")!)
                Button("第三方许可") { if let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "txt") { NSWorkspace.shared.open(url) } }
                Button("完整项目许可") { if let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") { NSWorkspace.shared.open(url) } }
            }.font(.caption)
        }
    }

    private func swatch(_ hex: String) -> Color {
        let rgb = LightingState.rgb(hex) ?? [255, 255, 255]
        return Color(.sRGB, red: Double(rgb[0]) / 255, green: Double(rgb[1]) / 255, blue: Double(rgb[2]) / 255)
    }
    private func keycap(_ text: String, width: CGFloat = 95) -> some View {
        Text(text).font(.callout).frame(width: width, height: 48).background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.25)))
    }
}
