import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

                        if item.captureCount > 1 {
                            Text("合并 \(item.captureCount) 次")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

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

                trailingAccessory
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

    @ViewBuilder
    private var trailingAccessory: some View {
        switch item.payload {
        case .text:
            EmptyView()
        case .richText:
            formatBadge(
                systemName: item.kind == .html ? "chevron.left.forwardslash.chevron.right" : "textformat",
                label: item.kind.label,
                tint: item.kind == .html ? .indigo : .blue
            )
        case .files(let files):
            let badge = fileBadge(for: files)
            formatBadge(systemName: badge.systemName, label: badge.label, tint: badge.tint)
        case .image(let data, _, _):
            if let previewImage = NSImage(data: data) {
                Image(nsImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(4)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08))
                    }
            } else {
                formatBadge(systemName: "photo", label: item.kind.label, tint: .pink)
            }
        }
    }

    private func fileBadge(for files: [ClipboardFileReference]) -> (systemName: String, label: String, tint: Color) {
        guard files.count == 1, let file = files.first else {
            return ("doc.on.doc", item.kind.label, .teal)
        }

        let fileURL = URL(fileURLWithPath: file.path)
        if isDirectory(fileURL) {
            return ("folder.fill", "文件夹", .yellow)
        }

        if fileURL.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
            return ("doc.richtext.fill", "PDF", .red)
        }

        if let fileType = UTType(filenameExtension: fileURL.pathExtension),
           fileType.conforms(to: .image) {
            return ("photo.fill", "图片", .pink)
        }

        return ("doc.fill", item.kind.label, .teal)
    }

    private func isDirectory(_ fileURL: URL) -> Bool {
        let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory ?? fileURL.hasDirectoryPath
    }

    private func formatBadge(systemName: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 60, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.1))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.18))
        }
    }
}
