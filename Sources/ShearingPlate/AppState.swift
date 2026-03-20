import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var items: [ClipboardItem]
    @Published var searchText = ""
    @Published var settings: AppSettings
    @Published var lastErrorMessage: String?
    @Published var launchAtLoginStatus: LaunchAtLoginStatusSnapshot?
    @Published var globalShortcutStatusMessage: String?

    var clipboardWriter: ((String) -> Void)?
    var launchAtLoginUpdater: ((Bool) throws -> LaunchAtLoginStatusSnapshot)?
    var launchAtLoginStatusProvider: (() -> LaunchAtLoginStatusSnapshot)?
    var hotKeyUpdater: ((Bool, HotKeyShortcut) throws -> HotKeyRegistrationResult)?

    private let store: ClipboardStore

    init(store: ClipboardStore) {
        self.store = store

        do {
            self.items = try store.loadItems()
        } catch {
            self.items = []
            self.lastErrorMessage = "历史记录读取失败：\(error.localizedDescription)"
        }

        do {
            self.settings = try store.loadSettings()
        } catch {
            self.settings = AppSettings()
            self.lastErrorMessage = "设置读取失败：\(error.localizedDescription)"
        }

        trimItems()
    }

    var filteredItems: [ClipboardItem] {
        let ordered = items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            return lhs.capturedAt > rhs.capturedAt
        }

        let normalizedQuery = searchText.normalizedClipboardText
        guard !normalizedQuery.isEmpty else {
            return ordered
        }

        return ordered.filter { $0.matches(query: normalizedQuery) }
    }

    func capture(content: String, sourceApp: NSRunningApplication?) {
        guard !settings.isPaused else {
            return
        }

        let normalizedContent = content.normalizedClipboardText
        guard !normalizedContent.isEmpty else {
            return
        }

        let sourceBundleID = sourceApp?.bundleIdentifier
        if let sourceBundleID, settings.ignoredBundleIDs.contains(sourceBundleID) {
            return
        }

        items.insert(
            ClipboardItem.make(
                content: normalizedContent,
                sourceAppName: sourceApp?.localizedName,
                sourceBundleID: sourceBundleID,
                capturedAt: Date()
            ),
            at: 0
        )

        trimItems()
        persistItems()
    }

    func copy(_ item: ClipboardItem) {
        clipboardWriter?(item.content)

        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].lastUsedAt = Date()
        persistItems()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].isPinned.toggle()
        persistItems()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        persistItems()
    }

    func clearAll() {
        items.removeAll()
        persistItems()
    }

    func setPaused(_ isPaused: Bool) {
        settings.isPaused = isPaused
        persistSettings()
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        let previousValue = settings.launchAtLoginEnabled

        do {
            let status = try launchAtLoginUpdater?(isEnabled)
                ?? LaunchAtLoginStatusSnapshot.disabledFallback()
            applyLaunchAtLoginStatus(status)
        } catch {
            settings.launchAtLoginEnabled = previousValue
            lastErrorMessage = "登录启动设置失败：\(error.localizedDescription)"
        }
    }

    func refreshLaunchAtLoginStatus() {
        guard let status = launchAtLoginStatusProvider?() else {
            return
        }

        applyLaunchAtLoginStatus(status)
    }

    func syncLaunchAtLoginStatus(_ status: LaunchAtLoginStatusSnapshot) {
        applyLaunchAtLoginStatus(status)
    }

    func setGlobalShortcutEnabled(_ isEnabled: Bool) {
        let previousValue = settings.globalShortcutEnabled

        do {
            let result = try hotKeyUpdater?(isEnabled, settings.globalShortcut)
                ?? HotKeyRegistrationResult(isEnabled: isEnabled, shortcut: settings.globalShortcut, statusMessage: nil)
            settings.globalShortcutEnabled = result.isEnabled
            settings.globalShortcut = result.shortcut
            globalShortcutStatusMessage = result.statusMessage
            persistSettings()
        } catch {
            settings.globalShortcutEnabled = previousValue
            lastErrorMessage = "快捷键设置失败：\(error.localizedDescription)"
        }
    }

    func updateGlobalShortcut(_ shortcut: HotKeyShortcut) {
        let previousShortcut = settings.globalShortcut

        do {
            let result = try hotKeyUpdater?(settings.globalShortcutEnabled, shortcut)
                ?? HotKeyRegistrationResult(isEnabled: settings.globalShortcutEnabled, shortcut: shortcut, statusMessage: nil)
            settings.globalShortcutEnabled = result.isEnabled
            settings.globalShortcut = result.shortcut
            globalShortcutStatusMessage = result.statusMessage
            persistSettings()
        } catch {
            settings.globalShortcut = previousShortcut
            lastErrorMessage = "快捷键设置失败：\(error.localizedDescription)"
        }
    }

    func restoreDefaultGlobalShortcut() {
        updateGlobalShortcut(.defaultShortcut)
    }

    func updateGlobalShortcutStatusMessage(_ statusMessage: String?) {
        globalShortcutStatusMessage = statusMessage
    }

    func updateMaxItems(_ value: Int) {
        settings.maxItems = max(20, value)
        trimItems()
        persistSettings()
        persistItems()
    }

    func updatePollInterval(_ value: TimeInterval) {
        settings.pollInterval = min(max(value, 0.2), 2.0)
        persistSettings()
    }

    func updateIgnoredBundleIDs(from text: String) {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        settings.ignoredBundleIDs = lines
        persistSettings()
    }

    func restoreDefaultIgnoredBundleIDs() {
        settings.ignoredBundleIDs = AppSettings.defaultIgnoredBundleIDs
        persistSettings()
    }

    func persist() {
        persistItems()
        persistSettings()
    }

    func clearLastError() {
        lastErrorMessage = nil
    }

    private func applyLaunchAtLoginStatus(_ status: LaunchAtLoginStatusSnapshot) {
        settings.launchAtLoginEnabled = status.isEnabled
        launchAtLoginStatus = status
        persistSettings()
    }

    private func trimItems() {
        let pinnedItems = items.filter(\.isPinned)
        let unpinnedItems = items
            .filter { !$0.isPinned }
            .sorted { $0.capturedAt > $1.capturedAt }

        let availableSlots = max(settings.maxItems - pinnedItems.count, 0)
        let trimmedUnpinned = Array(unpinnedItems.prefix(availableSlots))
        items = pinnedItems + trimmedUnpinned
    }

    private func persistItems() {
        do {
            try store.saveItems(items)
            if lastErrorMessage?.contains("历史记录") == true {
                lastErrorMessage = nil
            }
        } catch {
            lastErrorMessage = "历史记录保存失败：\(error.localizedDescription)"
        }
    }

    private func persistSettings() {
        do {
            try store.saveSettings(settings)
            if lastErrorMessage?.contains("设置") == true {
                lastErrorMessage = nil
            }
        } catch {
            lastErrorMessage = "设置保存失败：\(error.localizedDescription)"
        }
    }
}
