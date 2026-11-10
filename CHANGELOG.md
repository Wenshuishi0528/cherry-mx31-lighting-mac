# 更新记录

## 0.3.0 — 2026-11-10

- 增加独立的「单色 / 彩色 · 彩虹」选项，发送键盘内置彩色标志；常亮选择彩色时切换为彩虹波浪。
- 修正键盘示意图在单色波浪模式下仍显示彩虹的问题；彩色参数随本机方案保存，兼容旧方案。
- 软件、仓库及发布署名统一使用 GitHub 用户名 Wenshuishi0528。
- 彩虹波浪已由设备拥有者目视确认正常。

Added an explicit Single color / Rainbow option, matching preview and profile storage with backward compatibility. Public author credits now use the GitHub username Wenshuishi0528.

## 0.2.0 — 2026-11-10

- 新增随机选色，每次生成新的明亮颜色，保留手动应用；内置彩色模式下随机选色会切换为常亮。
- 在侧栏、使用说明和系统关于信息中加入版本号和作者Wenshuishi0528。
- 加入中英双语项目简介、CC BY-NC 4.0 许可、构建检查和公开发布包。
- 应用前检查界面所选板载配置是否仍在使用，切换后要求重新读取，避免误改另一套配置。

Added random color selection, visible version and author credits, bilingual documentation, CC BY-NC 4.0 licensing and public distribution. Applying a draft now stops if the onboard profile changed after it was displayed.

## 0.1.0 — 2026-11-10

- 为 CHERRY MX 3.1 RGB 制作原生中文 Mac 灯光面板、本机方案和常用按键映射。
- 实机验证 USB 控制报文、配置读回和恢复；LED 实物效果需要单独观察确认。
- 修正首版只写第 1 套板载灯光的问题：每次操作查询当前编号，按 64 字节配置页计算地址，保留未编辑字段。
- 将界面反馈改为区分「配置写入/读回」和「实物颜色已验证」。
- 用户确认当前第 2 套板载配置的主键区实际变为红色常亮；备份三套灯光配置并还原旧版误写的第 1 套参数。
- 将 Mac 上保存的配置明确标记为「本机方案」，删除本机方案不影响键盘板载配置。
