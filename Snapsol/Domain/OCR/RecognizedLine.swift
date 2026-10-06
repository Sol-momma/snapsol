import CoreGraphics

/// OCR で認識した 1 行（断片）。
struct RecognizedLine: Equatable, Sendable {
    var text: String
    /// 画像に対する正規化座標（0...1）。**左上原点**に変換済み（Vision は左下原点なので注意）
    var bounds: CGRect
}
