import AppKit
import os

/// 依存関係を組み立てる唯一の場所。
/// 各層の具体型（Infrastructure）をここで生成し、Application / Presentation に注入する。
@MainActor
final class AppContainer {
    private let logger = Logger(subsystem: "com.solmomma.snapsol", category: "App")
    private let paths = AppPaths.standard()
    private let thumbnails = ThumbnailLoader()
    private let clipboard = PasteboardClipboard()
    private let toast = ToastPresenter()
    private let history: HistoryService
    private let hotkeys = HotkeyBindingService(
        registrar: CarbonHotkeyRegistrar(),
        store: UserDefaultsHotkeyStore(defaults: .standard)
    )
    private var captureFlow: CaptureFlow!
    private var textCaptureFlow: TextCaptureFlow!
    private var statusItem: StatusItemController!

    init() {
        history = HistoryService(repository: FileHistoryRepository(
            historyDirectory: paths.historyDirectory,
            indexFile: paths.historyIndexFile
        ))
        // 撮影と OCR で同じインスタンスを共有し、同時に 1 つしか screencapture を走らせない
        let capturer = ExclusiveScreenCapturer(ScreencaptureService(
            runner: ProcessRunner(),
            temporaryDirectory: FileManager.default.temporaryDirectory,
            displayIndex: { DisplayResolver.indexOfDisplayUnderCursor() }
        ))
        captureFlow = CaptureFlow(capturer: capturer, history: history) { _ in }
        textCaptureFlow = TextCaptureFlow(
            capturer: capturer,
            recognizer: VisionTextRecognizer(),
            clipboard: clipboard,
            toast: toast
        )
        statusItem = StatusItemController(
            history: history,
            thumbnails: thumbnails,
            actions: .init(
                perform: { [weak self] action in self?.perform(action) },
                selectRecent: { [weak self] entry in self?.copy(entry) }
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
        case .captureText:
            Task {
                do { try await textCaptureFlow.run() } catch { logger.error("文字の読み取りに失敗: \(error)") }
            }
        }
    }

    private func capture(_ mode: CaptureMode) {
        Task {
            do { try await captureFlow.run(mode) } catch { logger.error("撮影に失敗: \(error)") }
        }
    }

    private func copy(_ entry: HistoryEntry) {
        do {
            try clipboard.copyImage(at: history.fileURL(for: entry))
            toast.show("画像をコピーしました", detail: nil)
        } catch {
            logger.error("コピーに失敗: \(error)")
        }
    }
}
