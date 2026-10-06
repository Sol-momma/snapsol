import Foundation

/// デフォルトと異なるキーだけを JSON で 1 キーに保存する。
/// デフォルト値を将来変えても、ユーザーが変更していないアクションには新しい値が効く。
@MainActor
struct UserDefaultsHotkeyStore: HotkeyShortcutStore {
    static let key = "hotkeys.v1"
    let defaults: UserDefaults

    func load() -> [HotkeyAction: HotkeyShortcut] {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode([String: HotkeyShortcut].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, shortcut in
            HotkeyAction(rawValue: key).map { ($0, shortcut) }
        })
    }

    func save(_ bindings: [HotkeyAction: HotkeyShortcut]) throws {
        let overrides = bindings.filter { $0.value != $0.key.defaultShortcut }
        let stored = Dictionary(uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value) })
        defaults.set(try JSONEncoder().encode(stored), forKey: Self.key)
    }
}
