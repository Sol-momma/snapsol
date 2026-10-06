import CoreGraphics
import Foundation

/// 注釈 1 つ分。座標はすべて**画像のピクセル座標・左上原点**。
/// 画面の拡大率に依存しないので、表示とフル解像度の書き出しで同じ値をそのまま使える。
struct Annotation: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case rectangle(CGRect)
        case arrow(start: CGPoint, end: CGPoint)
        /// rect は文字列を描いたときの外接矩形（計測は描画側が行う）
        case text(CGRect, string: String, fontSize: CGFloat)
        case mosaic(CGRect)
    }

    let id: UUID
    var kind: Kind
    var color: AnnotationColor
    var lineWidth: CGFloat
}

/// 選択中の注釈を変形するためのつまみ
enum AnnotationHandle: Hashable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight
    case arrowStart, arrowEnd
}

extension Annotation {
    var bounds: CGRect {
        switch kind {
        case .rectangle(let rect), .mosaic(let rect), .text(let rect, _, _):
            rect
        case .arrow(let start, let end):
            CGRect(corner: start, corner: end)
        }
    }

    /// 作成途中のドラッグが短すぎて、意図した図形になっていない
    var isDegenerate: Bool {
        switch kind {
        case .rectangle(let rect), .mosaic(let rect):
            rect.width < 3 || rect.height < 3
        case .arrow(let start, let end):
            hypot(end.x - start.x, end.y - start.y) < 5
        case .text(_, let string, _):
            string.isEmpty
        }
    }

    /// - Parameter tolerance: 当たりとみなす距離（画像ピクセル）。画面上で一定の掴みやすさにするため呼び出し側が拡大率から決める
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        switch kind {
        case .rectangle(let rect):
            // 枠線の近くだけが当たる。内側も当たると、大きな枠の中にある別の注釈を掴めなくなる
            let reach = tolerance + lineWidth / 2
            let outer = rect.insetBy(dx: -reach, dy: -reach)
            let inner = rect.insetBy(dx: reach, dy: reach)
            return outer.contains(point) && (inner.isNull || !inner.contains(point))
        case .arrow(let start, let end):
            return point.distance(toSegmentFrom: start, to: end) <= tolerance + lineWidth / 2
        case .text(let rect, _, _), .mosaic(let rect):
            return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    func translated(by delta: CGVector) -> Annotation {
        var copy = self
        switch kind {
        case .rectangle(let rect):
            copy.kind = .rectangle(rect.offsetBy(dx: delta.dx, dy: delta.dy))
        case .mosaic(let rect):
            copy.kind = .mosaic(rect.offsetBy(dx: delta.dx, dy: delta.dy))
        case .text(let rect, let string, let fontSize):
            copy.kind = .text(rect.offsetBy(dx: delta.dx, dy: delta.dy), string: string, fontSize: fontSize)
        case .arrow(let start, let end):
            copy.kind = .arrow(start: start.offsetBy(delta), end: end.offsetBy(delta))
        }
        return copy
    }

    var handles: [AnnotationHandle: CGPoint] {
        switch kind {
        case .rectangle(let rect), .mosaic(let rect):
            [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            ]
        case .arrow(let start, let end):
            [.arrowStart: start, .arrowEnd: end]
        case .text:
            [:] // テキストは移動のみ（大きさはフォントサイズで決まる）
        }
    }

    func handle(at point: CGPoint, tolerance: CGFloat) -> AnnotationHandle? {
        handles.first { hypot($0.value.x - point.x, $0.value.y - point.y) <= tolerance }?.key
    }

    /// つまみを `point` まで動かした結果。矩形は対角のつまみを固定し、裏返しても正規化する
    func resized(_ handle: AnnotationHandle, to point: CGPoint) -> Annotation {
        var copy = self
        switch (kind, handle) {
        case (.rectangle(let rect), _):
            copy.kind = .rectangle(CGRect(corner: rect.opposite(of: handle), corner: point))
        case (.mosaic(let rect), _):
            copy.kind = .mosaic(CGRect(corner: rect.opposite(of: handle), corner: point))
        case (.arrow(_, let end), .arrowStart):
            copy.kind = .arrow(start: point, end: end)
        case (.arrow(let start, _), .arrowEnd):
            copy.kind = .arrow(start: start, end: point)
        default:
            break
        }
        return copy
    }
}

extension CGRect {
    /// 2 点を対角とする矩形（どちら向きにドラッグしても幅・高さが正になる）
    init(corner a: CGPoint, corner b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    fileprivate func opposite(of handle: AnnotationHandle) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: maxX, y: maxY)
        case .topRight: CGPoint(x: minX, y: maxY)
        case .bottomLeft: CGPoint(x: maxX, y: minY)
        case .bottomRight, .arrowStart, .arrowEnd: CGPoint(x: minX, y: minY)
        }
    }
}

extension CGPoint {
    func offsetBy(_ delta: CGVector) -> CGPoint {
        CGPoint(x: x + delta.dx, y: y + delta.dy)
    }

    func distance(toSegmentFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(x - a.x, y - a.y) }
        // 線分上で最も近い点の位置（0...1 に収める）
        let t = max(0, min(1, ((x - a.x) * dx + (y - a.y) * dy) / lengthSquared))
        return hypot(x - (a.x + t * dx), y - (a.y + t * dy))
    }
}
