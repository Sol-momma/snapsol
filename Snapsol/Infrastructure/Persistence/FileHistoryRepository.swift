import Foundation

/// `history.json`（メタデータ）＋ 画像ファイル実体（History/ 配下）で履歴を永続化する。
/// actor にして、撮影と編集保存が同時に走っても index の読み書きが競合しないようにする。
actor FileHistoryRepository: HistoryRepository {
    private struct IndexFile: Codable {
        var version = 1
        var entries: [HistoryEntry]
    }

    private let historyDirectory: URL
    private let indexFile: URL
    private let discard: @Sendable (URL) throws -> Void
    private var cache: [HistoryEntry]?

    /// - Parameter discard: 削除時のファイル処理。本番はゴミ箱へ移動、テストでは完全削除を渡す
    init(
        historyDirectory: URL,
        indexFile: URL,
        discard: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) {
        self.historyDirectory = historyDirectory
        self.indexFile = indexFile
        self.discard = discard
    }

    nonisolated func fileURL(for entry: HistoryEntry) -> URL {
        historyDirectory.appending(path: entry.fileName)
    }

    func load() throws -> [HistoryEntry] {
        let stored = try readIndex()
        let existing = stored
            .filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
            .sorted { $0.createdAt > $1.createdAt }
        if existing.count != stored.count {
            try writeIndex(existing)
        }
        cache = existing
        return existing
    }

    func add(movingFrom source: URL, createdAt: Date) throws -> HistoryEntry {
        var entries = try currentEntries()
        try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)

        let existingNames = Set((try? FileManager.default.contentsOfDirectory(atPath: historyDirectory.path)) ?? [])
        let entry = HistoryEntry(
            id: UUID(),
            fileName: HistoryFileNaming.fileName(for: createdAt, existing: existingNames),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        try FileManager.default.moveItem(at: source, to: fileURL(for: entry))

        entries.insert(entry, at: 0)
        try writeIndex(entries)
        return entry
    }

    func replaceImage(id: UUID, with data: Data, updatedAt: Date) throws -> HistoryEntry {
        var entries = try currentEntries()
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        // 同じディレクトリに書いてから置換する。途中で落ちても元画像が壊れない
        let destination = fileURL(for: entries[index])
        let staging = historyDirectory.appending(path: ".\(UUID().uuidString).png")
        try data.write(to: staging)
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)

        entries[index].updatedAt = updatedAt
        try writeIndex(entries)
        return entries[index]
    }

    func delete(id: UUID) throws {
        var entries = try currentEntries()
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let url = fileURL(for: entries[index])
        // ファイルを先に処理し、成功してから index から消す（失敗時に履歴だけ消えるのを防ぐ）
        if FileManager.default.fileExists(atPath: url.path) {
            try discard(url)
        }
        entries.remove(at: index)
        try writeIndex(entries)
    }

    private func currentEntries() throws -> [HistoryEntry] {
        if let cache { return cache }
        return try load()
    }

    private func readIndex() throws -> [HistoryEntry] {
        guard FileManager.default.fileExists(atPath: indexFile.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(IndexFile.self, from: Data(contentsOf: indexFile)).entries
    }

    private func writeIndex(_ entries: [HistoryEntry]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: indexFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(IndexFile(entries: entries)).write(to: indexFile, options: .atomic)
        cache = entries
    }
}
