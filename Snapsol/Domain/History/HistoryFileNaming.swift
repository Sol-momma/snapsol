import Foundation

enum HistoryFileNaming {
    /// 撮影日時から人が読めるファイル名を作る。既存名と衝突したら " 2", " 3" … を付ける。
    /// ドラッグや「コピー」でファイルとして共有されたときにも、この名前が相手に見える。
    static func fileName(for date: Date, existing: Set<String>, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let base = "Snapsol \(formatter.string(from: date))"

        var candidate = "\(base).png"
        var counter = 2
        while existing.contains(candidate) {
            candidate = "\(base) \(counter).png"
            counter += 1
        }
        return candidate
    }
}
