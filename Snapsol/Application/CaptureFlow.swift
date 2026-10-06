import Foundation

/// 撮影 → 履歴取り込み → 撮影後アクション、の一連の流れ。
/// ホットキーとメニューの両方がここを呼ぶ。
@MainActor
final class CaptureFlow {
    private let capturer: any ScreenCapturing
    private let history: HistoryService
    private let onCaptured: (HistoryEntry) -> Void
    /// 範囲選択中にもう一度ホットキーを押すと screencapture が 2 つ走るのを防ぐ
    private(set) var isCapturing = false

    init(capturer: any ScreenCapturing, history: HistoryService, onCaptured: @escaping (HistoryEntry) -> Void) {
        self.capturer = capturer
        self.history = history
        self.onCaptured = onCaptured
    }

    func run(_ mode: CaptureMode) async throws {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        guard let url = try await capturer.capture(mode) else { return }
        let entry = try await history.add(movingFrom: url)
        onCaptured(entry)
    }
}
