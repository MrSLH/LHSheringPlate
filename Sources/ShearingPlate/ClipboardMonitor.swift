import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    var onCapture: ((String, NSRunningApplication?) -> Void)?

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

    func writeToPasteboard(_ content: String) {
        let normalizedContent = content.normalizedClipboardText
        guard !normalizedContent.isEmpty else {
            return
        }

        let hash = ClipboardItem.stableHash(for: normalizedContent)
        ignoredHashes[hash, default: 0] += 1

        pasteboard.clearContents()
        pasteboard.setString(normalizedContent, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard let content = pasteboard.string(forType: .string)?.normalizedClipboardText, !content.isEmpty else {
            return
        }

        let hash = ClipboardItem.stableHash(for: content)
        if let ignoredCount = ignoredHashes[hash] {
            if ignoredCount <= 1 {
                ignoredHashes.removeValue(forKey: hash)
            } else {
                ignoredHashes[hash] = ignoredCount - 1
            }
            return
        }

        onCapture?(content, NSWorkspace.shared.frontmostApplication)
    }
}
