import AppKit

/// SwiftUI の `App` を使わず AppKit で起動する。
/// メニューバー常駐（LSUIElement）で、設定やエディタは自前の NSWindow で出すため。
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        container = AppContainer()
    }
}
