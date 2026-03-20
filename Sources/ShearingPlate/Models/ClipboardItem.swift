import CryptoKit
import Foundation

enum ClipboardItemKind: String, Codable, CaseIterable {
    case text
    case url

    static func classify(content: String) -> ClipboardItemKind {
        guard let url = URL(string: content), let scheme = url.scheme, !scheme.isEmpty else {
            return .text
        }

        return .url
    }

    var label: String {
        switch self {
        case .text:
            return "文本"
        case .url:
            return "链接"
        }
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: ClipboardItemKind
    var content: String
    var preview: String
    var sourceAppName: String?
    var sourceBundleID: String?
    var capturedAt: Date
    var lastUsedAt: Date?
    var isPinned: Bool
    var contentHash: String

    init(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        content: String,
        preview: String,
        sourceAppName: String?,
        sourceBundleID: String?,
        capturedAt: Date,
        lastUsedAt: Date? = nil,
        isPinned: Bool = false,
        contentHash: String
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.preview = preview
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.capturedAt = capturedAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.contentHash = contentHash
    }

    static func make(
        content: String,
        sourceAppName: String?,
        sourceBundleID: String?,
        capturedAt: Date = Date()
    ) -> ClipboardItem {
        ClipboardItem(
            kind: ClipboardItemKind.classify(content: content),
            content: content,
            preview: preview(for: content),
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID,
            capturedAt: capturedAt,
            contentHash: stableHash(for: content)
        )
    }

    static func preview(for content: String) -> String {
        let collapsed = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if collapsed.count <= 140 {
            return collapsed
        }

        let index = collapsed.index(collapsed.startIndex, offsetBy: 140)
        return "\(collapsed[..<index])..."
    }

    static func stableHash(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func matches(query: String) -> Bool {
        let normalizedQuery = query.normalizedClipboardText.lowercased()
        guard !normalizedQuery.isEmpty else {
            return true
        }

        return content.lowercased().contains(normalizedQuery)
            || preview.lowercased().contains(normalizedQuery)
            || (sourceAppName?.lowercased().contains(normalizedQuery) ?? false)
    }
}

extension String {
    var normalizedClipboardText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
