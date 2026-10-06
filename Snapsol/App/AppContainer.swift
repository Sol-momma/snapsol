/// 依存関係を組み立てる唯一の場所。
/// 各層の具体型（Infrastructure）をここで生成し、Application / Presentation に注入する。
@MainActor
final class AppContainer {
    private let statusItem = StatusItemController()
}
