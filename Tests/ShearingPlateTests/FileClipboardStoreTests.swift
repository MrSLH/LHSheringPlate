import Carbon
import XCTest
@testable import ShearingPlate

final class FileClipboardStoreTests: XCTestCase {
    func testLegacySettingsDecodeFallsBackToDefaults() throws {
        let json = """
        {
          "isPaused": true,
          "maxItems": 150,
          "ignoredBundleIDs": ["com.apple.Terminal"],
          "pollInterval": 0.8
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let settings = try decoder.decode(AppSettings.self, from: data)

        XCTAssertTrue(settings.isPaused)
        XCTAssertFalse(settings.launchAtLoginEnabled)
        XCTAssertTrue(settings.globalShortcutEnabled)
        XCTAssertEqual(settings.globalShortcut, .defaultShortcut)
        XCTAssertEqual(settings.maxItems, 150)
        XCTAssertEqual(settings.ignoredBundleIDs, ["com.apple.Terminal"])
        XCTAssertEqual(settings.pollInterval, 0.8, accuracy: 0.001)
    }

    func testStorePersistsItemsAndSettings() throws {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let store = FileClipboardStore(baseDirectory: baseDirectory)
        let item = ClipboardItem.make(
            content: "https://example.com",
            sourceAppName: "Safari",
            sourceBundleID: "com.apple.Safari"
        )
        var settings = AppSettings()
        settings.maxItems = 350
        settings.isPaused = true
        settings.launchAtLoginEnabled = true
        settings.globalShortcutEnabled = false
        settings.globalShortcut = HotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_K),
            carbonModifiers: UInt32(cmdKey | optionKey)
        )

        try store.saveItems([item])
        try store.saveSettings(settings)

        let loadedItems = try store.loadItems()
        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(loadedItems.first?.content, item.content)
        XCTAssertEqual(loadedItems.first?.preview, item.preview)
        XCTAssertEqual(loadedItems.first?.sourceAppName, item.sourceAppName)
        XCTAssertEqual(loadedItems.first?.sourceBundleID, item.sourceBundleID)
        XCTAssertEqual(loadedItems.first?.contentHash, item.contentHash)
        XCTAssertEqual(try store.loadSettings(), settings)
    }

    @MainActor
    func testAppStateKeepsRecentCaptureEvents() {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let store = FileClipboardStore(baseDirectory: baseDirectory)
        let appState = AppState(store: store)

        appState.capture(content: "hello world", sourceApp: nil)
        appState.capture(content: "hello world", sourceApp: nil)

        XCTAssertEqual(appState.items.count, 2)
        XCTAssertEqual(appState.items.first?.content, "hello world")
    }

    @MainActor
    func testAppStateTrimsToDefaultTwentyItems() {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let store = FileClipboardStore(baseDirectory: baseDirectory)
        let appState = AppState(store: store)

        for index in 1 ... 25 {
            appState.capture(content: "item-\(index)", sourceApp: nil)
        }

        XCTAssertEqual(appState.items.count, 20)
        XCTAssertEqual(appState.items.first?.content, "item-25")
        XCTAssertEqual(appState.items.last?.content, "item-6")
    }
}
