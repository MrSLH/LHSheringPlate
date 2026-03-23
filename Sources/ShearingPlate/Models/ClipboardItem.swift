import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var payload: ClipboardPayload
    var sourceAppName: String?
    var sourceBundleID: String?
    var capturedAt: Date
    var lastUsedAt: Date?
    var isPinned: Bool
    var captureCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case payload
        case sourceAppName
        case sourceBundleID
        case capturedAt
        case lastUsedAt
        case isPinned
        case captureCount

        // Legacy JSON keys kept for migration compatibility.
        case content
    }

    var kind: ClipboardItemKind {
        payload.kind
    }

    var preview: String {
        payload.preview
    }

    var content: String {
        payload.plainTextValue ?? preview
    }

    var searchableText: String {
        payload.searchableText
    }

    var contentHash: String {
        payload.contentHash
    }

    init(
        id: UUID = UUID(),
        payload: ClipboardPayload,
        sourceAppName: String?,
        sourceBundleID: String?,
        capturedAt: Date,
        lastUsedAt: Date? = nil,
        isPinned: Bool = false,
        captureCount: Int = 1
    ) {
        self.id = id
        self.payload = payload
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.capturedAt = capturedAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.captureCount = max(1, captureCount)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        captureCount = max(1, try container.decodeIfPresent(Int.self, forKey: .captureCount) ?? 1)

        if let payload = try container.decodeIfPresent(ClipboardPayload.self, forKey: .payload) {
            self.payload = payload
            return
        }

        let legacyContent = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        let normalizedContent = legacyContent.normalizedClipboardText
        let legacyKind = try container.decodeIfPresent(ClipboardItemKind.self, forKey: .kind) ?? .text

        switch legacyKind {
        case .text, .url:
            payload = .text(normalizedContent)
        case .html, .richText:
            payload = .richText(plainText: normalizedContent, html: nil, rtfData: nil)
        case .image:
            payload = .image(data: Data(), width: nil, height: nil)
        case .files:
            payload = .files([])
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(payload, forKey: .payload)
        try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try container.encodeIfPresent(sourceBundleID, forKey: .sourceBundleID)
        try container.encode(capturedAt, forKey: .capturedAt)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(captureCount, forKey: .captureCount)
    }

    static func make(
        payload: ClipboardPayload,
        sourceAppName: String?,
        sourceBundleID: String?,
        capturedAt: Date = Date()
    ) -> ClipboardItem {
        ClipboardItem(
            payload: payload,
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID,
            capturedAt: capturedAt
        )
    }

    static func make(
        content: String,
        sourceAppName: String?,
        sourceBundleID: String?,
        capturedAt: Date = Date()
    ) -> ClipboardItem {
        ClipboardItem.make(
            payload: .text(content.normalizedClipboardText),
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID,
            capturedAt: capturedAt
        )
    }

    func mergedCapture(
        payload: ClipboardPayload,
        sourceAppName: String?,
        sourceBundleID: String?,
        capturedAt: Date = Date()
    ) -> ClipboardItem {
        ClipboardItem(
            id: id,
            payload: payload,
            sourceAppName: sourceAppName ?? self.sourceAppName,
            sourceBundleID: sourceBundleID ?? self.sourceBundleID,
            capturedAt: capturedAt,
            lastUsedAt: lastUsedAt,
            isPinned: isPinned,
            captureCount: captureCount + 1
        )
    }

    func matches(query: String) -> Bool {
        let normalizedQuery = query.normalizedClipboardText.lowercased()
        guard !normalizedQuery.isEmpty else {
            return true
        }

        return searchableText.lowercased().contains(normalizedQuery)
            || preview.lowercased().contains(normalizedQuery)
            || kind.label.lowercased().contains(normalizedQuery)
            || (sourceAppName?.lowercased().contains(normalizedQuery) ?? false)
    }
}

extension String {
    var normalizedClipboardText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
