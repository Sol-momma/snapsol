import Foundation
import Testing

struct PicturesExporterTests {
    @Test func 書き出し先にコピーし元ファイルは残す() throws {
        let root = try makeTemporaryDirectory()
        let source = try makeFile(in: root, name: "shot.png")
        let exporter = PicturesExporter(directory: root.appending(path: "Export"))

        let exported = try exporter.export(source)

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(exported.lastPathComponent == "shot.png")
    }

    @Test func 同名があれば連番を付ける() throws {
        let root = try makeTemporaryDirectory()
        let source = try makeFile(in: root, name: "shot.png")
        let exporter = PicturesExporter(directory: root.appending(path: "Export"))

        _ = try exporter.export(source)
        let second = try exporter.export(source)

        #expect(second.lastPathComponent == "shot 2.png")
    }
}
