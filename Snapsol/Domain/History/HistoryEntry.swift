import Foundation

/// 撮影履歴の 1 件。保存するのはファイル名だけで、絶対パスは持たない
/// （保存先ディレクトリが変わっても履歴が壊れないように）。
struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var fileName: String
    var createdAt: Date
    /// 注釈の焼き込みで画像が置き換わると更新される。サムネイルキャッシュのキーにも使う
    var updatedAt: Date
}
