import Foundation
import Testing

/// release() されるまで撮影を終えない（ユーザーが範囲選択中の状態を再現する）
private actor GatedCapturer: ScreenCapturing {
    private(set) var calls = 0
    private var waiting: CheckedContinuation<Void, Never>?

    func capture(_ mode: CaptureMode) async throws -> URL? {
        calls += 1
        await withCheckedContinuation { waiting = $0 }
        return URL(filePath: "/tmp/captured.png")
    }

    func release() {
        waiting?.resume()
        waiting = nil
    }
}

struct ExclusiveScreenCapturerTests {
    @Test func 撮影中の追加要求はnilを返し基になる撮影を起動しない() async throws {
        let gated = GatedCapturer()
        let exclusive = ExclusiveScreenCapturer(gated)

        let first = Task { try await exclusive.capture(.area) }
        try await waitUntil { await gated.calls == 1 }

        #expect(try await exclusive.capture(.window) == nil)
        #expect(await gated.calls == 1)

        await gated.release()
        #expect(try await first.value != nil)
    }

    @Test func 撮影が終われば次の撮影を受け付ける() async throws {
        let gated = GatedCapturer()
        let exclusive = ExclusiveScreenCapturer(gated)

        let first = Task { try await exclusive.capture(.area) }
        try await waitUntil { await gated.calls == 1 }
        await gated.release()
        _ = try await first.value

        let second = Task { try await exclusive.capture(.area) }
        try await waitUntil { await gated.calls == 2 }
        await gated.release()
        #expect(try await second.value != nil)
    }
}
