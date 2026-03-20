import Foundation

struct AppSettings: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case isPaused
        case launchAtLoginEnabled
        case globalShortcutEnabled
        case globalShortcut
        case maxItems
        case ignoredBundleIDs
        case pollInterval
    }

    static let defaultIgnoredBundleIDs = [
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.1password.1password7",
        "com.agilebits.onepassword8",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.microsoft.rdc.macos",
        "com.microsoft.rdc.mac",
    ]

    static let defaultPollInterval: TimeInterval = 0.4

    var isPaused = false
    var launchAtLoginEnabled = false
    var globalShortcutEnabled = true
    var globalShortcut = HotKeyShortcut.defaultShortcut
    var maxItems = 20
    var ignoredBundleIDs = AppSettings.defaultIgnoredBundleIDs
    var pollInterval = AppSettings.defaultPollInterval

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? false
        globalShortcutEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalShortcutEnabled) ?? true
        globalShortcut = try container.decodeIfPresent(HotKeyShortcut.self, forKey: .globalShortcut) ?? .defaultShortcut
        maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems) ?? 20
        ignoredBundleIDs = try container.decodeIfPresent([String].self, forKey: .ignoredBundleIDs) ?? Self.defaultIgnoredBundleIDs
        pollInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .pollInterval) ?? Self.defaultPollInterval
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(launchAtLoginEnabled, forKey: .launchAtLoginEnabled)
        try container.encode(globalShortcutEnabled, forKey: .globalShortcutEnabled)
        try container.encode(globalShortcut, forKey: .globalShortcut)
        try container.encode(maxItems, forKey: .maxItems)
        try container.encode(ignoredBundleIDs, forKey: .ignoredBundleIDs)
        try container.encode(pollInterval, forKey: .pollInterval)
    }
}
