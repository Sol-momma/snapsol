import AppKit
import SwiftUI

enum PreviewCardAction {
    case copy, save, annotate, delete, close, dragEnded
}

/// 撮影後カードを画面右下に積むパネル。状態は `PreviewStackState` に任せ、ここはタイマーとウィンドウの面倒を見る。
@MainActor
@Observable
final class PreviewPanelController {
    static let cardSize = CGSize(width: 220, height: 140)
    static let spacing: CGFloat = 12
    static let margin: CGFloat = 16

    struct Actions {
        var copy: (HistoryEntry) -> Void
        var save: (HistoryEntry) -> Void
        var annotate: (HistoryEntry) -> Void
        var delete: (HistoryEntry) -> Void
    }

    private(set) var state = PreviewStackState()
    @ObservationIgnored let history: HistoryService
    @ObservationIgnored let thumbnails: any ThumbnailProviding
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var screen: NSScreen?
    @ObservationIgnored private var timer: Task<Void, Never>?

    init(history: HistoryService, thumbnails: any ThumbnailProviding, settings: AppSettings, actions: Actions) {
        self.history = history
        self.thumbnails = thumbnails
        self.settings = settings
        self.actions = actions
    }

    /// 新しい順。履歴から消えた項目は出さない
    var entries: [HistoryEntry] {
        state.cards.compactMap { history.entry(id: $0.id) }
    }

    func show(_ entry: HistoryEntry) {
        if state.cards.isEmpty {
            screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        }
        state.push(entry.id, now: .now, lifetime: settings.cardLifetime > 0 ? settings.cardLifetime : nil)
        stateDidChange()
    }

    func dismiss(_ id: HistoryEntry.ID) {
        state.remove(id)
        stateDidChange()
    }

    func setHovering(_ hovering: Bool) {
        state.setHovering(hovering, now: .now)
        scheduleTimer()
    }

    func handle(_ action: PreviewCardAction, for entry: HistoryEntry) {
        switch action {
        case .copy:
            actions.copy(entry)
            dismiss(entry.id)
        case .save:
            actions.save(entry)
        case .annotate:
            actions.annotate(entry)
            dismiss(entry.id)
        case .delete:
            actions.delete(entry)
            dismiss(entry.id)
        case .close, .dragEnded:
            dismiss(entry.id)
        }
    }

    private func stateDidChange() {
        updatePanel()
        scheduleTimer()
    }

    /// 次の期限に 1 回だけ起きる。状態が変わるたびに張り直す
    private func scheduleTimer() {
        timer?.cancel()
        guard let deadline = state.nextDeadline else { return }
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self else { return }
            _ = state.removeExpired(now: .now)
            stateDidChange()
        }
    }

    private func updatePanel() {
        let count = state.cards.count
        guard count > 0 else {
            panel?.orderOut(nil)
            panel = nil
            // パネルごと消えると onHover の終了が届かないので、ここで解除しておく
            state.setHovering(false, now: .now)
            return
        }
        let panel = panel ?? makePanel()
        self.panel = panel

        let size = CGSize(
            width: Self.cardSize.width + Self.margin * 2,
            height: CGFloat(count) * Self.cardSize.height + CGFloat(count - 1) * Self.spacing + Self.margin * 2
        )
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrame(NSRect(x: visible.maxX - size.width, y: visible.minY, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = PreviewPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        // NSPanel は既定でアプリが非アクティブになると隠れる。常駐アプリでは常にそうなので無効にする
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // 次のスクリーンショットにカード自身が写り込まないようにする
        panel.sharingType = .none
        panel.contentView = NSHostingView(rootView: PreviewStackView(controller: self))
        return panel
    }
}

/// ボタンを押せるよう key になれるが、.nonactivatingPanel なので前面アプリのフォーカスは奪わない
private final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
