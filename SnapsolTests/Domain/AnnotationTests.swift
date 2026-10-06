import CoreGraphics
import Foundation
import Testing

struct AnnotationTests {
    private func make(_ kind: Annotation.Kind, lineWidth: CGFloat = 4) -> Annotation {
        Annotation(id: UUID(), kind: kind, color: .red, lineWidth: lineWidth)
    }

    @Test func 矩形は枠線の近くだけが当たり内側は当たらない() {
        let rect = make(.rectangle(CGRect(x: 100, y: 100, width: 200, height: 100)))
        #expect(rect.hitTest(CGPoint(x: 101, y: 150), tolerance: 4))
        #expect(!rect.hitTest(CGPoint(x: 200, y: 150), tolerance: 4))
        #expect(!rect.hitTest(CGPoint(x: 80, y: 150), tolerance: 4))
    }

    @Test func 矢印は線分からの距離で当たる() {
        let arrow = make(.arrow(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 0)))
        #expect(arrow.hitTest(CGPoint(x: 50, y: 5), tolerance: 4))
        #expect(!arrow.hitTest(CGPoint(x: 50, y: 20), tolerance: 4))
        // 線分の延長線上は当たらない
        #expect(!arrow.hitTest(CGPoint(x: 130, y: 0), tolerance: 4))
    }

    @Test func モザイクとテキストは内側も当たる() {
        let mosaic = make(.mosaic(CGRect(x: 0, y: 0, width: 50, height: 50)))
        #expect(mosaic.hitTest(CGPoint(x: 25, y: 25), tolerance: 4))
    }

    @Test func 角のつまみを対角の外へ引くと正規化される() {
        let rect = make(.rectangle(CGRect(x: 10, y: 10, width: 40, height: 40)))
        let resized = rect.resized(.bottomRight, to: CGPoint(x: 0, y: 0))
        #expect(resized.bounds == CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    @Test func 矢印の終点だけを動かせる() {
        let arrow = make(.arrow(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 10, y: 10)))
        #expect(arrow.resized(.arrowEnd, to: CGPoint(x: 50, y: 0)).kind == .arrow(start: .zero, end: CGPoint(x: 50, y: 0)))
    }

    @Test func 平行移動はすべての座標をずらす() {
        let arrow = make(.arrow(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 10, y: 10)))
        let moved = arrow.translated(by: CGVector(dx: 5, dy: -5))
        #expect(moved.kind == .arrow(start: CGPoint(x: 5, y: -5), end: CGPoint(x: 15, y: 5)))
    }
}
