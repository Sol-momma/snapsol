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

func makeRepository(root: URL) -> FileHistoryRepository {
    FileHistoryRepository(
        historyDirectory: root.appending(path: "History", directoryHint: .isDirectory),
        indexFile: root.appending(path: "history.json"),
        discard: { try FileManager.default.removeItem(at: $0) }
    )
}
