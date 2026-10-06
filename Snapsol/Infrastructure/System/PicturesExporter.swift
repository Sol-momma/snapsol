import Foundation

/// 履歴の画像を ~/Pictures/Snapsol へコピーする。同名があれば " 2", " 3" … を付ける
struct PicturesExporter: ImageExporting {
    let directory: URL

    func export(_ source: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = uniqueURL(for: source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    private func uniqueURL(for fileName: String) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = directory.appending(path: fileName)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appending(path: "\(base) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
