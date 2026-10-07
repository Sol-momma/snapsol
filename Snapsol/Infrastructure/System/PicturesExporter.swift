import Foundation

/// 履歴の画像を ~/Pictures/Snapsol へコピーする。同名があれば " 2", " 3" … を付ける
struct PicturesExporter: ImageExporting {
    let directory: URL

    func export(_ source: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = HistoryFileNaming.uniqueName(source.lastPathComponent) {
            FileManager.default.fileExists(atPath: directory.appending(path: $0).path)
        }
        let destination = directory.appending(path: name)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}
