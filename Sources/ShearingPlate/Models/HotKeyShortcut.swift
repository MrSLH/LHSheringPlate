import AppKit
import Carbon
import Foundation

struct HotKeyShortcut: Codable, Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let defaultShortcut = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    var isValid: Bool {
        carbonModifiers & UInt32(cmdKey | optionKey | controlKey | shiftKey) != 0
    }

    var displayString: String {
        Self.displayString(for: self)
    }

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(event: NSEvent) {
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)

        guard modifiers != 0 else {
            return nil
        }

        guard !Self.modifierOnlyKeyCodes.contains(event.keyCode) else {
            return nil
        }

        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0

        if flags.contains(.command) {
            result |= UInt32(cmdKey)
        }

        if flags.contains(.shift) {
            result |= UInt32(shiftKey)
        }

        if flags.contains(.option) {
            result |= UInt32(optionKey)
        }

        if flags.contains(.control) {
            result |= UInt32(controlKey)
        }

        return result
    }

    static func displayString(for shortcut: HotKeyShortcut) -> String {
        var parts: [String] = []

        if shortcut.carbonModifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        if shortcut.carbonModifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }

        if shortcut.carbonModifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }

        if shortcut.carbonModifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }

        parts.append(keyLabel(for: shortcut.keyCode))
        return parts.joined()
    }

    private static func keyLabel(for keyCode: UInt32) -> String {
        keyMap[keyCode] ?? "Key \(keyCode)"
    }

    private static let modifierOnlyKeyCodes: Set<UInt16> = [
        UInt16(kVK_Command),
        UInt16(kVK_RightCommand),
        UInt16(kVK_Shift),
        UInt16(kVK_RightShift),
        UInt16(kVK_Option),
        UInt16(kVK_RightOption),
        UInt16(kVK_Control),
        UInt16(kVK_RightControl),
        UInt16(kVK_CapsLock),
        UInt16(kVK_Function),
    ]

    private static let keyMap: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_ANSI_Minus): "-",
        UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[",
        UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Backslash): "\\",
        UInt32(kVK_ANSI_Grave): "`",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Delete): "Delete",
        UInt32(kVK_ForwardDelete): "ForwardDelete",
        UInt32(kVK_Escape): "Esc",
        UInt32(kVK_Home): "Home",
        UInt32(kVK_End): "End",
        UInt32(kVK_PageUp): "PageUp",
        UInt32(kVK_PageDown): "PageDown",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12",
    ]
}
