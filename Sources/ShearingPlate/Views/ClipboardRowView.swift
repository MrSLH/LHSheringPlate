import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.orange)
                        }

                        Text(item.preview)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }

                    HStack(spacing: 8) {
                        Text(item.kind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let sourceAppName = item.sourceAppName {
                            Text(sourceAppName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(Self.relativeDateFormatter.localizedString(for: item.capturedAt, relativeTo: Date()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button("复制", action: onCopy)
                    .buttonStyle(.borderedProminent)

                Button(item.isPinned ? "取消置顶" : "置顶", action: onTogglePin)
                    .buttonStyle(.bordered)

                Button("删除", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .contextMenu {
            Button("复制", action: onCopy)
            Button(item.isPinned ? "取消置顶" : "置顶", action: onTogglePin)
            Button("删除", role: .destructive, action: onDelete)
        }
    }
}
