/// 撮影結果を UI に出すためのポート。Application は AppKit を知らずに「カードを出す」「エディタを開く」を頼める
@MainActor
protocol CaptureResultPresenting: AnyObject {
    func showCard(for entry: HistoryEntry)
    func openEditor(for entry: HistoryEntry)
}
