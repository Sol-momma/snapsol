import Foundation

struct AppPaths: Sendable {
    let historyDirectory: URL
    let historyIndexFile: URL
    /// 「保存」で書き出す先
    let exportDirectory: URL

    static func standard() -> AppPaths {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Snapsol", directoryHint: .isDirectory)
        let pictures = fileManager.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        return AppPaths(
            historyDirectory: support.appending(path: "History", directoryHint: .isDirectory),
            historyIndexFile: support.appending(path: "history.json"),
            exportDirectory: pictures.appending(path: "Snapsol", directoryHint: .isDirectory)
        )
    }
}
