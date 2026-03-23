import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private static let activeStatusImage = makeActiveStatusImage()

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

        button.image = isPaused
            ? NSImage(
                systemSymbolName: "pause.circle.fill",
                accessibilityDescription: "ShearingPlate"
            )
            : Self.activeStatusImage
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

    private static func makeActiveStatusImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        NSColor.labelColor.setStroke()

        let body = NSBezierPath(
            roundedRect: NSRect(x: 2.75, y: 2.25, width: 10.5, height: 11.75),
            xRadius: 2.4,
            yRadius: 2.4
        )
        body.lineWidth = 1.5
        body.stroke()

        let clip = NSBezierPath(
            roundedRect: NSRect(x: 5.35, y: 12.75, width: 5.3, height: 2.7),
            xRadius: 1.35,
            yRadius: 1.35
        )
        clip.lineWidth = 1.5
        clip.stroke()

        drawStatusLine(from: CGPoint(x: 5.0, y: 10.1), to: CGPoint(x: 11.0, y: 10.1))
        drawStatusLine(from: CGPoint(x: 5.0, y: 7.4), to: CGPoint(x: 11.0, y: 7.4))
        drawStatusLine(from: CGPoint(x: 5.0, y: 4.7), to: CGPoint(x: 9.6, y: 4.7))

        let historyBadge = NSBezierPath(roundedRect: NSRect(x: 12.85, y: 4.1, width: 2.35, height: 7.55), xRadius: 1.0, yRadius: 1.0)
        historyBadge.lineWidth = 1.5
        historyBadge.stroke()

        drawStatusLine(from: CGPoint(x: 13.65, y: 9.4), to: CGPoint(x: 14.4, y: 9.4))
        drawStatusLine(from: CGPoint(x: 13.65, y: 7.85), to: CGPoint(x: 14.9, y: 7.85))
        drawStatusLine(from: CGPoint(x: 13.65, y: 6.3), to: CGPoint(x: 14.2, y: 6.3))

        return image
    }

    private static func drawStatusLine(from start: CGPoint, to end: CGPoint) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.stroke()
    }
}
