import Foundation
import Testing

struct FileHistoryRepositoryTests {
    private let root: URL
    private let repository: FileHistoryRepository

    init() throws {
        root = try makeTemporaryDirectory()
        repository = makeRepository(root: root)
    }

    @Test func 追加するとファイルが履歴ディレクトリへ移動する() async throws {
        let source = try makeFile(in: root)
        let entry = try await repository.add(movingFrom: source, createdAt: .now)

        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: repository.fileURL(for: entry).path))
    }

    @Test func 別インスタンスから新しい順で読み直せる() async throws {
        let older = try await repository.add(movingFrom: try makeFile(in: root), createdAt: Date(timeIntervalSince1970: 100))
        let newer = try await repository.add(movingFrom: try makeFile(in: root), createdAt: Date(timeIntervalSince1970: 200))

        let reloaded = try await makeRepository(root: root).load()
        #expect(reloaded.map(\.id) == [newer.id, older.id])
    }

    @Test func indexにはファイル名だけを保存し絶対パスを含まない() async throws {
        _ = try await repository.add(movingFrom: try makeFile(in: root), createdAt: .now)
        let json = try String(contentsOf: root.appending(path: "history.json"), encoding: .utf8)
        #expect(!json.contains(root.path))
    }

    @Test func 実ファイルが消えた項目は読み込み時に取り除く() async throws {
        let kept = try await repository.add(movingFrom: try makeFile(in: root), createdAt: .now)
        let lost = try await repository.add(movingFrom: try makeFile(in: root), createdAt: .now)
        try FileManager.default.removeItem(at: repository.fileURL(for: lost))

        let reloaded = try await makeRepository(root: root).load()
        #expect(reloaded.map(\.id) == [kept.id])
    }

    @Test func 画像を置き換えるとupdatedAtが更新される() async throws {
        let entry = try await repository.add(movingFrom: try makeFile(in: root, contents: "before"), createdAt: Date(timeIntervalSince1970: 100))
        let updated = try await repository.replaceImage(id: entry.id, with: Data("after".utf8), updatedAt: Date(timeIntervalSince1970: 200))

        #expect(updated.updatedAt == Date(timeIntervalSince1970: 200))
        #expect(updated.fileName == entry.fileName)
        #expect(try String(contentsOf: repository.fileURL(for: updated), encoding: .utf8) == "after")
    }

    @Test func 削除するとファイルと項目の両方が消える() async throws {
        let entry = try await repository.add(movingFrom: try makeFile(in: root), createdAt: .now)
        try await repository.delete(id: entry.id)

        #expect(!FileManager.default.fileExists(atPath: repository.fileURL(for: entry).path))
        #expect(try await makeRepository(root: root).load().isEmpty)
    }
}
