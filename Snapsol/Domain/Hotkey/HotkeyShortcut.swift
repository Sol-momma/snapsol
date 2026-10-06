/// グローバルホットキー 1 つ分。Carbon に依存しないよう、修飾キーは独自の OptionSet で持つ。
struct HotkeyShortcut: Codable, Hashable, Sendable {
    struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        let rawValue: Int

        static let command = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let shift = Modifiers(rawValue: 1 << 3)
    }

    /// 仮想キーコード（Carbon の kVK_* と同じ値）
    var keyCode: UInt16
    var modifiers: Modifiers

    /// 修飾キーなしの単キーは、普段のタイピングを奪ってしまうので許可しない
    var isValid: Bool { !modifiers.isEmpty }
}
