import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var ignoredBundleIDsText: String

    init(appState: AppState) {
        self.appState = appState
        _ignoredBundleIDsText = State(initialValue: appState.settings.ignoredBundleIDs.joined(separator: "\n"))
    }

    private var pauseBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.isPaused },
            set: { appState.setPaused($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.launchAtLoginEnabled },
            set: { appState.setLaunchAtLoginEnabled($0) }
        )
    }

    private var globalShortcutBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.globalShortcutEnabled },
            set: { appState.setGlobalShortcutEnabled($0) }
        )
    }

    private var maxItemsBinding: Binding<Int> {
        Binding(
            get: { appState.settings.maxItems },
            set: { appState.updateMaxItems($0) }
        )
    }

    private var pollIntervalBinding: Binding<Double> {
        Binding(
            get: { appState.settings.pollInterval },
            set: { appState.updatePollInterval($0) }
        )
    }

    var body: some View {
        Form {
            Section("系统集成") {
                Toggle("登录时自动启动", isOn: launchAtLoginBinding)

                if let launchAtLoginStatus = appState.launchAtLoginStatus {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(launchAtLoginStatus.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color(for: launchAtLoginStatus.kind))

                        Text(launchAtLoginStatus.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("系统状态：\(launchAtLoginStatus.serviceStatusDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("当前路径：\(launchAtLoginStatus.bundlePath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                HStack {
                    Spacer()

                    Button("刷新登录启动状态") {
                        appState.refreshLaunchAtLoginStatus()
                    }
                }

                Divider()

                Toggle("启用全局快捷键", isOn: globalShortcutBinding)

                ShortcutRecorderView(
                    shortcut: appState.settings.globalShortcut,
                    isEnabled: appState.settings.globalShortcutEnabled,
                    statusMessage: appState.globalShortcutStatusMessage,
                    onShortcutCaptured: { appState.updateGlobalShortcut($0) },
                    onRestoreDefault: { appState.restoreDefaultGlobalShortcut() }
                )
            }

            Section("记录策略") {
                Toggle("暂停记录", isOn: pauseBinding)

                Stepper(value: maxItemsBinding, in: 50 ... 1_000, step: 50) {
                    Text("最大历史条数：\(appState.settings.maxItems)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("轮询间隔")
                        Spacer()
                        Text(String(format: "%.1f 秒", appState.settings.pollInterval))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: pollIntervalBinding, in: 0.2 ... 2.0, step: 0.1)
                }
            }

            Section("忽略的应用 Bundle ID") {
                Text("每行一个。建议保留密码管理器、终端、远程桌面等敏感应用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $ignoredBundleIDsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)

                HStack {
                    Button("保存名单") {
                        appState.updateIgnoredBundleIDs(from: ignoredBundleIDsText)
                    }

                    Button("恢复默认") {
                        ignoredBundleIDsText = AppSettings.defaultIgnoredBundleIDs.joined(separator: "\n")
                        appState.restoreDefaultIgnoredBundleIDs()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(minWidth: 540, minHeight: 560)
    }

    private func color(for kind: LaunchAtLoginStatusKind) -> Color {
        switch kind {
        case .enabled:
            return .green
        case .warning:
            return .orange
        case .disabled:
            return .secondary
        case .unavailable:
            return .red
        }
    }
}
