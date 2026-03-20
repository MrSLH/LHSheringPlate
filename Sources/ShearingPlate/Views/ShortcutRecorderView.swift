import AppKit
import Carbon
import SwiftUI

@MainActor
final class ShortcutRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?

    private var eventMonitor: Any?
    private var onShortcutCaptured: ((HotKeyShortcut) -> Void)?

    func toggleRecording(onShortcutCaptured: @escaping (HotKeyShortcut) -> Void) {
        if isRecording {
            stopRecording()
            return
        }

        startRecording(onShortcutCaptured: onShortcutCaptured)
    }

    func stopRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        isRecording = false
    }

    private func startRecording(onShortcutCaptured: @escaping (HotKeyShortcut) -> Void) {
        stopRecording()
        errorMessage = nil
        isRecording = true
        self.onShortcutCaptured = onShortcutCaptured

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
        }
    }

    private func handle(event: NSEvent) -> NSEvent? {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return nil
        }

        guard let shortcut = HotKeyShortcut(event: event) else {
            errorMessage = "快捷键至少需要一个修饰键，且不能只按修饰键。按 Esc 取消。"
            NSSound.beep()
            return nil
        }

        onShortcutCaptured?(shortcut)
        stopRecording()
        return nil
    }
}

struct ShortcutRecorderView: View {
    let shortcut: HotKeyShortcut
    let isEnabled: Bool
    let statusMessage: String?
    let onShortcutCaptured: (HotKeyShortcut) -> Void
    let onRestoreDefault: () -> Void

    @StateObject private var recorder = ShortcutRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("打开面板快捷键")
                Spacer()
                Text(shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }

            HStack {
                Button(recorder.isRecording ? "按 Esc 取消录制" : "录制快捷键") {
                    recorder.toggleRecording(onShortcutCaptured: onShortcutCaptured)
                }

                Button("恢复默认", action: onRestoreDefault)
            }

            if recorder.isRecording {
                Text("请直接按下新的快捷键组合。建议包含 Command、Shift、Option、Control 中的至少一个。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = recorder.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            recorder.stopRecording()
        }
    }
}
