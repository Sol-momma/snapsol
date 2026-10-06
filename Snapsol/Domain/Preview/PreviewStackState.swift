import Foundation

/// 撮影後カードの積み重ねと自動クローズの状態機械。
/// 現在時刻を引数で受け取る純粋な値型なので、タイマーを待たずにテストできる。
struct PreviewStackState: Equatable {
    struct Card: Equatable, Identifiable {
        let id: UUID
        /// nil なら自動では閉じない
        var expiresAt: Date?
    }

    /// ホバーをやめてから最低これだけは残す（読みかけ・押しかけのカードが消えないように）
    static let hoverGrace: TimeInterval = 2

    /// 新しい順
    private(set) var cards: [Card] = []
    private(set) var isHovering = false
    let maxCards: Int

    init(maxCards: Int = 5) {
        self.maxCards = maxCards
    }

    /// 先頭に積む。上限を超えて押し出されたカードの ID を返す
    @discardableResult
    mutating func push(_ id: UUID, now: Date, lifetime: TimeInterval?) -> [UUID] {
        cards.removeAll { $0.id == id }
        cards.insert(Card(id: id, expiresAt: lifetime.map { now.addingTimeInterval($0) }), at: 0)
        guard cards.count > maxCards else { return [] }
        let overflow = cards[maxCards...].map(\.id)
        cards.removeLast(cards.count - maxCards)
        return overflow
    }

    mutating func remove(_ id: UUID) {
        cards.removeAll { $0.id == id }
    }

    /// ホバー中はどのカードも閉じない。ホバーをやめたら、期限が近いカードを猶予分だけ延ばす
    mutating func setHovering(_ hovering: Bool, now: Date) {
        if isHovering, !hovering {
            let earliest = now.addingTimeInterval(Self.hoverGrace)
            for index in cards.indices {
                if let expiresAt = cards[index].expiresAt, expiresAt < earliest {
                    cards[index].expiresAt = earliest
                }
            }
        }
        isHovering = hovering
    }

    /// 期限切れのカードを取り除き、その ID を返す
    mutating func removeExpired(now: Date) -> [UUID] {
        guard !isHovering else { return [] }
        let expired = cards.filter { $0.expiresAt.map { $0 <= now } ?? false }.map(\.id)
        cards.removeAll { expired.contains($0.id) }
        return expired
    }

    /// 次に期限が来る時刻。タイマーはこの時刻に 1 回だけ起きればよい
    var nextDeadline: Date? {
        isHovering ? nil : cards.compactMap(\.expiresAt).min()
    }
}
