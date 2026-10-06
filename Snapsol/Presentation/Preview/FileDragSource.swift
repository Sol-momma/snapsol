import AppKit
import SwiftUI

/// カードを他アプリへドラッグしてファイルを渡す。
/// SwiftUI の onDrag は操作の種類を指定できず、Finder へのドロップが「移動」になって
/// 履歴の実体が消えることがある。NSDraggingSource で `.copy` に固定する。
struct FileDragSource: NSViewRepresentable {
    let url: URL
    let image: CGImage?
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> DragSourceView {
        DragSourceView()
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.url = url
        view.image = image
        view.onDragEnded = onDragEnded
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var url: URL?
    var image: CGImage?
    var onDragEnded: (() -> Void)?
    private var dragStarted = false

    /// 非アクティブなパネルでも最初のクリックからドラッグできるようにする
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted, let url else { return }
        dragStarted = true
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: image.map { NSImage(cgImage: $0, size: bounds.size) })
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] { onDragEnded?() }
    }
}
