import AppKit
import os

/// 依存関係を組み立てる唯一の場所。
/// 各層の具体型（Infrastructure）をここで生成し、Application / Presentation に注入する。
@MainActor
final class AppContainer {
    private let logger = Logger(subsystem: "com.solmomma.snapsol", category: "App")
    private let paths = AppPaths.standard()
    private let thumbnails = ThumbnailLoader()
    private let history: HistoryService
    private let hotkeys = HotkeyBindingService(
        registrar: CarbonHotkeyRegistrar(),
        store: UserDefaultsHotkeyStore(defaults: .standard)
    )
    private var captureFlow: CaptureFlow!
    private var statusItem: StatusItemController!

    init() {
        history = HistoryService(repository: FileHistoryRepository(
            historyDirectory: paths.historyDirectory,
            indexFile: paths.historyIndexFile
        ))
        let capturer = ScreencaptureService(
            runner: ProcessRunner(),
            temporaryDirectory: FileManager.default.temporaryDirectory,
            displayIndex: { DisplayResolver.indexOfDisplayUnderCursor() }
        )
        captureFlow = CaptureFlow(capturer: capturer, history: history) { _ in }
        statusItem = StatusItemController(
            history: history,
            thumbnails: thumbnails,
            actions: .init(
                capture: { [weak self] mode in self?.capture(mode) },
                selectRecent: { [weak self] entry in self?.revealInFinder(entry) }
            )
        )

        hotkeys.onAction = { [weak self] action in self?.perform(action) }
        hotkeys.start()

        Task {
            do { try await history.reload() } catch { logger.error("履歴の読み込みに失敗: \(error)") }
        }
    }

    private func perform(_ action: HotkeyAction) {
        switch action {
        case .captureFullscreen: capture(.fullscreen)
        case .captureWindow: capture(.window)
        case .captureArea: capture(.area)
        case .captureText: break // TODO(ステップ4): OCR
        }
    }

    private func capture(_ mode: CaptureMode) {
        Task {
            do { try await captureFlow.run(mode) } catch { logger.error("撮影に失敗: \(error)") }
        }
    }

    private func revealInFinder(_ entry: HistoryEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([history.fileURL(for: entry)])
    }
}
