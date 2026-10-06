import CoreGraphics
import Foundation
import Testing

private struct FakeCapturer: ScreenCapturing {
    let file: URL?
    func capture(_ mode: CaptureMode) async throws -> URL? { file }
}

private struct FakeRecognizer: TextRecognizing {
    let lines: [RecognizedLine]
    func recognizeText(at url: URL) async throws -> [RecognizedLine] { lines }
}

@MainActor
private final class SpyClipboard: ClipboardWriting {
    var text: String?
    func copyImage(at url: URL) throws {}
    func copyText(_ text: String) { self.text = text }
}

@MainActor
private final class SpyToast: ToastPresenting {
    var titles: [String] = []
    func show(_ title: String, detail: String?) { titles.append(title) }
}

@MainActor
struct TextCaptureFlowTests {
    private let clipboard = SpyClipboard()
    private let toast = SpyToast()

    private func flow(file: URL?, lines: [RecognizedLine] = []) -> TextCaptureFlow {
        TextCaptureFlow(capturer: FakeCapturer(file: file), recognizer: FakeRecognizer(lines: lines), clipboard: clipboard, toast: toast)
    }

    @Test func 認識した文字をコピーし一時画像を消す() async throws {
        let file = try makeFile(in: try makeTemporaryDirectory())
        let lines = [RecognizedLine(text: "こんにちは", bounds: CGRect(x: 0, y: 0, width: 0.5, height: 0.1))]

        try await flow(file: file, lines: lines).run()

        #expect(clipboard.text == "こんにちは")
        #expect(toast.titles == ["1 行のテキストをコピーしました"])
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func 文字がなければクリップボードを変えずに知らせる() async throws {
        let file = try makeFile(in: try makeTemporaryDirectory())

        try await flow(file: file).run()

        #expect(clipboard.text == nil)
        #expect(toast.titles == ["文字が見つかりませんでした"])
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func キャンセルしたら何もしない() async throws {
        try await flow(file: nil).run()
        #expect(clipboard.text == nil)
        #expect(toast.titles.isEmpty)
    }
}
