import Foundation
import Observation

/// UI が参照する履歴の唯一の情報源。永続化は `HistoryRepository` に任せる。
@MainActor
@Observable
final class HistoryService {
    private(set) var entries: [HistoryEntry] = []
    @ObservationIgnored private let repository: any HistoryRepository

    init(repository: any HistoryRepository) {
        self.repository = repository
    }

    func reload() async throws {
        entries = try await repository.load()
    }

    func recent(_ count: Int = 5) -> [HistoryEntry] {
        Array(entries.prefix(count))
    }

    func entry(id: HistoryEntry.ID) -> HistoryEntry? {
        entries.first { $0.id == id }
    }

    func fileURL(for entry: HistoryEntry) -> URL {
        repository.fileURL(for: entry)
    }

    func add(movingFrom source: URL) async throws -> HistoryEntry {
        let entry = try await repository.add(movingFrom: source, createdAt: .now)
        entries.insert(entry, at: 0)
        return entry
    }

    func replaceImage(of entry: HistoryEntry, with data: Data) async throws -> HistoryEntry {
        let updated = try await repository.replaceImage(id: entry.id, with: data, updatedAt: .now)
        if let index = entries.firstIndex(where: { $0.id == updated.id }) {
            entries[index] = updated
        }
        return updated
    }

    func delete(_ entry: HistoryEntry) async throws {
        try await repository.delete(id: entry.id)
        entries.removeAll { $0.id == entry.id }
    }
}
