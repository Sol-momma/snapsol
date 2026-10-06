import Foundation

@MainActor
protocol ClipboardWriting {
    /// ファイル参照と画像データを同時に載せる（貼り付け先が理解できる形式を選べるように）
    func copyImage(at url: URL) throws
    func copyText(_ text: String)
}

@MainActor
protocol ToastPresenting {
    func show(_ title: String, detail: String?)
}
