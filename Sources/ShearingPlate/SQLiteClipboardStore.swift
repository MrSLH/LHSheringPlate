import Foundation
import SQLite3

enum SQLiteClipboardStoreError: LocalizedError {
    case openDatabase(String)
    case prepareStatement(String)
    case execute(String)
    case bind(String)
    case malformedRow(String)

    var errorDescription: String? {
        switch self {
        case .openDatabase(let message):
            return "SQLite 打开失败：\(message)"
        case .prepareStatement(let message):
            return "SQLite 语句准备失败：\(message)"
        case .execute(let message):
            return "SQLite 执行失败：\(message)"
        case .bind(let message):
            return "SQLite 参数绑定失败：\(message)"
        case .malformedRow(let message):
            return "SQLite 数据格式异常：\(message)"
        }
    }
}

final class SQLiteClipboardStore: ClipboardStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let databaseURL: URL
    private let legacyStore: FileClipboardStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let shouldAttemptLegacyMigration: Bool

    private var database: OpaquePointer?
    private var isPrepared = false

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.directoryURL = baseDirectory ?? FileClipboardStore.defaultDirectoryURL(fileManager: fileManager)
        self.databaseURL = directoryURL.appendingPathComponent("clipboard.sqlite3")
        self.legacyStore = FileClipboardStore(fileManager: fileManager, baseDirectory: self.directoryURL)
        self.shouldAttemptLegacyMigration = !fileManager.fileExists(atPath: self.databaseURL.path)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    deinit {
        sqlite3_close(database)
    }

    func loadItems() throws -> [ClipboardItem] {
        try ensurePrepared()

        let sql = """
        SELECT id, payload_json, source_app_name, source_bundle_id, captured_at, last_used_at, is_pinned, capture_count
        FROM clipboard_items
        ORDER BY captured_at DESC
        """
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
        }

        try prepare(sql: sql, statement: &statement)

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCString = sqlite3_column_text(statement, 0),
                let payloadBytes = sqlite3_column_blob(statement, 1)
            else {
                throw SQLiteClipboardStoreError.malformedRow("缺少必填字段。")
            }

            let payloadLength = Int(sqlite3_column_bytes(statement, 1))
            let payloadData = Data(bytes: payloadBytes, count: payloadLength)
            let payload = try decoder.decode(ClipboardPayload.self, from: payloadData)

            let idString = String(cString: idCString)
            guard let id = UUID(uuidString: idString) else {
                throw SQLiteClipboardStoreError.malformedRow("无效的 UUID：\(idString)")
            }

            let sourceAppName = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let sourceBundleID = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            let capturedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            let lastUsedAt: Date? = sqlite3_column_type(statement, 5) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
            let isPinned = sqlite3_column_int(statement, 6) != 0
            let captureCount = Int(sqlite3_column_int(statement, 7))

            items.append(
                ClipboardItem(
                    id: id,
                    payload: payload,
                    sourceAppName: sourceAppName,
                    sourceBundleID: sourceBundleID,
                    capturedAt: capturedAt,
                    lastUsedAt: lastUsedAt,
                    isPinned: isPinned,
                    captureCount: captureCount
                )
            )
        }

        return items
    }

    func saveItems(_ items: [ClipboardItem]) throws {
        try ensurePrepared()
        try execute(sql: "BEGIN IMMEDIATE TRANSACTION")

        do {
            try execute(sql: "DELETE FROM clipboard_items")

            let sql = """
            INSERT INTO clipboard_items (
                id, kind, payload_json, preview, searchable_text, source_app_name, source_bundle_id,
                captured_at, last_used_at, is_pinned, capture_count, content_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            var statement: OpaquePointer?
            defer {
                sqlite3_finalize(statement)
            }

            try prepare(sql: sql, statement: &statement)

            for item in items {
                try bind(item: item, to: statement)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw SQLiteClipboardStoreError.execute(lastErrorMessage())
                }

                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
            }

            try execute(sql: "COMMIT")
        } catch {
            try? execute(sql: "ROLLBACK")
            throw error
        }
    }

    func loadSettings() throws -> AppSettings {
        try ensurePrepared()

        let sql = "SELECT value_json FROM app_settings WHERE key = ? LIMIT 1"
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
        }

        try prepare(sql: sql, statement: &statement)
        try bind(text: "settings", index: 1, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return AppSettings()
        }

        guard let bytes = sqlite3_column_blob(statement, 0) else {
            return AppSettings()
        }

        let length = Int(sqlite3_column_bytes(statement, 0))
        let data = Data(bytes: bytes, count: length)
        return try decoder.decode(AppSettings.self, from: data)
    }

    func saveSettings(_ settings: AppSettings) throws {
        try ensurePrepared()

        let sql = """
        INSERT INTO app_settings (key, value_json)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value_json = excluded.value_json
        """
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
        }

        try prepare(sql: sql, statement: &statement)
        try bind(text: "settings", index: 1, statement: statement)

        let data = try encoder.encode(settings)
        try bind(data: data, index: 2, statement: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteClipboardStoreError.execute(lastErrorMessage())
        }
    }

    private func ensurePrepared() throws {
        try connectIfNeeded()

        guard !isPrepared else {
            return
        }

        try ensureDirectoryExists()
        try createSchema()
        isPrepared = true

        do {
            try migrateLegacyIfNeeded()
        } catch {
            isPrepared = false
            throw error
        }
    }

    private func connectIfNeeded() throws {
        guard database == nil else {
            return
        }

        try ensureDirectoryExists()

        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
            sqlite3_close(db)
            throw SQLiteClipboardStoreError.openDatabase(message)
        }

        database = db
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func createSchema() throws {
        try execute(sql: """
        CREATE TABLE IF NOT EXISTS clipboard_items (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            payload_json BLOB NOT NULL,
            preview TEXT NOT NULL,
            searchable_text TEXT NOT NULL,
            source_app_name TEXT,
            source_bundle_id TEXT,
            captured_at REAL NOT NULL,
            last_used_at REAL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            capture_count INTEGER NOT NULL DEFAULT 1,
            content_hash TEXT NOT NULL UNIQUE
        )
        """)

        try execute(sql: """
        CREATE INDEX IF NOT EXISTS idx_clipboard_items_captured_at
        ON clipboard_items(captured_at DESC)
        """)

        try execute(sql: """
        CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY NOT NULL,
            value_json BLOB NOT NULL
        )
        """)
    }

    private func migrateLegacyIfNeeded() throws {
        guard shouldAttemptLegacyMigration else {
            return
        }

        guard try isClipboardTableEmpty() else {
            return
        }

        let legacyItems = try legacyStore.loadItems()
        let legacySettings = try legacyStore.loadSettings()

        if !legacyItems.isEmpty {
            try saveItems(Self.mergeDuplicateItems(legacyItems))
        }

        if fileManager.fileExists(atPath: directoryURL.appendingPathComponent("settings.json").path) {
            try saveSettings(legacySettings)
        }
    }

    private func isClipboardTableEmpty() throws -> Bool {
        let sql = "SELECT COUNT(*) FROM clipboard_items"
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
        }

        try prepare(sql: sql, statement: &statement)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return true
        }

        return sqlite3_column_int(statement, 0) == 0
    }

    private func prepare(sql: String, statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteClipboardStoreError.prepareStatement(lastErrorMessage())
        }
    }

    private func execute(sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteClipboardStoreError.execute(lastErrorMessage())
        }
    }

    private func bind(item: ClipboardItem, to statement: OpaquePointer?) throws {
        try bind(text: item.id.uuidString, index: 1, statement: statement)
        try bind(text: item.kind.rawValue, index: 2, statement: statement)
        try bind(data: encoder.encode(item.payload), index: 3, statement: statement)
        try bind(text: item.preview, index: 4, statement: statement)
        try bind(text: item.searchableText, index: 5, statement: statement)
        try bind(optionalText: item.sourceAppName, index: 6, statement: statement)
        try bind(optionalText: item.sourceBundleID, index: 7, statement: statement)
        guard sqlite3_bind_double(statement, 8, item.capturedAt.timeIntervalSince1970) == SQLITE_OK else {
            throw SQLiteClipboardStoreError.bind(lastErrorMessage())
        }

        if let lastUsedAt = item.lastUsedAt {
            guard sqlite3_bind_double(statement, 9, lastUsedAt.timeIntervalSince1970) == SQLITE_OK else {
                throw SQLiteClipboardStoreError.bind(lastErrorMessage())
            }
        } else {
            guard sqlite3_bind_null(statement, 9) == SQLITE_OK else {
                throw SQLiteClipboardStoreError.bind(lastErrorMessage())
            }
        }

        guard sqlite3_bind_int(statement, 10, item.isPinned ? 1 : 0) == SQLITE_OK else {
            throw SQLiteClipboardStoreError.bind(lastErrorMessage())
        }
        guard sqlite3_bind_int(statement, 11, Int32(item.captureCount)) == SQLITE_OK else {
            throw SQLiteClipboardStoreError.bind(lastErrorMessage())
        }
        try bind(text: item.contentHash, index: 12, statement: statement)
    }

    private func bind(text: String, index: Int32, statement: OpaquePointer?) throws {
        guard sqlite3_bind_text(statement, index, text, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw SQLiteClipboardStoreError.bind(lastErrorMessage())
        }
    }

    private func bind(optionalText: String?, index: Int32, statement: OpaquePointer?) throws {
        if let value = optionalText {
            try bind(text: value, index: index, statement: statement)
            return
        }

        guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
            throw SQLiteClipboardStoreError.bind(lastErrorMessage())
        }
    }

    private func bind(data: Data, index: Int32, statement: OpaquePointer?) throws {
        let status = data.withUnsafeBytes { rawBuffer in
            sqlite3_bind_blob(statement, index, rawBuffer.baseAddress, Int32(rawBuffer.count), SQLITE_TRANSIENT)
        }

        guard status == SQLITE_OK else {
            throw SQLiteClipboardStoreError.bind(lastErrorMessage())
        }
    }

    private func lastErrorMessage() -> String {
        database.map { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
    }

    private static func mergeDuplicateItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        var mergedByHash: [String: ClipboardItem] = [:]

        for item in items.sorted(by: { $0.capturedAt > $1.capturedAt }) {
            if let existing = mergedByHash[item.contentHash] {
                mergedByHash[item.contentHash] = ClipboardItem(
                    id: existing.id,
                    payload: existing.payload,
                    sourceAppName: existing.sourceAppName ?? item.sourceAppName,
                    sourceBundleID: existing.sourceBundleID ?? item.sourceBundleID,
                    capturedAt: max(existing.capturedAt, item.capturedAt),
                    lastUsedAt: max(existing.lastUsedAt ?? .distantPast, item.lastUsedAt ?? .distantPast) == .distantPast
                        ? nil
                        : max(existing.lastUsedAt ?? .distantPast, item.lastUsedAt ?? .distantPast),
                    isPinned: existing.isPinned || item.isPinned,
                    captureCount: existing.captureCount + item.captureCount
                )
            } else {
                mergedByHash[item.contentHash] = item
            }
        }

        return mergedByHash.values.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            return lhs.capturedAt > rhs.capturedAt
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
