import CoreGraphics
import Foundation

protocol HistoryRepository: Sendable {
    /// 新しい順で返す。実ファイルが消えている項目は取り除く
    func load() async throws -> [HistoryEntry]
    /// `source` のファイルを履歴ディレクトリへ移動して登録する
    func add(movingFrom source: URL, createdAt: Date) async throws -> HistoryEntry
    /// 画像を原子的に置き換え、`updatedAt` を更新する（注釈の焼き込み保存）
    func replaceImage(id: UUID, with data: Data, updatedAt: Date) async throws -> HistoryEntry
    func delete(id: UUID) async throws
    nonisolated func fileURL(for entry: HistoryEntry) -> URL
}

protocol ThumbnailProviding: Sendable {
    /// `version` が変わるとキャッシュを使わず読み直す
    func thumbnail(at url: URL, version: Date, maxPixelSize: Int) -> CGImage?
}
