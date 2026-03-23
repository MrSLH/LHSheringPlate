import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    var onCapture: ((ClipboardPayload, NSRunningApplication?) -> Void)?

    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredHashes: [String: Int] = [:]
    private var pollInterval: TimeInterval = AppSettings.defaultPollInterval

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastChangeCount = pasteboard.changeCount
    }

    func updatePollInterval(_ interval: TimeInterval) {
        let sanitizedInterval = min(max(interval, 0.2), 2.0)
        guard abs(pollInterval - sanitizedInterval) > 0.001 else {
            return
        }

        pollInterval = sanitizedInterval

        if timer != nil {
            stop()
            start()
        }
    }

    func writeToPasteboard(_ item: ClipboardItem) {
        ignoredHashes[item.contentHash, default: 0] += 1
        pasteboard.clearContents()

        switch item.payload {
        case .text(let content):
            pasteboard.setString(content.normalizedClipboardText, forType: .string)
        case .richText(let plainText, let html, let rtfData):
            let pasteboardItem = NSPasteboardItem()

            if !plainText.normalizedClipboardText.isEmpty {
                pasteboardItem.setString(plainText, forType: .string)
            }

            if let html, !html.isEmpty {
                pasteboardItem.setString(html, forType: .html)
            }

            if let rtfData, !rtfData.isEmpty {
                pasteboardItem.setData(rtfData, forType: .rtf)
            }

            pasteboard.writeObjects([pasteboardItem])
        case .image(let data, _, _):
            if let image = NSImage(data: data), let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)

                if let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    pasteboard.setData(pngData, forType: NSPasteboard.PasteboardType("public.png"))
                }
            } else {
                pasteboard.setData(data, forType: .tiff)
            }
        case .files(let files):
            let urls = files.map { NSURL(fileURLWithPath: $0.path) }
            pasteboard.writeObjects(urls)
        }

        lastChangeCount = pasteboard.changeCount
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard let payload = readPayload() else {
            return
        }

        let hash = payload.contentHash
        if let ignoredCount = ignoredHashes[hash] {
            if ignoredCount <= 1 {
                ignoredHashes.removeValue(forKey: hash)
            } else {
                ignoredHashes[hash] = ignoredCount - 1
            }
            return
        }

        onCapture?(payload, NSWorkspace.shared.frontmostApplication)
    }

    private func readPayload() -> ClipboardPayload? {
        readFilesPayload()
            ?? readImagePayload()
            ?? readRichTextPayload()
            ?? readTextPayload()
    }

    private func readFilesPayload() -> ClipboardPayload? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]

        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return nil
        }

        let files = objects
            .map { ClipboardFileReference(path: $0.standardizedFileURL.path) }
        guard !files.isEmpty else {
            return nil
        }

        return .files(files)
    }

    private func readImagePayload() -> ClipboardPayload? {
        let imageData = pasteboard.data(forType: .tiff)
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.png"))
        guard let imageData else {
            return nil
        }

        let imageSize = NSImage(data: imageData)?.size
        let width = imageSize.map { max(Int($0.width.rounded()), 1) }
        let height = imageSize.map { max(Int($0.height.rounded()), 1) }

        return .image(data: imageData, width: width, height: height)
    }

    private func readRichTextPayload() -> ClipboardPayload? {
        let html = pasteboard.string(forType: .html)
        let rtfData = pasteboard.data(forType: .rtf)

        guard html != nil || rtfData != nil else {
            return nil
        }

        let plainText = pasteboard.string(forType: .string)?.normalizedClipboardText
            ?? html.flatMap(Self.extractPlainTextFromHTML(_:))
            ?? rtfData.flatMap(Self.extractPlainTextFromRTF(_:))
            ?? ""

        return .richText(
            plainText: plainText,
            html: html,
            rtfData: rtfData
        )
    }

    private func readTextPayload() -> ClipboardPayload? {
        guard let content = pasteboard.string(forType: .string)?.normalizedClipboardText, !content.isEmpty else {
            return nil
        }

        return .text(content)
    }

    private static func extractPlainTextFromHTML(_ html: String) -> String? {
        guard let data = html.data(using: .utf8) else {
            return nil
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
        let plainText = attributed?.string.normalizedClipboardText
        return plainText?.isEmpty == true ? nil : plainText
    }

    private static func extractPlainTextFromRTF(_ data: Data) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf,
        ]
        let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
        let plainText = attributed?.string.normalizedClipboardText
        return plainText?.isEmpty == true ? nil : plainText
    }
}
