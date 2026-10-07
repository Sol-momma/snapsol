import Foundation
import Testing

/// 撮影結果を差し替える。nil を返すとユーザーがキャンセルしたことになる
private struct FakeCapturer: ScreenCapturing {
    let directory: URL
    var cancels = false

    func capture(_ mode: CaptureMode) async throws -> URL? {
        cancels ? nil : try makeFile(in: directory)
    }
}

@MainActor
private final class SpyPresenter: CaptureResultPresenting {
    var cards: [HistoryEntry] = []
    var editors: [HistoryEntry] = []
    func showCard(for entry: HistoryEntry) { cards.append(entry) }
    func openEditor(for entry: HistoryEntry) { editors.append(entry) }
}

@MainActor
private final class SpyClipboard: ClipboardWriting {
    struct Failed: Error {}
    var images: [URL] = []
    var fails = false

    func copyImage(at url: URL) throws {
        if fails { throw Failed() }
        images.append(url)
    }

    func copyText(_ text: String) {}
}

@MainActor
final class CaptureFlowTests {
    private let root: URL
    private let history: HistoryService
    private let defaults: TemporaryDefaults
    private let settings: AppSettings
    private let presenter = SpyPresenter()
    private let clipboard = SpyClipboard()

    init() throws {
        root = try makeTemporaryDirectory()
        history = HistoryService(repository: makeRepository(root: root))
        defaults = try TemporaryDefaults()
        settings = AppSettings(defaults: defaults.defaults)
    }

    private func flow(cancels: Bool = false) -> CaptureFlow {
        CaptureFlow(
            capturer: FakeCapturer(directory: root, cancels: cancels),
            history: history,
            settings: settings,
            clipboard: clipboard,
            presenter: presenter
        )
    }

    @Test func 既定では履歴に追加してカードだけを出す() async throws {
        try await flow().run(.area)

        #expect(history.entries.count == 1)
        #expect(presenter.cards == history.entries)
        #expect(presenter.editors.isEmpty)
        #expect(clipboard.images.isEmpty)
    }

    @Test func 設定に応じてコピーとエディタも行う() async throws {
        settings.afterCapture = [.copyToClipboard, .openEditor]

        try await flow().run(.area)

        let entry = try #require(history.entries.first)
        #expect(clipboard.images == [history.fileURL(for: entry)])
        #expect(presenter.editors == [entry])
        #expect(presenter.cards.isEmpty)
    }

    @Test func コピーに失敗してもカードは出る() async throws {
        settings.afterCapture = [.showCard, .copyToClipboard]
        clipboard.fails = true

        await #expect(throws: SpyClipboard.Failed.self) { try await self.flow().run(.area) }
        #expect(presenter.cards.count == 1)
    }

    @Test func キャンセルしたら何も起きない() async throws {
        try await flow(cancels: true).run(.area)

        #expect(history.entries.isEmpty)
        #expect(presenter.cards.isEmpty)
    }
}
