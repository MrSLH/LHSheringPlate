import AppKit
import Combine
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SQLiteClipboardStore()
    private lazy var appState = AppState(store: store)
    private let clipboardMonitor = ClipboardMonitor()
    private let launchAtLoginController = LaunchAtLoginController()
    private let hotKeyController = HotKeyController()

    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.clipboardWriter = { [weak self] item in
            self?.clipboardMonitor.writeToPasteboard(item)
        }
        appState.launchAtLoginUpdater = { [weak self] isEnabled in
            guard let self else {
                return LaunchAtLoginStatusSnapshot.disabledFallback()
            }

            return try self.launchAtLoginController.setEnabled(isEnabled)
        }
        appState.launchAtLoginStatusProvider = { [weak self] in
            self?.launchAtLoginController.currentStatus ?? LaunchAtLoginStatusSnapshot.disabledFallback()
        }
        appState.hotKeyUpdater = { [weak self] isEnabled, shortcut in
            guard let self else {
                return HotKeyRegistrationResult(isEnabled: isEnabled, shortcut: shortcut, statusMessage: nil)
            }

            return try self.hotKeyController.updateRegistration(isEnabled: isEnabled, shortcut: shortcut)
        }

        clipboardMonitor.onCapture = { [weak self] payload, sourceApp in
            self?.appState.capture(payload: payload, sourceApp: sourceApp)
        }
        hotKeyController.onHotKey = { [weak self] in
            self?.statusBarController?.togglePanel()
        }

        observeSettings()

        statusBarController = StatusBarController(
            appState: appState,
            openSettings: { [weak self] in
                self?.presentSettingsWindow()
            },
            quitApp: {
                NSApp.terminate(nil)
            }
        )

        appState.syncLaunchAtLoginStatus(launchAtLoginController.currentStatus)
        apply(settings: appState.settings)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.persist()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState.refreshLaunchAtLoginStatus()
    }

    private func observeSettings() {
        appState.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.apply(settings: settings)
            }
            .store(in: &cancellables)
    }

    private func apply(settings: AppSettings) {
        clipboardMonitor.updatePollInterval(settings.pollInterval)

        do {
            let result = try hotKeyController.updateRegistration(
                isEnabled: settings.globalShortcutEnabled,
                shortcut: settings.globalShortcut
            )
            appState.updateGlobalShortcutStatusMessage(result.statusMessage)
        } catch {
            appState.lastErrorMessage = "快捷键注册失败：\(error.localizedDescription)"
        }

        if settings.isPaused {
            clipboardMonitor.stop()
        } else {
            clipboardMonitor.start()
        }

        statusBarController?.updatePauseState(settings.isPaused)
    }

    private func presentSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appState: appState)
        }

        appState.refreshLaunchAtLoginStatus()
        settingsWindowController?.showWindow(nil)
    }
}
