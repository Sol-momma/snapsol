import AppKit

enum DisplayResolver {
    /// マウスカーソルがあるディスプレイを、`screencapture -D` が期待する 1 始まりの番号で返す。
    /// `CGGetActiveDisplayList` はメインディスプレイを先頭に返し、`-D` の番号順と一致する。
    @MainActor
    static func indexOfDisplayUnderCursor() -> Int {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return 1 }

        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return 1 }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success,
              let index = displays.firstIndex(of: number.uint32Value)
        else { return 1 }
        return index + 1
    }
}
