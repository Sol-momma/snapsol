import Foundation

/// 撮影中に別の撮影要求が来たら無視する（nil = キャンセル扱い）。
/// 範囲選択中にホットキーを押し直すと screencapture が 2 つ走るのを、撮影・OCR の両方でまとめて防ぐ。
/// actor の再入性により、`await` 中に来た呼び出しは `isBusy == true` を見て即座に返る。
actor ExclusiveScreenCapturer: ScreenCapturing {
    private let base: any ScreenCapturing
    private var isBusy = false

    init(_ base: any ScreenCapturing) {
        self.base = base
    }

    func capture(_ mode: CaptureMode) async throws -> URL? {
        guard !isBusy else { return nil }
        isBusy = true
        defer { isBusy = false }
        return try await base.capture(mode)
    }
}
