import Foundation

protocol ScreenCapturing: Sendable {
    /// 撮影した一時 PNG の URL を返す。ユーザーが Esc でキャンセルした場合は nil。
    func capture(_ mode: CaptureMode) async throws -> URL?
}
