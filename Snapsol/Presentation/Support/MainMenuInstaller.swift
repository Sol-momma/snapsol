import AppKit

/// メインメニューを自前で作る。
/// storyboard を持たない常駐アプリには Edit メニューが無く、ウィンドウ表示中でも
/// ⌘C / ⌘V / ⌘Z / ⌘W がテキスト欄やエディタに届かないため。
/// 標準項目は target を nil にしてレスポンダチェーンに流す（その時のフォーカスが処理する）。
@MainActor
enum MainMenuInstaller {
    private static var settingsTarget: ClosureMenuTarget?

    static func install(openSettings: @escaping () -> Void) {
        let main = NSMenu()

        let appMenu = NSMenu()
        let target = ClosureMenuTarget(openSettings)
        settingsTarget = target
        let settings = NSMenuItem(title: "設定…", action: #selector(ClosureMenuTarget.perform(_:)), keyEquivalent: ",")
        settings.target = target
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Snapsol を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenuItem(appMenu))

        let edit = NSMenu(title: "編集")
        edit.addItem(withTitle: "取り消す", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "やり直す", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "カット", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "コピー", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "ペースト", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "すべてを選択", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenuItem(edit))

        let window = NSMenu(title: "ウインドウ")
        window.addItem(withTitle: "閉じる", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "しまう", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(submenuItem(window))

        NSApp.mainMenu = main
    }

    private static func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}

/// NSMenuItem の target/action をクロージャで書くための小さなアダプタ
@MainActor
final class ClosureMenuTarget: NSObject {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func perform(_ sender: Any?) {
        handler()
    }
}
