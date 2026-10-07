import Observation

enum HotkeyBindingError: Error, Equatable {
    /// 修飾キーがない
    case invalid
    /// Snapsol の別アクションが同じキーを使っている
    case conflict(HotkeyAction)
    /// OS への登録に失敗した（他アプリやシステムが使用中など）
    case registrationFailed
}

/// アクションとホットキーの対応を管理する。OS 登録は `HotkeyRegistering`、保存は `HotkeyShortcutStore` に任せる。
@MainActor
@Observable
final class HotkeyBindingService {
    private(set) var bindings: [HotkeyAction: HotkeyShortcut] = [:]
    /// 起動時に登録できなかったアクション（設定画面で警告を出す）
    private(set) var failedActions: Set<HotkeyAction> = []
    @ObservationIgnored var onAction: ((HotkeyAction) -> Void)?

    @ObservationIgnored private var registrations: [HotkeyAction: HotkeyRegistration] = [:]
    @ObservationIgnored private let registrar: any HotkeyRegistering
    @ObservationIgnored private let store: any HotkeyShortcutStore

    init(registrar: any HotkeyRegistering, store: any HotkeyShortcutStore) {
        self.registrar = registrar
        self.store = store
        registrar.onPressed = { [weak self] registration in self?.handlePress(registration) }
    }

    func start() {
        let saved = store.load()
        for action in HotkeyAction.allCases {
            bindings[action] = saved[action] ?? action.defaultShortcut
        }
        registerUnregistered()
    }

    /// 新キーの登録 → 保存 → 旧キーの解除 の順に行う。
    /// どこかで失敗したら、旧キー・保存値・`bindings` はすべて元のまま残る。
    func rebind(_ action: HotkeyAction, to shortcut: HotkeyShortcut) throws {
        guard shortcut.isValid else { throw HotkeyBindingError.invalid }
        // 同じアプリが同じキーを二重登録すると OS がエラーを返すので、変化なしは何もしない
        if bindings[action] == shortcut, registrations[action] != nil { return }
        if let other = conflictingAction(for: shortcut, excluding: action) {
            throw HotkeyBindingError.conflict(other)
        }

        let newRegistration: HotkeyRegistration
        do {
            newRegistration = try registrar.register(shortcut)
        } catch {
            throw HotkeyBindingError.registrationFailed
        }

        var updated = bindings
        updated[action] = shortcut
        do {
            try store.save(updated)
        } catch {
            registrar.unregister(newRegistration)
            throw error
        }

        if let old = registrations[action] {
            registrar.unregister(old)
        }
        registrations[action] = newRegistration
        bindings = updated
        failedActions.remove(action)
    }

    func conflictingAction(for shortcut: HotkeyShortcut, excluding action: HotkeyAction) -> HotkeyAction? {
        bindings.first { $0.key != action && $0.value == shortcut }?.key
    }

    /// キー録音中は一時的に全解除する。そうしないと録音しようとしたキーで撮影が始まってしまう。
    /// 録音中に rebind されたアクションは登録済みなので、再開時は未登録のものだけを登録し直す
    func setSuspended(_ suspended: Bool) {
        if suspended {
            registrations.values.forEach(registrar.unregister)
            registrations.removeAll()
        } else {
            registerUnregistered()
        }
    }

    private func registerUnregistered() {
        for action in HotkeyAction.allCases where registrations[action] == nil {
            guard let shortcut = bindings[action] else { continue }
            do {
                registrations[action] = try registrar.register(shortcut)
                failedActions.remove(action)
            } catch {
                failedActions.insert(action)
            }
        }
    }

    private func handlePress(_ registration: HotkeyRegistration) {
        guard let action = registrations.first(where: { $0.value == registration })?.key else { return }
        onAction?(action)
    }
}
