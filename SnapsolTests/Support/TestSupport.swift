import Foundation

/// テストごとに使い捨ての一時ディレクトリを作る
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "SnapsolTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// 中身を区別できるダミーファイルを作る
@discardableResult
func makeFile(in directory: URL, name: String = "\(UUID().uuidString).png", contents: String = "image") throws -> URL {
    let url = directory.appending(path: name)
    try Data(contents.utf8).write(to: url)
    return url
}

/// テスト専用の UserDefaults。破棄時に plist ごと消す（~/Library/Preferences に溜まらないように）
final class TemporaryDefaults {
    let suiteName = "SnapsolTests-\(UUID().uuidString)"
    let defaults: UserDefaults

    struct Unavailable: Error {}

    init() throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else { throw Unavailable() }
        self.defaults = defaults
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        // removePersistentDomain は値を消すだけで plist ファイルは残るので、同期してからファイルも消す
        CFPreferencesAppSynchronize(suiteName as CFString)
        let plist = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appending(path: "Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: plist)
    }
}

struct WaitTimedOut: Error {}

/// 条件が満たされるまで譲り続ける。実装が壊れてもテストが止まらないよう回数に上限を設ける
func waitUntil(_ condition: () async -> Bool) async throws {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
    throw WaitTimedOut()
}

func makeRepository(root: URL) -> FileHistoryRepository {
    FileHistoryRepository(
        historyDirectory: root.appending(path: "History", directoryHint: .isDirectory),
        indexFile: root.appending(path: "history.json"),
        discard: { try FileManager.default.removeItem(at: $0) }
    )
}
