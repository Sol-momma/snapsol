import CoreGraphics
import CoreText
import Foundation

/// 注釈の描画。エディタの画面表示と、保存時のフル解像度書き出しが同じ実装を使う
protocol AnnotationRendering: Sendable {
    func loadImage(at url: URL) -> CGImage?
    /// モザイク用に元画像を粗くした画像。注釈を含まない元画像から 1 回だけ作る
    func mosaicSource(for image: CGImage) -> CGImage?
    /// `context` は画像ピクセル座標・左上原点（y 下向き）に変換済みであること
    func draw(_ annotations: [Annotation], in context: CGContext, imageSize: CGSize, mosaicSource: CGImage?)
    /// 元画像に注釈を焼き込んだ PNG。解像度（DPI）は元画像を引き継ぐ
    func renderPNG(baseImageAt url: URL, annotations: [Annotation]) throws -> Data
    func textSize(_ string: String, fontSize: CGFloat) -> CGSize
    /// テキスト注釈のフォント。エディタの入力欄も同じものを使い、確定前後で見た目がずれないようにする
    func textFont(ofSize size: CGFloat) -> CTFont
}
