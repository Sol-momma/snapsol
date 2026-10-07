import Carbon.HIToolbox
import Foundation
import Testing

@MainActor
struct HotkeyInfrastructureTests {
    @Test func 修飾キーをCarbonのフラグに変換する() {
        let modifiers: HotkeyShortcut.Modifiers = [.command, .shift]
        #expect(modifiers.carbonFlags == UInt32(cmdKey | shiftKey))
    }

    @Test func デフォルトキーはANSIの1から4() {
        #expect(HotkeyAction.allCases.map(\.defaultShortcut.keyCode) == [
            UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3), UInt16(kVK_ANSI_4),
        ])
    }

    @Test func ストアはデフォルトと異なるキーだけを保存して読み戻す() throws {
        let temporary = try TemporaryDefaults()
        let store = UserDefaultsHotkeyStore(defaults: temporary.defaults)
        let custom = HotkeyShortcut(keyCode: 23, modifiers: [.command, .shift])

        try store.save([.captureArea: custom, .captureWindow: HotkeyAction.captureWindow.defaultShortcut])

        #expect(store.load() == [.captureArea: custom])
    }
}
