import AppKit

/// メニューバーのアイコンとメニュー。
/// メニューは開くたびに `menuNeedsUpdate` で組み直す（直近の撮影履歴を常に最新で出すため）。
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let onCapture: (CaptureMode) -> Void

    init(onCapture: @escaping (CaptureMode) -> Void) {
        self.onCapture = onCapture
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Snapsol")
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for mode in CaptureMode.allCases {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(captureSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Snapsol を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func captureSelected(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? CaptureMode else { return }
        onCapture(mode)
    }
}

private extension CaptureMode {
    var menuTitle: String {
        switch self {
        case .fullscreen: "全画面を撮影"
        case .window: "ウィンドウを撮影"
        case .area: "範囲を撮影"
        }
    }
}
