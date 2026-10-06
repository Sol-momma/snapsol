import AppKit

/// メニューバーのアイコンとメニュー。
/// メニューは開くたびに `menuNeedsUpdate` で組み直す（直近の撮影履歴を常に最新で出すため）。
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    struct Actions {
        var capture: (CaptureMode) -> Void
        var selectRecent: (HistoryEntry) -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let history: HistoryService
    private let thumbnails: any ThumbnailProviding
    private let actions: Actions

    init(history: HistoryService, thumbnails: any ThumbnailProviding, actions: Actions) {
        self.history = history
        self.thumbnails = thumbnails
        self.actions = actions
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
        let recent = history.recent()
        if recent.isEmpty {
            let empty = NSMenuItem(title: "撮影履歴はまだありません", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            menu.addItem(.sectionHeader(title: "最近の撮影"))
            for entry in recent {
                menu.addItem(recentItem(for: entry))
            }
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Snapsol を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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

    @objc private func captureSelected(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? CaptureMode else { return }
        actions.capture(mode)
    }

    @objc private func recentSelected(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        actions.selectRecent(entry)
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
