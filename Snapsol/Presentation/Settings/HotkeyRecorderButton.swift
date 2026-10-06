import AppKit
import Carbon.HIToolbox
import SwiftUI

/// クリックすると次に押したキーの組み合わせを記録するボタン。Esc で取り消し。
struct HotkeyRecorderButton: View {
    let shortcut: HotkeyShortcut?
    /// 記録の開始・終了を知らせる（記録中はグローバルホットキーを止めるため）
    let onRecordingChanged: (Bool) -> Void
    let onRecord: (HotkeyShortcut) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? "キーを押してください…" : shortcut.map(KeyLabel.string(for:)) ?? "未設定")
                .monospaced()
                .frame(minWidth: 130)
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        onRecordingChanged(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = HotkeyShortcut.Modifiers(event.modifierFlags)
            if event.keyCode == UInt16(kVK_Escape), modifiers.isEmpty {
                stop()
            } else {
                onRecord(HotkeyShortcut(keyCode: event.keyCode, modifiers: modifiers))
                stop()
            }
            return nil // 記録したキーを他へ流さない
        }
    }

    private func stop() {
        guard isRecording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        onRecordingChanged(false)
    }
}
