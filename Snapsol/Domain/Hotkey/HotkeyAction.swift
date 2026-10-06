enum HotkeyAction: String, CaseIterable, Codable, Sendable {
    case captureFullscreen
    case captureWindow
    case captureArea
    case captureText

    /// ⌥1〜⌥4。キーコードは kVK_ANSI_1〜4（Domain は Carbon を import しないので数値で持つ）
    var defaultShortcut: HotkeyShortcut {
        let keyCode: UInt16 = switch self {
        case .captureFullscreen: 18
        case .captureWindow: 19
        case .captureArea: 20
        case .captureText: 21
        }
        return HotkeyShortcut(keyCode: keyCode, modifiers: .option)
    }
}
