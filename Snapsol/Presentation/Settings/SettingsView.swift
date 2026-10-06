import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let hotkeys: HotkeyBindingService

    var body: some View {
        Form {
            Section("ホットキー") {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    HotkeyRow(action: action, hotkeys: hotkeys)
                }
            }

            Section("撮影後に行うこと") {
                Toggle("プレビューカードを表示", isOn: afterCapture(.showCard))
                Toggle("クリップボードにコピー", isOn: afterCapture(.copyToClipboard))
                Toggle("注釈エディタを開く", isOn: afterCapture(.openEditor))
            }

            Section("プレビューカード") {
                Picker("自動で閉じるまで", selection: $settings.cardLifetime) {
                    Text("3 秒").tag(3.0)
                    Text("6 秒").tag(6.0)
                    Text("10 秒").tag(10.0)
                    Text("20 秒").tag(20.0)
                    Text("閉じない").tag(0.0)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func afterCapture(_ action: AfterCaptureActions) -> Binding<Bool> {
        Binding(
            get: { settings.afterCapture.contains(action) },
            set: { isOn in
                if isOn { settings.afterCapture.insert(action) } else { settings.afterCapture.remove(action) }
            }
        )
    }
}

private struct HotkeyRow: View {
    let action: HotkeyAction
    let hotkeys: HotkeyBindingService
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(action.menuTitle)
                Spacer()
                HotkeyRecorderButton(
                    shortcut: hotkeys.bindings[action],
                    onRecordingChanged: { hotkeys.setSuspended($0) },
                    onRecord: { rebind(to: $0) }
                )
                Button("既定に戻す") { rebind(to: action.defaultShortcut) }
                    .disabled(hotkeys.bindings[action] == action.defaultShortcut && !hotkeys.failedActions.contains(action))
            }
            if let message = errorMessage ?? (hotkeys.failedActions.contains(action) ? "このキーを登録できませんでした。別のキーを設定してください" : nil) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func rebind(to shortcut: HotkeyShortcut) {
        do {
            try hotkeys.rebind(action, to: shortcut)
            errorMessage = nil
        } catch let error as HotkeyBindingError {
            errorMessage = switch error {
            case .invalid: "⌘ ⌥ ⌃ ⇧ のいずれかと組み合わせてください"
            case .conflict(let other): "「\(other.menuTitle)」と同じキーです"
            case .registrationFailed: "このキーは他のアプリかシステムが使用しています"
            }
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
