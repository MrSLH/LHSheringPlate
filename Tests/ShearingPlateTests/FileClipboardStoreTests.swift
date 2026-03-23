import Carbon
import XCTest
@testable import ShearingPlate

final class FileClipboardStoreTests: XCTestCase {
    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

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

    func testLegacyFileStorePersistsItemsAndSettings() throws {
        let baseDirectory = makeTemporaryDirectory()
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

    func testSQLiteStorePersistsRichPayloadsAndSettings() throws {
        let baseDirectory = makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let store = SQLiteClipboardStore(baseDirectory: baseDirectory)
        let items = [
            ClipboardItem.make(
                payload: .richText(
                    plainText: "Bold text",
                    html: "<p><strong>Bold text</strong></p>",
                    rtfData: Data("{\\rtf1\\ansi Bold text}".utf8)
                ),
                sourceAppName: "Pages",
                sourceBundleID: "com.apple.iWork.Pages",
                capturedAt: Date(timeIntervalSince1970: 1)
            ),
            ClipboardItem.make(
                payload: .files([
                    ClipboardFileReference(path: "/tmp/a.txt"),
                    ClipboardFileReference(path: "/tmp/b.txt"),
                ]),
                sourceAppName: "Finder",
                sourceBundleID: "com.apple.finder",
                capturedAt: Date(timeIntervalSince1970: 2)
            ),
            ClipboardItem.make(
                payload: .image(data: Data([0x01, 0x02, 0x03]), width: 12, height: 34),
                sourceAppName: "Preview",
                sourceBundleID: "com.apple.Preview",
                capturedAt: Date(timeIntervalSince1970: 3)
            ),
        ]

        var settings = AppSettings()
        settings.maxItems = 250
        settings.pollInterval = 1.2

        try store.saveItems(items)
        try store.saveSettings(settings)

        let expectedOrder = items.sorted { $0.capturedAt > $1.capturedAt }
        XCTAssertEqual(try store.loadItems(), expectedOrder)
        XCTAssertEqual(try store.loadSettings(), settings)
    }

    func testSQLiteStoreMigratesLegacyJSONFilesOnFirstLoad() throws {
        let baseDirectory = makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let legacyStore = FileClipboardStore(baseDirectory: baseDirectory)
        let legacyItems = [
            ClipboardItem.make(
                content: "https://example.com",
                sourceAppName: "Safari",
                sourceBundleID: "com.apple.Safari"
            ),
            ClipboardItem.make(
                content: "https://example.com",
                sourceAppName: "Safari",
                sourceBundleID: "com.apple.Safari"
            ),
        ]
        var legacySettings = AppSettings()
        legacySettings.maxItems = 400

        try legacyStore.saveItems(legacyItems)
        try legacyStore.saveSettings(legacySettings)

        let sqliteStore = SQLiteClipboardStore(baseDirectory: baseDirectory)
        let migratedItems = try sqliteStore.loadItems()

        XCTAssertEqual(migratedItems.count, 1)
        XCTAssertEqual(migratedItems.first?.content, "https://example.com")
        XCTAssertEqual(migratedItems.first?.captureCount, 2)
        XCTAssertEqual(try sqliteStore.loadSettings(), legacySettings)
    }

    func testSQLiteStoreDoesNotReimportLegacyJSONAfterDatabaseExists() throws {
        let baseDirectory = makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let legacyStore = FileClipboardStore(baseDirectory: baseDirectory)
        try legacyStore.saveItems([
            ClipboardItem.make(
                content: "legacy",
                sourceAppName: "Notes",
                sourceBundleID: "com.apple.Notes"
            ),
        ])

        let firstStore = SQLiteClipboardStore(baseDirectory: baseDirectory)
        XCTAssertEqual(try firstStore.loadItems().count, 1)
        try firstStore.saveItems([])

        let secondStore = SQLiteClipboardStore(baseDirectory: baseDirectory)
        XCTAssertTrue(try secondStore.loadItems().isEmpty)
    }

    @MainActor
    func testAppStateMergesDuplicateCaptures() {
        let baseDirectory = makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let store = FileClipboardStore(baseDirectory: baseDirectory)
        let appState = AppState(store: store)

        appState.capture(content: "hello world", sourceApp: nil)
        appState.capture(content: "hello world", sourceApp: nil)

        XCTAssertEqual(appState.items.count, 1)
        XCTAssertEqual(appState.items.first?.content, "hello world")
        XCTAssertEqual(appState.items.first?.captureCount, 2)
    }

    @MainActor
    func testAppStateTrimsToDefaultTwentyItems() {
        let baseDirectory = makeTemporaryDirectory()
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
