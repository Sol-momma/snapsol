import Foundation

/// 撮影 → 履歴取り込み → 撮影後アクション、の一連の流れ。
/// ホットキーとメニューの両方がここを呼ぶ。
@MainActor
final class CaptureFlow {
    private let capturer: any ScreenCapturing
    private let history: HistoryService
    private let settings: AppSettings
    private let clipboard: any ClipboardWriting
    private weak var presenter: (any CaptureResultPresenting)?

    init(
        capturer: any ScreenCapturing,
        history: HistoryService,
        settings: AppSettings,
        clipboard: any ClipboardWriting,
        presenter: any CaptureResultPresenting
    ) {
        self.capturer = capturer
        self.history = history
        self.settings = settings
        self.clipboard = clipboard
        self.presenter = presenter
    }

    func run(_ mode: CaptureMode) async throws {
        guard let url = try await capturer.capture(mode) else { return }
        let entry = try await history.add(movingFrom: url)

        let actions = settings.afterCapture
        if actions.contains(.copyToClipboard) {
            try clipboard.copyImage(at: history.fileURL(for: entry))
        }
        if actions.contains(.showCard) {
            presenter?.showCard(for: entry)
        }
        if actions.contains(.openEditor) {
            presenter?.openEditor(for: entry)
        }
    }
}
