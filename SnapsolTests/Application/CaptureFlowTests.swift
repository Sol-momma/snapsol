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
struct CaptureFlowTests {
    private let root: URL
    private let history: HistoryService

    init() throws {
        root = try makeTemporaryDirectory()
        history = HistoryService(repository: makeRepository(root: root))
    }

    @Test func 撮影すると履歴に追加され撮影後処理が呼ばれる() async throws {
        var captured: [HistoryEntry] = []
        let flow = CaptureFlow(capturer: FakeCapturer(directory: root), history: history) { captured.append($0) }

        try await flow.run(.area)

        #expect(history.entries.count == 1)
        #expect(captured == history.entries)
    }

    @Test func キャンセルしたら何も起きない() async throws {
        var called = false
        let flow = CaptureFlow(capturer: FakeCapturer(directory: root, cancels: true), history: history) { _ in called = true }

        try await flow.run(.area)

        #expect(history.entries.isEmpty)
        #expect(!called)
    }
}
