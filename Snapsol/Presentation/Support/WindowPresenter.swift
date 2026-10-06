import AppKit
import SwiftUI

/// SwiftUI の View を自前の NSWindow で開く。同じ id のウィンドウは 1 枚だけで、2 回目は前面に出すだけ。
/// SwiftUI の `Window` シーンは常駐（accessory）アプリから開きにくいので AppKit で管理する。
@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {
    private struct Managed {
        let window: NSWindow
        let shouldClose: (() -> Bool)?
        let onClose: (() -> Void)?
    }

    private let activation: ActivationPolicyController
    private var windows: [String: Managed] = [:]

    init(activation: ActivationPolicyController) {
        self.activation = activation
    }

    /// - Parameters:
    ///   - shouldClose: false を返すと閉じない（未保存の確認など）
    ///   - onClose: 閉じた後に呼ばれる
    func show(
        id: String,
        title: String,
        size: NSSize,
        shouldClose: (() -> Bool)? = nil,
        onClose: (() -> Void)? = nil,
        content: () -> some View
    ) {
        if let existing = windows[id] {
            existing.window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let hosting = NSHostingController(rootView: content())
        hosting.sizingOptions = []
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = hosting
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        windows[id] = Managed(window: window, shouldClose: shouldClose, onClose: onClose)
        activation.enter()
        window.makeKeyAndOrderFront(nil)
    }

    func close(id: String) {
        windows[id]?.window.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        windows.values.first { $0.window === sender }?.shouldClose?() ?? true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = windows.first(where: { $0.value.window === window })?.key,
              let managed = windows.removeValue(forKey: id)
        else { return }
        activation.leave()
        managed.onClose?()
    }
}
