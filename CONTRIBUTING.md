# 贡献 / Contributing

欢迎提交问题与修改。先说明型号、软件版本、复现步骤和实物表现，避免上传个人宏、序列号或私人输入。

Issues and patches are welcome. Include the model, app version, reproduction steps and physical behavior, without private macros, serial numbers or input contents.

- 修改前阅读 [许可范围](COPYRIGHT) 和 [第三方许可](Resources/THIRD_PARTY_NOTICES.txt)。提交者须有权按项目采用的 CC BY-NC 4.0 许可提供自己的贡献；第三方内容须单独标明。/ Review the licensing scope and provide only contributions you have the right to license under the project's terms, marking third-party material separately.
- 保持硬件型号精确匹配，保留未编辑字段及板载配置。/ Keep exact device matching and preserve unedited fields and onboard slots.
- 新型号不能仅凭同品牌就开放写入，需要独立的协议证据和实机观察。/ New device IDs need protocol evidence and physical validation before writes are enabled.
- 运行 `./scripts/test.sh` 和 `./scripts/build.sh`。CI 不能替代实物测试。/ Run the test and build scripts; CI does not replace hardware observation.
- 不将 USB 应答或读回一致描述为灯光效果已目视验证。/ Do not describe an acknowledged write or matching readback as visually verified LED behavior.
