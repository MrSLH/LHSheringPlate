import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(appState: AppState) {
        let contentViewController = NSHostingController(rootView: SettingsView(appState: appState))
        let window = NSWindow(contentViewController: contentViewController)
        window.title = "ShearingPlate 设置"
        window.setContentSize(NSSize(width: 480, height: 460))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
