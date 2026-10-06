import CoreGraphics

/// Vision の認識結果は返却順が読み順を保証しない。上から下へ「視覚的な行」にまとめ、
/// 行内を左から右へ並べて 1 つの文字列にする。
enum ReadingOrderSorter {
    static func sort(_ lines: [RecognizedLine]) -> String {
        // 許容誤差付きの比較関数は strict weak ordering にならず sorted(by:) の結果が未定義になる。
        // そのため「上から順に並べる → 行にまとめる」の 2 段階で処理する
        let topDown = lines.sorted { $0.bounds.midY < $1.bounds.midY }

        var rows: [[RecognizedLine]] = []
        for line in topDown {
            // 中心の高さの差が、行の高さの半分以内なら同じ行とみなす
            if let anchor = rows.last?.first, abs(line.bounds.midY - anchor.bounds.midY) <= anchor.bounds.height / 2 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }

        return rows
            .map { joinRow($0.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text)) }
            .joined(separator: "\n")
    }

    /// 同じ行の断片をつなぐ。日本語どうしは空白なし、それ以外（英単語の間など）は空白 1 つ
    private static func joinRow(_ fragments: [String]) -> String {
        fragments.dropFirst().reduce(into: fragments.first ?? "") { result, next in
            if let last = result.last, let first = next.first, isCJK(last), isCJK(first) {
                result += next
            } else {
                result += " " + next
            }
        }
    }

    private static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first?.value else { return false }
        return (0x3000...0x30FF).contains(scalar)    // 句読点・ひらがな・カタカナ
            || (0x3400...0x4DBF).contains(scalar)    // CJK 統合漢字拡張 A
            || (0x4E00...0x9FFF).contains(scalar)    // CJK 統合漢字
            || (0xFF00...0xFFEF).contains(scalar)    // 全角英数・半角カナ
    }
}
