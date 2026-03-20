# Contributing

感谢关注这个项目。

当前 ShearingPlate 还处在 `MVP / Alpha` 阶段，仓库更适合以下几类贡献：

- Bug 反馈
- 使用体验反馈
- 小范围可验证的功能改进
- 打包、分发、兼容性问题修复

## 开发环境

- macOS 13+
- 已安装 `Xcode.app`
- Swift 6

## 常用命令

开发运行：

```bash
./Scripts/run-dev.sh
```

构建：

```bash
swift build
```

测试：

```bash
swift test
```

打包 `.app`：

```bash
./Scripts/package-app.sh
```

打包测试分发 `zip`：

```bash
./Scripts/package-zip.sh
```

## 提交 Bug 前请尽量附带这些信息

- macOS 版本
- Intel / Apple Silicon
- 是否安装 Rosetta 2
- 使用的是 `swift run` 版本还是打包后的 `.app`
- 问题复现步骤
- 预期结果
- 实际结果
- 如有可能，附带 `~/Library/Application Support/ShearingPlate/settings.json` 的相关配置

## 功能建议请尽量说明

- 你的使用场景
- 为什么当前功能不够用
- 你希望的交互方式
- 是否会影响隐私或权限

## 当前已知边界

- 当前只支持纯文本和 URL
- 当前默认是本地 JSON 存储
- 当前打包产物是 `x86_64`
- 当前不是公证版本

## Pull Request 建议

- 保持改动范围清晰
- 优先小 PR
- 如果改动影响打包或系统权限，请更新 README 或 Docs
- 如果改动影响设置结构，请补充兼容性测试

## License 提醒

如果你准备把仓库公开给更多人使用，建议先补充正式的 `LICENSE` 文件，再开放更广泛的外部贡献。
