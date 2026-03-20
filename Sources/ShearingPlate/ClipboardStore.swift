import Foundation

protocol ClipboardStore {
    func loadItems() throws -> [ClipboardItem]
    func saveItems(_ items: [ClipboardItem]) throws
    func loadSettings() throws -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
}

final class FileClipboardStore: ClipboardStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let itemsURL: URL
    private let settingsURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.directoryURL = baseDirectory ?? Self.defaultDirectoryURL(fileManager: fileManager)
        self.itemsURL = directoryURL.appendingPathComponent("clip-items.json")
        self.settingsURL = directoryURL.appendingPathComponent("settings.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadItems() throws -> [ClipboardItem] {
        try load([ClipboardItem].self, from: itemsURL, fallback: [])
    }

    func saveItems(_ items: [ClipboardItem]) throws {
        try save(items, to: itemsURL)
    }

    func loadSettings() throws -> AppSettings {
        try load(AppSettings.self, from: settingsURL, fallback: AppSettings())
    }

    func saveSettings(_ settings: AppSettings) throws {
        try save(settings, to: settingsURL)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL, fallback: @autoclosure () -> T) throws -> T {
        guard fileManager.fileExists(atPath: url.path) else {
            return fallback()
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("Application Support")

        return baseURL.appendingPathComponent("ShearingPlate", isDirectory: true)
    }
}
