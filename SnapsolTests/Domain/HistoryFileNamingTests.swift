import Foundation
import Testing

struct HistoryFileNamingTests {
    private let date = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21 14:13:20 UTC
    private let utc = TimeZone(identifier: "UTC")!

    @Test func 日時から読めるファイル名を作る() {
        #expect(HistoryFileNaming.fileName(for: date, existing: [], timeZone: utc) == "Snapsol 2026-09-21 14.13.20.png")
    }

    @Test func 衝突したら連番を付ける() {
        let existing: Set = ["Snapsol 2026-09-21 14.13.20.png", "Snapsol 2026-09-21 14.13.20 2.png"]
        #expect(HistoryFileNaming.fileName(for: date, existing: existing, timeZone: utc) == "Snapsol 2026-09-21 14.13.20 3.png")
    }
}
