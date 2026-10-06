import CoreGraphics
import Testing

struct ReadingOrderSorterTests {
    private func line(_ text: String, x: CGFloat, y: CGFloat, height: CGFloat = 0.04) -> RecognizedLine {
        RecognizedLine(text: text, bounds: CGRect(x: x, y: y, width: 0.2, height: height))
    }

    @Test func 上から下へ並べる() {
        let lines = [line("2行目", x: 0.1, y: 0.5), line("1行目", x: 0.1, y: 0.1)]
        #expect(ReadingOrderSorter.sort(lines) == "1行目\n2行目")
    }

    @Test func 同じ高さの断片は左から右へ1行にまとめる() {
        let lines = [line("World", x: 0.6, y: 0.11), line("Hello", x: 0.1, y: 0.1)]
        #expect(ReadingOrderSorter.sort(lines) == "Hello World")
    }

    @Test func 日本語どうしは空白を入れずにつなぐ() {
        let lines = [line("テスト", x: 0.6, y: 0.1), line("読み順の", x: 0.1, y: 0.1)]
        #expect(ReadingOrderSorter.sort(lines) == "読み順のテスト")
    }

    @Test func 行の高さの半分を超えてずれたら別の行にする() {
        let lines = [line("下", x: 0.1, y: 0.13), line("上", x: 0.5, y: 0.1)]
        #expect(ReadingOrderSorter.sort(lines) == "上\n下")
    }

    @Test func 空なら空文字() {
        #expect(ReadingOrderSorter.sort([]) == "")
    }
}
