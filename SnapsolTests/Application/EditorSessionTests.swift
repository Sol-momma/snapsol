import CoreGraphics
import Testing

@MainActor
struct EditorSessionTests {
    private let session = EditorSession(imageSize: CGSize(width: 1000, height: 800))

    private func drag(from start: CGPoint, to end: CGPoint) {
        session.pointerDown(at: start, tolerance: 6)
        session.pointerDragged(to: end)
        session.pointerUp()
    }

    @Test func ドラッグで矩形を作り選択状態にする() {
        session.tool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 50, y: 300))

        #expect(session.annotations.count == 1)
        #expect(session.annotations[0].kind == .rectangle(CGRect(x: 50, y: 100, width: 50, height: 200)))
        #expect(session.selection == session.annotations[0].id)
    }

    @Test func クリックだけでは何も作らず取り消し履歴も積まない() {
        session.tool = .arrow
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 101, y: 100))

        #expect(session.annotations.isEmpty)
        #expect(!session.canUndo)
    }

    @Test func 既存の注釈を掴むと新しく作らずに移動する() {
        session.tool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        drag(from: CGPoint(x: 100, y: 150), to: CGPoint(x: 150, y: 170))

        #expect(session.annotations.count == 1)
        #expect(session.annotations[0].bounds.origin == CGPoint(x: 150, y: 120))
    }

    @Test func 選択中の角のつまみでリサイズする() {
        session.tool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        drag(from: CGPoint(x: 300, y: 200), to: CGPoint(x: 400, y: 250))

        #expect(session.annotations[0].bounds == CGRect(x: 100, y: 100, width: 300, height: 150))
    }

    @Test func 一回のドラッグは一回の取り消しで戻る() {
        session.tool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        session.pointerDown(at: CGPoint(x: 100, y: 150), tolerance: 6)
        session.pointerDragged(to: CGPoint(x: 120, y: 150))
        session.pointerDragged(to: CGPoint(x: 140, y: 150))
        session.pointerUp()

        session.undo()
        #expect(session.annotations[0].bounds.origin == CGPoint(x: 100, y: 100))
        session.undo()
        #expect(session.annotations.isEmpty)
        session.redo()
        #expect(session.annotations.count == 1)
    }

    @Test func 新しい操作をするとやり直し履歴は消える() {
        session.tool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        session.undo()
        drag(from: CGPoint(x: 500, y: 500), to: CGPoint(x: 600, y: 600))
        #expect(!session.canRedo)
    }

    @Test func 選択中の注釈を削除し取り消せる() {
        session.tool = .arrow
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        session.deleteSelection()
        #expect(session.annotations.isEmpty)
        session.undo()
        #expect(session.annotations.count == 1)
    }

    @Test func 色を変えると選択中の注釈も塗り替える() {
        session.tool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        session.color = .blue
        #expect(session.annotations[0].color == .blue)
        session.undo()
        #expect(session.annotations[0].color == .red)
    }

    @Test func テキストを確定すると注釈になり空なら何も作らない() {
        session.tool = .text
        session.pointerDown(at: CGPoint(x: 10, y: 20), tolerance: 6)
        #expect(session.textEditing?.origin == CGPoint(x: 10, y: 20))
        session.commitText("  ", size: CGSize(width: 10, height: 20))
        #expect(session.annotations.isEmpty)

        session.pointerDown(at: CGPoint(x: 10, y: 20), tolerance: 6)
        session.commitText("こんにちは", size: CGSize(width: 100, height: 30))
        #expect(session.annotations.first?.kind == .text(CGRect(x: 10, y: 20, width: 100, height: 30), string: "こんにちは", fontSize: session.fontSize))
    }

    @Test func 既存のテキストをクリックすると編集し空にすると消える() {
        session.tool = .text
        session.pointerDown(at: CGPoint(x: 10, y: 20), tolerance: 6)
        session.commitText("メモ", size: CGSize(width: 100, height: 30))
        let id = session.annotations[0].id

        session.pointerDown(at: CGPoint(x: 50, y: 30), tolerance: 6)
        #expect(session.textEditing?.id == id)
        #expect(session.displayAnnotations.isEmpty) // 編集中は入力欄が代わりに表示する

        session.commitText("", size: .zero)
        #expect(session.annotations.isEmpty)
    }

    @Test func 保存後は未保存の変更なしになる() {
        session.tool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        #expect(session.hasUnsavedChanges)
        session.markSaved()
        #expect(!session.hasUnsavedChanges)
    }
}
