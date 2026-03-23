# ShearingPlate 测试安装说明

这是一个用于熟人内测的 macOS 菜单栏应用。

## 包内文件

- `ShearingPlate.app`
- `README-Install.md`

## 系统要求

- macOS 13 或更高版本
- 当前版本是 `x86_64` 架构
- 如果你使用的是 Apple Silicon Mac，可能需要先安装 `Rosetta 2`

## 安装步骤

1. 解压 `ShearingPlate-test-package.zip`
2. 把 `ShearingPlate.app` 拖到 `/Applications`
3. 在 `/Applications` 中找到 `ShearingPlate.app`
4. 第一次打开时，优先尝试右键应用，选择“打开”

## 如果系统阻止打开

如果 macOS 提示无法验证开发者或无法检查恶意软件，请按下面方式处理：

1. 打开一次应用，让系统弹出拦截提示
2. 前往“系统设置 > 隐私与安全性”
3. 在页面底部找到关于 `ShearingPlate.app` 的提示
4. 点击“仍要打开”或“Open Anyway”
5. 再次打开应用

如果仍然打不开，可以在终端执行：

```bash
xattr -d com.apple.quarantine /Applications/ShearingPlate.app
```

然后再次尝试打开。

## Apple Silicon Mac 提示

如果你使用的是 M1、M2、M3、M4 等 Apple Silicon Mac，而应用无法启动，通常是因为当前测试版还是 `x86_64` 构建。请先安装 Rosetta 2：

```bash
softwareupdate --install-rosetta --agree-to-license
```

安装完成后再重新打开应用。

## 启动后的使用方式

- 应用启动后会出现在 macOS 菜单栏
- 点击菜单栏图标可打开历史面板
- 默认会记录最近 20 条唯一历史，支持文本、图片、富文本 / HTML、文件
- 可以在设置中开启登录启动
- 可以在设置中录制自定义快捷键
- 面板底部有“退出”按钮

## 数据位置

应用数据默认保存在：

```text
~/Library/Application Support/ShearingPlate/
```

当前主数据文件为：

- `clipboard.sqlite3`

## 测试版说明

- 这是内测版本，不是 App Store 版本
- 当前没有 Apple Developer ID 公证
- 当前不适合公开大规模分发
