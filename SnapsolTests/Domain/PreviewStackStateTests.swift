import Foundation
import Testing

struct PreviewStackStateTests {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let a = UUID(), b = UUID(), c = UUID()

    @Test func 新しいカードを先頭に積む() {
        var state = PreviewStackState()
        state.push(a, now: t0, lifetime: 6)
        state.push(b, now: t0, lifetime: 6)
        #expect(state.cards.map(\.id) == [b, a])
    }

    @Test func 上限を超えたら最も古いカードを押し出す() {
        var state = PreviewStackState(maxCards: 2)
        state.push(a, now: t0, lifetime: 6)
        state.push(b, now: t0, lifetime: 6)
        let overflow = state.push(c, now: t0, lifetime: 6)
        #expect(overflow == [a])
        #expect(state.cards.map(\.id) == [c, b])
    }

    @Test func 期限が来たカードだけ取り除く() {
        var state = PreviewStackState()
        state.push(a, now: t0, lifetime: 6)
        state.push(b, now: t0.addingTimeInterval(3), lifetime: 6)

        #expect(state.removeExpired(now: t0.addingTimeInterval(6)) == [a])
        #expect(state.cards.map(\.id) == [b])
        #expect(state.nextDeadline == t0.addingTimeInterval(9))
    }

    @Test func ホバー中はどのカードも閉じない() {
        var state = PreviewStackState()
        state.push(a, now: t0, lifetime: 6)
        state.setHovering(true, now: t0.addingTimeInterval(1))

        #expect(state.removeExpired(now: t0.addingTimeInterval(100)).isEmpty)
        #expect(state.nextDeadline == nil)
    }

    @Test func ホバーをやめたら最低限の猶予を与える() {
        var state = PreviewStackState()
        state.push(a, now: t0, lifetime: 6)
        state.setHovering(true, now: t0.addingTimeInterval(1))
        let leave = t0.addingTimeInterval(10)
        state.setHovering(false, now: leave)

        #expect(state.nextDeadline == leave.addingTimeInterval(PreviewStackState.hoverGrace))
    }

    @Test func 寿命なしのカードは自動で閉じない() {
        var state = PreviewStackState()
        state.push(a, now: t0, lifetime: nil)
        #expect(state.nextDeadline == nil)
        #expect(state.removeExpired(now: t0.addingTimeInterval(1_000)).isEmpty)
    }

    @Test func 同じIDを積み直すと先頭に移動する() {
        var state = PreviewStackState()
        state.push(a, now: t0, lifetime: 6)
        state.push(b, now: t0, lifetime: 6)
        state.push(a, now: t0, lifetime: 6)
        #expect(state.cards.map(\.id) == [a, b])
    }
}
