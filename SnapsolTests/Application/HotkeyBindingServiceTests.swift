import Testing

/// 呼び出し順を記録し、指定したキーの登録だけ失敗させられる
@MainActor
private final class FakeRegistrar: HotkeyRegistering {
    enum Call: Equatable {
        case register(HotkeyShortcut)
        case unregister(UInt32)
    }

    var onPressed: ((HotkeyRegistration) -> Void)?
    var log: [Call] = []
    var failing: Set<HotkeyShortcut> = []
    private(set) var active: [UInt32: HotkeyShortcut] = [:]
    private var nextID: UInt32 = 1

    struct Failed: Error {}

    func register(_ shortcut: HotkeyShortcut) throws -> HotkeyRegistration {
        log.append(.register(shortcut))
        if failing.contains(shortcut) { throw Failed() }
        defer { nextID += 1 }
        active[nextID] = shortcut
        return HotkeyRegistration(id: nextID)
    }

    func unregister(_ registration: HotkeyRegistration) {
        log.append(.unregister(registration.id))
        active.removeValue(forKey: registration.id)
    }

    func press(_ shortcut: HotkeyShortcut) {
        guard let id = active.first(where: { $0.value == shortcut })?.key else { return }
        onPressed?(HotkeyRegistration(id: id))
    }
}

@MainActor
private final class FakeStore: HotkeyShortcutStore {
    var saved: [HotkeyAction: HotkeyShortcut] = [:]
    var failsOnSave = false

    struct Failed: Error {}

    func load() -> [HotkeyAction: HotkeyShortcut] { saved }

    func save(_ bindings: [HotkeyAction: HotkeyShortcut]) throws {
        if failsOnSave { throw Failed() }
        saved = bindings
    }
}

@MainActor
struct HotkeyBindingServiceTests {
    private let registrar = FakeRegistrar()
    private let store = FakeStore()
    private let commandShift5 = HotkeyShortcut(keyCode: 23, modifiers: [.command, .shift])

    private func startedService() -> HotkeyBindingService {
        let service = HotkeyBindingService(registrar: registrar, store: store)
        service.start()
        registrar.log.removeAll()
        return service
    }

    @Test func 起動時はデフォルトキーを登録する() {
        let service = startedService()
        #expect(service.bindings[.captureArea] == HotkeyAction.captureArea.defaultShortcut)
        #expect(Set(registrar.active.values) == Set(HotkeyAction.allCases.map(\.defaultShortcut)))
    }

    @Test func 保存済みのキーがあればそれを使う() {
        store.saved = [.captureArea: commandShift5]
        let service = startedService()
        #expect(service.bindings[.captureArea] == commandShift5)
    }

    @Test func 起動時に登録できなかったアクションを記録する() {
        registrar.failing = [HotkeyAction.captureText.defaultShortcut]
        let service = startedService()
        #expect(service.failedActions == [.captureText])
    }

    @Test func 押されたキーに対応するアクションが呼ばれる() {
        let service = startedService()
        var performed: [HotkeyAction] = []
        service.onAction = { performed.append($0) }

        registrar.press(HotkeyAction.captureWindow.defaultShortcut)
        #expect(performed == [.captureWindow])
    }

    @Test func 変更は新キー登録のあとに旧キーを解除し保存する() throws {
        let service = startedService()
        try service.rebind(.captureArea, to: commandShift5)

        #expect(registrar.log.first == .register(commandShift5))
        #expect(registrar.log.count == 2)
        #expect(!registrar.active.values.contains(HotkeyAction.captureArea.defaultShortcut))
        #expect(service.bindings[.captureArea] == commandShift5)
        #expect(store.saved[.captureArea] == commandShift5)
    }

    @Test func 登録に失敗したら旧キーも保存値も変わらない() {
        let service = startedService()
        registrar.failing = [commandShift5]

        #expect(throws: HotkeyBindingError.registrationFailed) {
            try service.rebind(.captureArea, to: commandShift5)
        }
        #expect(service.bindings[.captureArea] == HotkeyAction.captureArea.defaultShortcut)
        #expect(registrar.active.values.contains(HotkeyAction.captureArea.defaultShortcut))
        #expect(store.saved.isEmpty)
    }

    @Test func 保存に失敗したら新キーの登録を取り消す() {
        let service = startedService()
        store.failsOnSave = true

        #expect(throws: FakeStore.Failed.self) {
            try service.rebind(.captureArea, to: commandShift5)
        }
        #expect(!registrar.active.values.contains(commandShift5))
        #expect(registrar.active.values.contains(HotkeyAction.captureArea.defaultShortcut))
    }

    @Test func 他のアクションと同じキーは拒否する() {
        let service = startedService()
        #expect(throws: HotkeyBindingError.conflict(.captureWindow)) {
            try service.rebind(.captureArea, to: HotkeyAction.captureWindow.defaultShortcut)
        }
        #expect(registrar.log.isEmpty)
    }

    @Test func 修飾キーなしは拒否する() {
        let service = startedService()
        #expect(throws: HotkeyBindingError.invalid) {
            try service.rebind(.captureArea, to: HotkeyShortcut(keyCode: 0, modifiers: []))
        }
    }

    @Test func 同じキーへの変更は何もしない() throws {
        let service = startedService()
        try service.rebind(.captureArea, to: HotkeyAction.captureArea.defaultShortcut)
        #expect(registrar.log.isEmpty)
    }

    @Test func 一時停止中は全解除し再開で登録し直す() {
        let service = startedService()
        service.setSuspended(true)
        #expect(registrar.active.isEmpty)
        service.setSuspended(false)
        #expect(registrar.active.count == HotkeyAction.allCases.count)
    }
}
