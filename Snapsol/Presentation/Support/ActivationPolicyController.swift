import AppKit

/// 普段は Dock に出ない（.accessory）が、ウィンドウを開いている間だけ通常アプリ（.regular）にする。
/// 複数ウィンドウが同時に開くので参照カウントで管理し、最後の 1 枚が閉じたら戻す。
@MainActor
final class ActivationPolicyController {
    private var openCount = 0

    func enter() {
        openCount += 1
        if openCount == 1 {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
    }

    func leave() {
        openCount = max(0, openCount - 1)
        if openCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
