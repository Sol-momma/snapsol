import AppKit
import os

/// 依存関係を組み立てる唯一の場所。
/// 各層の具体型（Infrastructure）をここで生成し、Application / Presentation に注入する。
@MainActor
final class AppContainer {
    private let logger = Logger(subsystem: "com.solmomma.snapsol", category: "App")
    private let capturer: any ScreenCapturing = ScreencaptureService(
        runner: ProcessRunner(),
        temporaryDirectory: FileManager.default.temporaryDirectory,
        displayIndex: { DisplayResolver.indexOfDisplayUnderCursor() }
    )
    private var statusItem: StatusItemController?

    init() {
        statusItem = StatusItemController { [weak self] mode in self?.capture(mode) }
    }

    // TODO(ステップ2): CaptureFlow（履歴への取り込み）に置き換える。今は撮影結果をプレビュー.appで開くだけ
    private func capture(_ mode: CaptureMode) {
        Task {
            do {
                guard let url = try await capturer.capture(mode) else { return }
                NSWorkspace.shared.open(url)
            } catch {
                logger.error("撮影に失敗: \(error)")
            }
        }
    }
}
