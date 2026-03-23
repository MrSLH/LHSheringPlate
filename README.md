# ShearingPlate

一个面向 macOS 的剪贴板历史工具，当前聚焦在「本机自用 / 熟人内测 / PoC 与 MVP 演示」场景。

ShearingPlate 采用菜单栏常驻形态，默认本地存储，不依赖云端，不要求先有 Apple Developer Program 账号也能完成开发、打包和小范围测试分发。

## 项目状态

- 当前阶段：`MVP / Alpha`
- 当前支持：`macOS 13+`
- 当前打包产物：`x86_64`
- 当前分发方式：手动打包 `.app` / `.zip`
- 当前不包含：Developer ID 签名、公证、自动更新、云同步

## 已有能力

- 菜单栏常驻
- 自动记录纯文本、URL、图片、富文本 / HTML、文件
- 相同内容自动合并，默认保留最近 20 条唯一历史
- 搜索历史记录
- 置顶、删除、清空未置顶
- 暂停记录
- 登录启动
- 登录启动状态检测与刷新
- 全局快捷键打开面板
- 设置页录制自定义快捷键
- 来源应用黑名单
- 本地 SQLite 持久化
- 兼容旧版 JSON 数据自动迁移
- 一键打包 `.app`
- 一键生成测试分发 `zip`

## 当前限制

- 当前构建产物是 `x86_64`，Apple Silicon Mac 可能需要 Rosetta 2
- 当前是 ad-hoc 签名，不是公证版本
- 不适合公开大规模分发

## 为什么做这个项目

这个项目的目标不是先追求“正式商业分发”，而是优先验证一个可用、干净、足够稳定的 macOS 剪贴板工具原型：

- 先在本机跑通
- 再给少量熟人测试
- 再决定是否进入公证、自动更新、公开分发阶段

## 技术栈

- `Swift 6`
- `AppKit + SwiftUI`
- `NSPasteboard` 轮询监听
- `Carbon RegisterEventHotKey` 全局快捷键
- `ServiceManagement.SMAppService` 登录启动
- 本地 `SQLite` 持久化
- `Swift Package Manager`

## 快速开始

### 1. 开发运行

```bash
./Scripts/run-dev.sh
```

说明：

- 应用会以菜单栏常驻方式启动
- `swift run` 方式下，全局快捷键可用
- 登录启动请在打包后的 `.app` 中开启

### 2. 打包本地 `.app`

```bash
./Scripts/package-app.sh
open dist/ShearingPlate.app
```

这个脚本会：

- 生成应用图标
- 构建 release 产物
- 组装 `.app` 包
- 做 ad-hoc 签名

### 3. 生成测试分发包

```bash
./Scripts/package-zip.sh
```

这个脚本会输出：

- `dist/ShearingPlate.app`
- `dist/ShearingPlate-test-package.zip`

压缩包内包含：

- `ShearingPlate.app`
- `README-Install.md`

## 给测试用户的分发建议

建议直接发：

- `dist/ShearingPlate-test-package.zip`

而不是裸发 `.app`。

原因：

- `zip` 更适合跨机器传输
- 压缩包里已经附带安装说明
- 更不容易在传输过程中破坏应用包结构

测试用户说明文案见：

- [Docs/TESTER-INSTALL.md](Docs/TESTER-INSTALL.md)

## 数据与隐私

应用数据默认保存在：

```text
~/Library/Application Support/ShearingPlate/
```

当前包含：

- `clipboard.sqlite3`
- 旧版 `clip-items.json` / `settings.json` 会在首次启动时自动迁移

默认会忽略一批敏感应用，例如：

- Keychain Access
- 1Password
- LastPass
- Bitwarden
- Terminal
- iTerm2
- Microsoft Remote Desktop

这份黑名单可以在设置页中修改。

## 仓库结构

```text
Sources/ShearingPlate/      应用源码
Tests/ShearingPlateTests/   单元测试
Scripts/                    构建、打包、图标生成脚本
Docs/                       分发与 GitHub 文案
Config/                     应用打包配置
Assets/                     图标资源
```

## 路线图

- 更完整的搜索与过滤
- Universal build
- Developer ID 签名与公证
- 自动更新

## 贡献与反馈

如果你准备把这个仓库上传到 GitHub，建议至少补齐以下项目后再公开邀请贡献：

- Issues 使用说明
- Roadmap 的优先级说明

当前贡献/反馈说明见：

- [CONTRIBUTING.md](CONTRIBUTING.md)

Issue / PR 模板已包含在仓库中：

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/pull_request_template.md`

## License

当前默认采用：

- [Apache License 2.0](LICENSE)

## GitHub 文案

我额外整理了一份 GitHub 可直接复用的仓库描述、发布说明和测试邀请文案：

- [Docs/GITHUB-COPY.md](Docs/GITHUB-COPY.md)
