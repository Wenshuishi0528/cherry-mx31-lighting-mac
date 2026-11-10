# 验证范围 / Validation

## 已验证 / Verified

- CHERRY MX 3.1 RGB，USB `046A:01D7`，Apple Silicon Mac，macOS 15.7.9。
- 当前板载配置编号查询，以及 64 字节灯光页的地址计算。
- 灯光读写、应答检查、读回一致性和测试设置恢复。
- 主键区红色常亮由设备拥有者目视确认。读回一致单独不等于 LED 颜色已验证。
- `hidutil` 临时测试映射的写入、读回和原映射恢复。
- 中文原生窗口、连接状态和当前配置编号。
- v0.2.0 随机选色按钮连续两次生成不同颜色；作者、版本与许可在原生窗口中可见。随机选色没有写入硬件。

The exact USB device has been tested for active-slot detection, configuration reads/writes, response checks and restoration. Static red was visually confirmed by the device owner. Device-scoped `hidutil` mapping write/readback and restoration were also checked.

## 软件检查 / Software checks

`./scripts/test.sh` exercises packet size/checksum checks, mismatched responses, invalid settings and backups, preservation of unrelated mappings, built-in profile validity and slot offsets 65/129. It does not send device commands.

`./scripts/build.sh` builds the Apple Silicon application and verifies its ad-hoc signature. GitHub Actions runs these checks on macOS without a keyboard connected.

## 尚未验证 / Not yet verified

每一种动画的视觉表现、断电保留、Intel Mac、其他 USB ID、侧边灯、逐键 RGB 及硬件宏。未实现的功能不对外开放。

Every animation's physical appearance, persistence after power loss, Intel Macs and other USB IDs remain unverified. Side lighting, per-key RGB and hardware macros are not implemented.

请用软件版本、USB 型号标识和操作步骤报告问题。勿上传包含个人键盘宏、私人按键内容或设备序列号的日志。

When reporting an issue, include app version, USB model ID and reproduction steps. Do not publish private macros, input contents or device serial numbers.
