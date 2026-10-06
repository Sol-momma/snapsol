import Foundation

/// 範囲選択 → OCR → クリップボード → トースト。画像は履歴に入れず、一時ファイルも必ず消す。
@MainActor
final class TextCaptureFlow {
    private let capturer: any ScreenCapturing
    private let recognizer: any TextRecognizing
    private let clipboard: any ClipboardWriting
    private let toast: any ToastPresenting

    init(capturer: any ScreenCapturing, recognizer: any TextRecognizing, clipboard: any ClipboardWriting, toast: any ToastPresenting) {
        self.capturer = capturer
        self.recognizer = recognizer
        self.clipboard = clipboard
        self.toast = toast
    }

    func run() async throws {
        guard let url = try await capturer.capture(.area) else { return }
        defer { try? FileManager.default.removeItem(at: url) }

        let text = ReadingOrderSorter.sort(try await recognizer.recognizeText(at: url))
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            toast.show("文字が見つかりませんでした", detail: nil)
            return
        }
        clipboard.copyText(text)
        let lines = text.split(separator: "\n")
        toast.show("\(lines.count) 行のテキストをコピーしました", detail: lines.first.map(String.init))
    }
}
