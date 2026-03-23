import CryptoKit
import Foundation

enum ClipboardItemKind: String, Codable, CaseIterable {
    case text
    case url
    case html
    case richText
    case image
    case files

    var label: String {
        switch self {
        case .text:
            return "文本"
        case .url:
            return "链接"
        case .html:
            return "HTML"
        case .richText:
            return "富文本"
        case .image:
            return "图片"
        case .files:
            return "文件"
        }
    }
}

struct ClipboardFileReference: Codable, Equatable {
    let path: String

    init(path: String) {
        self.path = URL(fileURLWithPath: path).standardizedFileURL.path
    }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

enum ClipboardPayload: Codable, Equatable {
    case text(String)
    case richText(plainText: String, html: String?, rtfData: Data?)
    case image(data: Data, width: Int?, height: Int?)
    case files([ClipboardFileReference])

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case plainText
        case html
        case rtfData
        case imageData
        case width
        case height
        case files
    }

    private enum PayloadType: String, Codable {
        case text
        case richText
        case image
        case files
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PayloadType.self, forKey: .type)

        switch type {
        case .text:
            self = .text(try container.decode(String.self, forKey: .text))
        case .richText:
            self = .richText(
                plainText: try container.decode(String.self, forKey: .plainText),
                html: try container.decodeIfPresent(String.self, forKey: .html),
                rtfData: try container.decodeIfPresent(Data.self, forKey: .rtfData)
            )
        case .image:
            self = .image(
                data: try container.decode(Data.self, forKey: .imageData),
                width: try container.decodeIfPresent(Int.self, forKey: .width),
                height: try container.decodeIfPresent(Int.self, forKey: .height)
            )
        case .files:
            self = .files(try container.decode([ClipboardFileReference].self, forKey: .files))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let value):
            try container.encode(PayloadType.text, forKey: .type)
            try container.encode(value, forKey: .text)
        case .richText(let plainText, let html, let rtfData):
            try container.encode(PayloadType.richText, forKey: .type)
            try container.encode(plainText, forKey: .plainText)
            try container.encodeIfPresent(html, forKey: .html)
            try container.encodeIfPresent(rtfData, forKey: .rtfData)
        case .image(let data, let width, let height):
            try container.encode(PayloadType.image, forKey: .type)
            try container.encode(data, forKey: .imageData)
            try container.encodeIfPresent(width, forKey: .width)
            try container.encodeIfPresent(height, forKey: .height)
        case .files(let files):
            try container.encode(PayloadType.files, forKey: .type)
            try container.encode(files, forKey: .files)
        }
    }

    var kind: ClipboardItemKind {
        switch self {
        case .text(let value):
            return Self.classifyText(value)
        case .richText(_, let html, _):
            return html == nil ? .richText : .html
        case .image:
            return .image
        case .files:
            return .files
        }
    }

    var preview: String {
        switch self {
        case .text(let value):
            return Self.previewText(for: value)
        case .richText(let plainText, let html, _):
            let normalized = plainText.normalizedClipboardText
            if !normalized.isEmpty {
                return Self.previewText(for: normalized)
            }
            return html == nil ? "富文本内容" : "HTML 内容"
        case .image(_, let width, let height):
            if let width, let height {
                return "图片 \(width)x\(height)"
            }
            return "图片"
        case .files(let files):
            let names = files.map(\.displayName)
            guard !names.isEmpty else {
                return "文件"
            }

            if names.count == 1 {
                return names[0]
            }

            let head = names.prefix(3).joined(separator: ", ")
            let suffix = names.count > 3 ? " 等 \(names.count) 个文件" : " (\(names.count) 个文件)"
            return "\(head)\(suffix)"
        }
    }

    var searchableText: String {
        switch self {
        case .text(let value):
            return value.normalizedClipboardText
        case .richText(let plainText, _, _):
            return plainText.normalizedClipboardText
        case .image:
            return ""
        case .files(let files):
            return files
                .map { "\($0.displayName) \($0.path)" }
                .joined(separator: "\n")
        }
    }

    var contentHash: String {
        switch self {
        case .text(let value):
            return Self.stableHash(parts: [
                Data("text".utf8),
                Data(value.normalizedClipboardText.utf8),
            ])
        case .richText(let plainText, let html, let rtfData):
            var parts = [
                Data("richText".utf8),
                Data(plainText.normalizedClipboardText.utf8),
                Data((html ?? "").utf8),
            ]
            if let rtfData {
                parts.append(rtfData)
            }
            return Self.stableHash(parts: parts)
        case .image(let data, let width, let height):
            return Self.stableHash(parts: [
                Data("image".utf8),
                data,
                Data("\(width ?? 0)x\(height ?? 0)".utf8),
            ])
        case .files(let files):
            let normalizedPaths = files.map(\.path).joined(separator: "\n")
            return Self.stableHash(parts: [
                Data("files".utf8),
                Data(normalizedPaths.utf8),
            ])
        }
    }

    var plainTextValue: String? {
        switch self {
        case .text(let value):
            return value
        case .richText(let plainText, _, _):
            let normalized = plainText.normalizedClipboardText
            return normalized.isEmpty ? nil : normalized
        case .image:
            return nil
        case .files(let files):
            let joined = files.map(\.path).joined(separator: "\n")
            return joined.isEmpty ? nil : joined
        }
    }

    private static func classifyText(_ content: String) -> ClipboardItemKind {
        let normalized = content.normalizedClipboardText
        guard let url = URL(string: normalized), let scheme = url.scheme, !scheme.isEmpty else {
            return .text
        }

        return .url
    }

    private static func previewText(for content: String) -> String {
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

    private static func stableHash(parts: [Data]) -> String {
        var hasher = SHA256()
        for part in parts {
            hasher.update(data: part)
            hasher.update(data: Data([0]))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
