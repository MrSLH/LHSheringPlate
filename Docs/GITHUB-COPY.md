# GitHub 文案备份

这份文件用于存放上传 GitHub 时可直接复用的文案。

## 仓库标题建议

- `ShearingPlate`
- `ShearingPlate - macOS Clipboard History MVP`

## GitHub About 简介

### 中文短版

一个面向 macOS 的菜单栏剪贴板历史工具，适合本机自用、熟人内测和 MVP 演示。

### 中文长版

ShearingPlate 是一个使用 Swift 构建的 macOS 菜单栏剪贴板历史工具，支持登录启动、全局快捷键、自定义录制、搜索和本地持久化，当前聚焦自用与小范围测试分发场景。

### English Short

A lightweight macOS menu bar clipboard history app built with Swift for local use, small-scale testing, and MVP demos.

## GitHub Topics 建议

- `macos`
- `swift`
- `appkit`
- `swiftui`
- `clipboard`
- `clipboard-manager`
- `menu-bar-app`
- `productivity`
- `macos-app`

## 仓库置顶介绍文案

ShearingPlate 是一个面向 macOS 的剪贴板历史工具原型。它优先解决“先做出来、先自己用、再给熟人测试”的问题，而不是一开始就进入正式商业分发流程。

## 首个 Release 标题建议

- `v0.1.0-alpha`
- `v0.1.0 MVP Preview`

## Release Notes 模板

### 中文版

`ShearingPlate v0.1.0-alpha`

这是第一个可运行的 MVP 版本，当前支持：

- 菜单栏常驻
- 自动记录纯文本和 URL
- 最近 20 次复制动作历史
- 搜索、置顶、删除、暂停记录
- 登录启动
- 全局快捷键打开面板
- 自定义快捷键录制
- 本地 JSON 持久化

注意事项：

- 当前为 `x86_64` 构建
- Apple Silicon 设备可能需要 Rosetta 2
- 当前不是公证版本
- 更适合熟人测试，不适合公开大规模分发

### English Version

`ShearingPlate v0.1.0-alpha`

This is the first runnable MVP release with:

- macOS menu bar app experience
- clipboard history for plain text and URLs
- recent 20 copy events
- search, pin, delete, pause recording
- launch at login
- global shortcut to open the panel
- customizable shortcut recorder
- local JSON persistence

Notes:

- current build is `x86_64`
- Apple Silicon Macs may require Rosetta 2
- this build is not notarized
- intended for small-scale testing, not broad public distribution

## 发给测试用户的邀请文案

### 中文版

我做了一个 macOS 剪贴板历史工具的早期测试版，想请你帮我试用一下。  
这是一个菜单栏应用，当前支持记录最近 20 次复制动作、快捷搜索、登录启动和自定义快捷键。  
这版还是内测包，不是公证版本，所以第一次打开时系统可能会拦一下。压缩包里我已经放了安装说明。

### 简短版

这里是 ShearingPlate 的测试包，你解压后把 `ShearingPlate.app` 拖到 `/Applications` 即可。第一次打开如果被系统拦截，按压缩包里的 `README-Install.md` 操作就行。

## Issue 引导文案

如果你在使用中遇到问题，请尽量附带以下信息：

- macOS 版本
- Intel / Apple Silicon
- 是否安装 Rosetta 2
- 复现步骤
- 预期结果
- 实际结果

## 上传 GitHub 前的建议检查项

- 确认 `.build/` 和 `dist/` 没有提交
- 确认没有把本地测试数据提交到仓库
- 决定是否补充 `LICENSE`
- 决定仓库是否公开
