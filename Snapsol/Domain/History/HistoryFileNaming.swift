import Foundation

enum HistoryFileNaming {
    /// 撮影日時から人が読めるファイル名を作る。既存名と衝突したら " 2", " 3" … を付ける。
    /// ドラッグや「コピー」でファイルとして共有されたときにも、この名前が相手に見える。
    static func fileName(for date: Date, existing: Set<String>, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return uniqueName("Snapsol \(formatter.string(from: date)).png") { existing.contains($0) }
    }

    /// `fileName` が使用済みなら、拡張子の前に " 2", " 3" … を付けて空いている名前を返す
    static func uniqueName(_ fileName: String, isTaken: (String) -> Bool) -> String {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = fileName
        var counter = 2
        while isTaken(candidate) {
            candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            counter += 1
        }
        return candidate
    }
}
