import CoreGraphics
import Foundation
import Observation

enum EditorTool: CaseIterable, Sendable {
    case select, rectangle, arrow, text, mosaic
}

/// 注釈エディタ 1 枚分の状態。ポインタ入力（画像ピクセル座標）を受けて注釈を作る・動かす。
/// View には依存しないので、マウス操作をそのままテストで再現できる。
@MainActor
@Observable
final class EditorSession {
    /// 編集中のテキスト。Presentation はこれを見て入力欄を重ねる
    struct TextEditing: Equatable {
        /// 既存のテキストを編集しているならその ID
        var id: Annotation.ID?
        var origin: CGPoint
        var string: String
        var fontSize: CGFloat
        var color: AnnotationColor
    }

    private enum Interaction {
        case idle
        case creating(id: Annotation.ID, origin: CGPoint)
        case moving(original: Annotation, start: CGPoint)
        case resizing(original: Annotation, handle: AnnotationHandle)
    }

    let imageSize: CGSize
    /// 画像の大きさに比例させる。4K の画像でも線や文字が細すぎないように
    let lineWidth: CGFloat
    let fontSize: CGFloat

    private(set) var annotations: [Annotation] = []
    private(set) var selection: Annotation.ID?
    private(set) var textEditing: TextEditing?
    private(set) var undoStack: [[Annotation]] = []
    private(set) var redoStack: [[Annotation]] = []

    var tool: EditorTool = .rectangle {
        didSet { if tool != oldValue { selection = nil } }
    }

    /// 新しい注釈の色。選択中の注釈があればそれも塗り替える
    var color: AnnotationColor = .red {
        didSet { recolorSelection() }
    }

    @ObservationIgnored private var interaction = Interaction.idle
    @ObservationIgnored private var snapshotBeforeInteraction: [Annotation]?
    @ObservationIgnored private var savedAnnotations: [Annotation] = []

    init(imageSize: CGSize) {
        self.imageSize = imageSize
        let longSide = max(imageSize.width, imageSize.height)
        lineWidth = max(3, (longSide * 0.004).rounded())
        fontSize = max(18, (longSide * 0.022).rounded())
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var hasUnsavedChanges: Bool { annotations != savedAnnotations }

    /// 画面に描く注釈（編集中のテキストは入力欄が代わりに表示するので除く）
    var displayAnnotations: [Annotation] {
        guard let id = textEditing?.id else { return annotations }
        return annotations.filter { $0.id != id }
    }

    var selectedAnnotation: Annotation? {
        selection.flatMap { id in annotations.first { $0.id == id } }
    }

    // MARK: - Pointer

    /// - Parameter tolerance: 当たり判定の距離（画像ピクセル）
    func pointerDown(at point: CGPoint, tolerance: CGFloat) {
        guard textEditing == nil else { return }
        snapshotBeforeInteraction = annotations

        if let selected = selectedAnnotation, let handle = selected.handle(at: point, tolerance: tolerance * 1.5) {
            interaction = .resizing(original: selected, handle: handle)
            return
        }
        if tool == .text {
            beginText(at: point, tolerance: tolerance)
            return
        }
        // どのツールでも、既存の注釈を掴んだら移動にする（描き直さずに位置を直せるように）
        if let hit = annotations.last(where: { $0.hitTest(point, tolerance: tolerance) }) {
            selection = hit.id
            interaction = .moving(original: hit, start: point)
            return
        }

        switch tool {
        case .select, .text:
            selection = nil
        case .rectangle:
            create(.rectangle(CGRect(origin: point, size: .zero)), at: point)
        case .mosaic:
            create(.mosaic(CGRect(origin: point, size: .zero)), at: point)
        case .arrow:
            create(.arrow(start: point, end: point), at: point)
        }
    }

    func pointerDragged(to point: CGPoint) {
        switch interaction {
        case .idle:
            break
        case .creating(let id, let origin):
            update(id) { annotation in
                switch annotation.kind {
                case .rectangle: annotation.kind = .rectangle(CGRect(corner: origin, corner: point))
                case .mosaic: annotation.kind = .mosaic(CGRect(corner: origin, corner: point))
                case .arrow: annotation.kind = .arrow(start: origin, end: point)
                case .text: break
                }
            }
        case .moving(let original, let start):
            replace(original.translated(by: CGVector(dx: point.x - start.x, dy: point.y - start.y)))
        case .resizing(let original, let handle):
            replace(original.resized(handle, to: point))
        }
    }

    func pointerUp() {
        if case .creating(let id, _) = interaction, annotations.first(where: { $0.id == id })?.isDegenerate == true {
            // クリックしただけ（ドラッグしていない）なら何も作らない
            annotations.removeAll { $0.id == id }
            selection = nil
        }
        interaction = .idle
        // 1 回のドラッグを 1 回の取り消し単位にする。何も変わらなければ積まない
        if let snapshot = snapshotBeforeInteraction, snapshot != annotations {
            pushUndo(snapshot)
        }
        snapshotBeforeInteraction = nil
    }

    // MARK: - Text

    func commitText(_ string: String, size: CGSize) {
        guard let editing = textEditing else { return }
        textEditing = nil
        let before = annotations
        let isEmpty = string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let kind = Annotation.Kind.text(CGRect(origin: editing.origin, size: size), string: string, fontSize: editing.fontSize)

        if let id = editing.id {
            if isEmpty {
                annotations.removeAll { $0.id == id }
                selection = nil
            } else {
                update(id) { $0.kind = kind }
            }
        } else if !isEmpty {
            let annotation = Annotation(id: UUID(), kind: kind, color: editing.color, lineWidth: lineWidth)
            annotations.append(annotation)
            selection = annotation.id
        }
        if before != annotations { pushUndo(before) }
    }

    func cancelText() {
        textEditing = nil
    }

    private func beginText(at point: CGPoint, tolerance: CGFloat) {
        snapshotBeforeInteraction = nil
        let hit = annotations.last { annotation in
            if case .text = annotation.kind { return annotation.hitTest(point, tolerance: tolerance) }
            return false
        }
        if let hit, case .text(let rect, let string, let fontSize) = hit.kind {
            selection = hit.id
            textEditing = TextEditing(id: hit.id, origin: rect.origin, string: string, fontSize: fontSize, color: hit.color)
        } else {
            selection = nil
            textEditing = TextEditing(id: nil, origin: point, string: "", fontSize: fontSize, color: color)
        }
    }

    // MARK: - Commands

    func deleteSelection() {
        guard let id = selection else { return }
        pushUndo(annotations)
        annotations.removeAll { $0.id == id }
        selection = nil
    }

    func clearSelection() {
        selection = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        restore(next)
    }

    /// 焼き込み保存した後に呼ぶ。以降は「未保存の変更なし」になる
    func markSaved() {
        savedAnnotations = annotations
    }

    // MARK: - Private

    private func create(_ kind: Annotation.Kind, at point: CGPoint) {
        let annotation = Annotation(id: UUID(), kind: kind, color: color, lineWidth: lineWidth)
        annotations.append(annotation)
        selection = annotation.id
        interaction = .creating(id: annotation.id, origin: point)
    }

    private func recolorSelection() {
        guard let selected = selectedAnnotation, selected.color != color else { return }
        pushUndo(annotations)
        update(selected.id) { $0.color = color }
    }

    private func update(_ id: Annotation.ID, _ change: (inout Annotation) -> Void) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        change(&annotations[index])
    }

    private func replace(_ annotation: Annotation) {
        update(annotation.id) { $0 = annotation }
    }

    private func pushUndo(_ snapshot: [Annotation]) {
        undoStack.append(snapshot)
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func restore(_ snapshot: [Annotation]) {
        annotations = snapshot
        textEditing = nil
        if let id = selection, !snapshot.contains(where: { $0.id == id }) {
            selection = nil
        }
    }
}
