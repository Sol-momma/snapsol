import Carbon.HIToolbox

struct CarbonHotkeyError: Error {
    let status: OSStatus
}

/// Carbon の `RegisterEventHotKey` でグローバルホットキーを登録する。
/// `NSEvent.addGlobalMonitorForEvents` と違いアクセシビリティ権限が不要で、
/// キー入力を「奪う」（前面アプリに ⌥1 が届かない）ことができる。
@MainActor
final class CarbonHotkeyRegistrar: HotkeyRegistering {
    var onPressed: ((HotkeyRegistration) -> Void)?

    private static let signature = OSType(0x534E_504C) // 'SNPL'
    private var refs: [UInt32: EventHotKeyRef] = [:]
    /// 登録ごとに一意な ID を振る。キー変更中に新旧が一時的に共存しても押下を取り違えない
    private var nextID: UInt32 = 1

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // C 関数ポインタなので外部をキャプチャできない。self は userData 経由で渡す
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { registrar.onPressed?(HotkeyRegistration(id: hotKeyID.id)) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    func register(_ shortcut: HotkeyShortcut) throws -> HotkeyRegistration {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode), shortcut.modifiers.carbonFlags,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { throw CarbonHotkeyError(status: status) }
        refs[id] = ref
        return HotkeyRegistration(id: id)
    }

    func unregister(_ registration: HotkeyRegistration) {
        guard let ref = refs.removeValue(forKey: registration.id) else { return }
        UnregisterEventHotKey(ref)
    }
}

extension HotkeyShortcut.Modifiers {
    var carbonFlags: UInt32 {
        var flags = 0
        if contains(.command) { flags |= cmdKey }
        if contains(.option) { flags |= optionKey }
        if contains(.control) { flags |= controlKey }
        if contains(.shift) { flags |= shiftKey }
        return UInt32(flags)
    }
}
