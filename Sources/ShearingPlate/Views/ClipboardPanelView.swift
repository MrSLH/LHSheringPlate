import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var appState: AppState
    let openSettings: () -> Void
    let quitApp: () -> Void

    private var pauseBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.isPaused },
            set: { appState.setPaused($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ShearingPlate")
                        .font(.headline)

                    Text(appState.settings.isPaused ? "已暂停记录" : "正在监听系统剪贴板")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("暂停记录", isOn: pauseBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            TextField("搜索历史内容或来源应用", text: $appState.searchText)
                .textFieldStyle(.roundedBorder)

            if let errorMessage = appState.lastErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if appState.filteredItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("还没有可展示的历史记录")
                        .font(.headline)
                    Text("复制一段文本或链接后，它会自动出现在这里。当前 MVP 只记录纯文本和 URL。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.filteredItems) { item in
                            ClipboardRowView(
                                item: item,
                                onCopy: { appState.copy(item) },
                                onTogglePin: { appState.togglePin(item) },
                                onDelete: { appState.delete(item) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack {
                Text("\(appState.filteredItems.count)/\(appState.items.count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("退出", role: .destructive, action: quitApp)

                Button("清空未置顶", role: .destructive) {
                    appState.clearUnpinned()
                }
                .disabled(appState.items.allSatisfy { $0.isPinned })

                Button("设置", action: openSettings)
            }
        }
        .padding(14)
        .frame(width: 420, height: 560)
    }
}
