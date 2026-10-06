import AppKit

/// メニューバーのアイコンとメニュー。
/// メニューは開くたびに `menuNeedsUpdate` で組み直す（直近の撮影履歴とホットキーを常に最新で出すため）。
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    struct Actions {
        var perform: (HotkeyAction) -> Void
        var selectRecent: (HistoryEntry) -> Void
        var showHistory: () -> Void
        var showSettings: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let history: HistoryService
    private let hotkeys: HotkeyBindingService
    private let thumbnails: any ThumbnailProviding
    private let actions: Actions

    init(history: HistoryService, hotkeys: HotkeyBindingService, thumbnails: any ThumbnailProviding, actions: Actions) {
        self.history = history
        self.hotkeys = hotkeys
        self.thumbnails = thumbnails
        self.actions = actions
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Snapsol")
        menu.delegate = self
        statusItem.menu = menu
    }

    /// NSMenuItem.target は weak なので、クロージャ用の target はここで保持する
    private var closureTargets: [ClosureMenuTarget] = []

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        closureTargets.removeAll()
        for action in HotkeyAction.allCases {
            let item = NSMenuItem(title: action.menuTitle, action: #selector(actionSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action
            if let shortcut = hotkeys.bindings[action], let character = KeyLabel.menuKeyEquivalent(for: shortcut.keyCode) {
                // 表示用。実際のキー入力は Carbon のグローバルホットキーが受ける
                item.keyEquivalent = character
                item.keyEquivalentModifierMask = NSEvent.ModifierFlags(shortcut.modifiers)
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let recent = history.recent()
        if recent.isEmpty {
            let empty = NSMenuItem(title: "撮影履歴はまだありません", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            menu.addItem(.sectionHeader(title: "最近の撮影（クリックでコピー）"))
            for entry in recent {
                menu.addItem(recentItem(for: entry))
            }
        }
        menu.addItem(closureItem("履歴を表示…", actions.showHistory))

        menu.addItem(.separator())
        menu.addItem(closureItem("設定…", actions.showSettings))
        menu.addItem(withTitle: "Snapsol を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func closureItem(_ title: String, _ handler: @escaping () -> Void) -> NSMenuItem {
        let target = ClosureMenuTarget(handler)
        closureTargets.append(target)
        let item = NSMenuItem(title: title, action: #selector(ClosureMenuTarget.perform(_:)), keyEquivalent: "")
        item.target = target
        return item
    }

    private func recentItem(for entry: HistoryEntry) -> NSMenuItem {
        let item = NSMenuItem(
            title: entry.createdAt.formatted(date: .abbreviated, time: .shortened),
            action: #selector(recentSelected(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = entry
        let url = history.fileURL(for: entry)
        if let image = thumbnails.thumbnail(at: url, version: entry.updatedAt, maxPixelSize: 96) {
            let thumbnail = NSImage(cgImage: image, size: .zero)
            let scale = 32 / max(thumbnail.size.width, thumbnail.size.height)
            thumbnail.size = NSSize(width: thumbnail.size.width * scale, height: thumbnail.size.height * scale)
            item.image = thumbnail
        }
        return item
    }

    @objc private func actionSelected(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? HotkeyAction else { return }
        actions.perform(action)
    }

    @objc private func recentSelected(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        actions.selectRecent(entry)
    }
}

extension HotkeyAction {
    var menuTitle: String {
        switch self {
        case .captureFullscreen: "全画面を撮影"
        case .captureWindow: "ウィンドウを撮影"
        case .captureArea: "範囲を撮影"
        case .captureText: "範囲の文字をコピー"
        }
    }
}
