import AppKit

extension NSScreen {
    /// マウスカーソルがあるディスプレイ（通知やカードはユーザーが見ている画面に出す）
    @MainActor
    static var underCursor: NSScreen? {
        screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? main
    }
}
