import AppKit

/// メニューバーのアイコンとメニュー。
/// メニューは開くたびに `menuNeedsUpdate` で組み直す（直近の撮影履歴を常に最新で出すため）。
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    override init() {
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Snapsol")
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "Snapsol を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }
}
