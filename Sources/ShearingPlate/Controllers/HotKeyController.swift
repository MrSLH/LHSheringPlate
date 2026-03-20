import Carbon
import Foundation

struct HotKeyRegistrationResult {
    let isEnabled: Bool
    let shortcut: HotKeyShortcut
    let statusMessage: String?
}

enum HotKeyRegistrationError: LocalizedError {
    case invalidShortcut
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            return "快捷键必须包含至少一个修饰键，且不能只按修饰键。"
        case .registrationFailed(let status):
            return "系统拒绝注册这个快捷键，错误码：\(status)。可能与系统或其他应用冲突。"
        }
    }
}

@MainActor
final class HotKeyController {
    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: HotKeyController.signature, id: 1)

    func updateRegistration(isEnabled: Bool, shortcut: HotKeyShortcut) throws -> HotKeyRegistrationResult {
        unregister()

        guard isEnabled else {
            return HotKeyRegistrationResult(
                isEnabled: false,
                shortcut: shortcut,
                statusMessage: "全局快捷键已关闭。"
            )
        }

        guard shortcut.isValid else {
            throw HotKeyRegistrationError.invalidShortcut
        }

        installEventHandlerIfNeeded()

        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            throw HotKeyRegistrationError.registrationFailed(status)
        }

        return HotKeyRegistrationResult(
            isEnabled: true,
            shortcut: shortcut,
            statusMessage: "全局快捷键已启用：\(shortcut.displayString)"
        )
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
                return controller.handleEvent(event)
            },
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )
    }

    private func handleEvent(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }

        var pressedHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedHotKeyID
        )

        guard status == noErr,
              pressedHotKeyID.signature == Self.signature,
              pressedHotKeyID.id == hotKeyID.id else {
            return status
        }

        onHotKey?()
        return noErr
    }

    private static let signature: OSType = {
        let scalars = Array("SPHK".unicodeScalars)
        return scalars.reduce(0) { partialResult, scalar in
            (partialResult << 8) + scalar.value
        }
    }()
}
