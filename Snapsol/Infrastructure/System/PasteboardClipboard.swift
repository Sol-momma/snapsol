import AppKit
import UniformTypeIdentifiers

@MainActor
struct PasteboardClipboard: ClipboardWriting {
    var pasteboard: NSPasteboard = .general

    func copyImage(at url: URL) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        // 1 つの item に複数の形式を載せる。
        // - fileURL: ターミナルやエディタ、Slack など「ファイルを貼る」アプリが読む
        // - PNG / TIFF: メールやメモなど、画像データを直接読むアプリが読む
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        item.setData(data, forType: .png)
        if let tiff = NSBitmapImageRep(data: data)?.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    func copyText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
