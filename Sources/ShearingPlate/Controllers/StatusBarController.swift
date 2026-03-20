import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(appState: AppState, openSettings: @escaping () -> Void, quitApp: @escaping () -> Void) {
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPanelView(
                appState: appState,
                openSettings: openSettings,
                quitApp: quitApp
            )
        )

        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        updatePauseState(appState.settings.isPaused)
    }

    func togglePanel() {
        togglePopover(nil)
    }

    func updatePauseState(_ isPaused: Bool) {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(
            systemSymbolName: isPaused ? "pause.circle.fill" : "doc.on.clipboard.fill",
            accessibilityDescription: "ShearingPlate"
        )
        button.toolTip = isPaused ? "ShearingPlate 已暂停记录" : "ShearingPlate 正在记录剪贴板"
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
    }
}
