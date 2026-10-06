import AppKit
import Carbon.HIToolbox
import SwiftUI

/// SwiftUI から使うためのラッパー。注釈や選択が変わると updateNSView が呼ばれて再描画する
struct AnnotationCanvas: NSViewRepresentable {
    let session: EditorSession
    let baseImage: CGImage
    let mosaicSource: CGImage?
    let renderer: any AnnotationRendering
    // 以下は変更検知のためだけに受け取る（値が変わると updateNSView が走る）
    let annotations: [Annotation]
    let selection: Annotation.ID?
    let tool: EditorTool
    let textEditing: EditorSession.TextEditing?

    func makeNSView(context: Context) -> AnnotationCanvasView {
        AnnotationCanvasView(session: session, baseImage: baseImage, mosaicSource: mosaicSource, renderer: renderer)
    }

    func updateNSView(_ view: AnnotationCanvasView, context: Context) {
        view.sessionDidChange()
    }
}

/// 画像を縦横比を保って中央に表示し、その上に注釈を描く。
/// マウス位置は画像ピクセル座標に変換してから `EditorSession` に渡す。
final class AnnotationCanvasView: NSView, NSTextViewDelegate {
    private let session: EditorSession
    private let baseImage: CGImage
    private let mosaicSource: CGImage?
    private let renderer: any AnnotationRendering
    private var textView: NSTextView?

    init(session: EditorSession, baseImage: CGImage, mosaicSource: CGImage?, renderer: any AnnotationRendering) {
        self.session = session
        self.baseImage = baseImage
        self.mosaicSource = mosaicSource
        self.renderer = renderer
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    func sessionDidChange() {
        syncTextEditor()
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    // MARK: - 座標変換

    private var imageSize: CGSize { session.imageSize }

    /// 画像を表示している矩形（ビュー座標）
    private var imageFrame: CGRect {
        let available = bounds.insetBy(dx: 16, dy: 16)
        let scale = min(available.width / imageSize.width, available.height / imageSize.height, 1 / backingScale)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// ビュー 1pt あたりの画像ピクセル数の逆数（画像 1px が何 pt で表示されているか）
    private var scale: CGFloat { imageFrame.width / imageSize.width }

    /// 等倍より大きく引き伸ばさない（Retina 画像は 2px = 1pt で表示する）
    private var backingScale: CGFloat { window?.backingScaleFactor ?? 2 }

    private func toImage(_ point: NSPoint) -> CGPoint {
        CGPoint(x: (point.x - imageFrame.minX) / scale, y: (point.y - imageFrame.minY) / scale)
    }

    private func toView(_ point: CGPoint) -> NSPoint {
        NSPoint(x: imageFrame.minX + point.x * scale, y: imageFrame.minY + point.y * scale)
    }

    /// 画面上で 6pt 以内なら当たりにする（拡大率が変わっても掴みやすさを一定にする）
    private var tolerance: CGFloat { 6 / scale }

    // MARK: - 描画

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let frame = imageFrame

        NSImage(cgImage: baseImage, size: frame.size)
            .draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

        context.saveGState()
        context.clip(to: frame)
        context.translateBy(x: frame.minX, y: frame.minY)
        context.scaleBy(x: scale, y: scale)
        renderer.draw(session.displayAnnotations, in: context, imageSize: imageSize, mosaicSource: mosaicSource)
        context.restoreGState()

        drawSelection(in: context)
    }

    private func drawSelection(in context: CGContext) {
        guard let selected = session.selectedAnnotation, session.textEditing == nil else { return }
        let topLeft = toView(selected.bounds.origin)
        let bottomRight = toView(CGPoint(x: selected.bounds.maxX, y: selected.bounds.maxY))
        let outline = CGRect(corner: topLeft, corner: bottomRight).insetBy(dx: -4, dy: -4)

        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(outline)
        context.setLineDash(phase: 0, lengths: [])
        for point in selected.handles.values {
            let center = toView(point)
            let handle = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(handle)
            context.stroke(handle)
        }
        context.restoreGState()
    }

    override func resetCursorRects() {
        addCursorRect(imageFrame, cursor: session.tool == .select ? .arrow : (session.tool == .text ? .iBeam : .crosshair))
    }

    // MARK: - マウス

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if textView != nil {
            // 入力欄の外をクリックしたら確定するだけ（このクリックでは描かない）
            window?.makeFirstResponder(self)
            return
        }
        window?.makeFirstResponder(self)
        session.pointerDown(at: toImage(convert(event.locationInWindow, from: nil)), tolerance: tolerance)
        sessionDidChange()
    }

    override func mouseDragged(with event: NSEvent) {
        session.pointerDragged(to: toImage(convert(event.locationInWindow, from: nil)))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        session.pointerUp()
        needsDisplay = true
    }

    // MARK: - キーボード

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch Int(event.keyCode) {
        case kVK_Delete, kVK_ForwardDelete:
            session.deleteSelection()
        case kVK_Escape:
            session.clearSelection()
        default:
            guard modifiers.isEmpty, let tool = Self.toolShortcuts[event.charactersIgnoringModifiers ?? ""] else {
                super.keyDown(with: event)
                return
            }
            session.tool = tool
        }
        sessionDidChange()
    }

    static let toolShortcuts: [String: EditorTool] = ["v": .select, "r": .rectangle, "a": .arrow, "t": .text, "m": .mosaic]

    /// メインメニューの「取り消す」（⌘Z）はレスポンダチェーンでここに届く
    @objc func undo(_ sender: Any?) {
        session.undo()
        sessionDidChange()
    }

    @objc func redo(_ sender: Any?) {
        session.redo()
        sessionDidChange()
    }

    // MARK: - テキスト入力

    /// 実物の NSTextView を重ねて入力させる。日本語 IME の変換や選択がそのまま使える
    private func syncTextEditor() {
        guard let editing = session.textEditing else {
            removeTextView()
            return
        }
        guard textView == nil else { return }

        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.6)
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        // 画面上の大きさ = 画像上のフォントサイズ × 表示倍率
        textView.typingAttributes = [
            .font: renderer.textFont(ofSize: editing.fontSize * scale) as NSFont,
            .foregroundColor: NSColor(srgbRed: editing.color.red, green: editing.color.green, blue: editing.color.blue, alpha: 1),
        ]
        textView.string = editing.string
        textView.setFrameOrigin(toView(editing.origin))
        textView.delegate = self
        addSubview(textView)
        resizeTextView(textView)
        window?.makeFirstResponder(textView)
        self.textView = textView
    }

    private func resizeTextView(_ textView: NSTextView) {
        guard let container = textView.textContainer, let layout = textView.layoutManager else { return }
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container).size
        let lineHeight = (textView.typingAttributes[.font] as? NSFont).map { layout.defaultLineHeight(for: $0) } ?? 20
        textView.setFrameSize(NSSize(width: max(used.width + 8, 40), height: max(used.height, lineHeight)))
    }

    private func removeTextView() {
        guard let textView else { return }
        // 先に参照を外す。removeFromSuperview でフォーカスが外れて textDidEndEditing が二重に呼ばれるのを防ぐ
        self.textView = nil
        textView.delegate = nil
        textView.removeFromSuperview()
        window?.makeFirstResponder(self)
    }

    func textDidChange(_ notification: Notification) {
        if let textView { resizeTextView(textView) }
    }

    func textDidEndEditing(_ notification: Notification) {
        guard let textView, let editing = session.textEditing else { return }
        let string = textView.string
        session.commitText(string, size: renderer.textSize(string, fontSize: editing.fontSize))
        sessionDidChange()
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(cancelOperation(_:)) {
            session.cancelText()
            sessionDidChange()
            return true
        }
        return false
    }
}
