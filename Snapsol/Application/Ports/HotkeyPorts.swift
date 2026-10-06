/// OS に登録したホットキー 1 件を指すトークン
struct HotkeyRegistration: Hashable, Sendable {
    let id: UInt32
}

@MainActor
protocol HotkeyRegistering: AnyObject {
    /// 登録に失敗したら throw し、状態は何も変えない
    func register(_ shortcut: HotkeyShortcut) throws -> HotkeyRegistration
    func unregister(_ registration: HotkeyRegistration)
    var onPressed: ((HotkeyRegistration) -> Void)? { get set }
}

@MainActor
protocol HotkeyShortcutStore {
    func load() -> [HotkeyAction: HotkeyShortcut]
    func save(_ bindings: [HotkeyAction: HotkeyShortcut]) throws
}
