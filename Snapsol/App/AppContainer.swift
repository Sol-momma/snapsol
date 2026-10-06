import AppKit
import os

/// 依存関係を組み立てる唯一の場所。
/// 各層の具体型（Infrastructure）をここで生成し、Application / Presentation に注入する。
@MainActor
final class AppContainer: CaptureResultPresenting {
    private let logger = Logger(subsystem: "com.solmomma.snapsol", category: "App")
    private let paths = AppPaths.standard()
    private let settings = AppSettings(defaults: .standard)
    private let thumbnails = ThumbnailLoader()
    private let clipboard = PasteboardClipboard()
    private let toast = ToastPresenter()
    private let exporter: PicturesExporter
    private let history: HistoryService
    private let hotkeys = HotkeyBindingService(
        registrar: CarbonHotkeyRegistrar(),
        store: UserDefaultsHotkeyStore(defaults: .standard)
    )
    private let windows = WindowPresenter(activation: ActivationPolicyController())
    private var captureFlow: CaptureFlow!
    private var textCaptureFlow: TextCaptureFlow!
    private var preview: PreviewPanelController!
    private var statusItem: StatusItemController!

    init() {
        exporter = PicturesExporter(directory: paths.exportDirectory)
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
        captureFlow = CaptureFlow(capturer: capturer, history: history, settings: settings, clipboard: clipboard, presenter: self)
        textCaptureFlow = TextCaptureFlow(
            capturer: capturer,
            recognizer: VisionTextRecognizer(),
            clipboard: clipboard,
            toast: toast
        )
        preview = PreviewPanelController(
            history: history,
            thumbnails: thumbnails,
            settings: settings,
            actions: .init(
                copy: { [weak self] entry in self?.copy(entry) },
                save: { [weak self] entry in self?.save(entry) },
                annotate: { [weak self] entry in self?.openEditor(for: entry) },
                delete: { [weak self] entry in self?.delete(entry) }
            )
        )
        statusItem = StatusItemController(
            history: history,
            hotkeys: hotkeys,
            thumbnails: thumbnails,
            actions: .init(
                perform: { [weak self] action in self?.perform(action) },
                selectRecent: { [weak self] entry in self?.copy(entry) },
                showHistory: { [weak self] in self?.showHistory() },
                showSettings: { [weak self] in self?.showSettings() }
            )
        )
        MainMenuInstaller.install { [weak self] in self?.showSettings() }

        hotkeys.onAction = { [weak self] action in self?.perform(action) }
        hotkeys.start()

        Task {
            do { try await history.reload() } catch { logger.error("履歴の読み込みに失敗: \(error)") }
        }
    }

    // MARK: - CaptureResultPresenting

    func showCard(for entry: HistoryEntry) {
        preview.show(entry)
    }

    func openEditor(for entry: HistoryEntry) {
        logger.info("TODO(ステップ8): 注釈エディタを開く \(entry.fileName)")
    }

    // MARK: - Actions

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

    private func save(_ entry: HistoryEntry) {
        do {
            let url = try exporter.export(history.fileURL(for: entry))
            toast.show("保存しました", detail: url.path(percentEncoded: false))
        } catch {
            logger.error("保存に失敗: \(error)")
            toast.show("保存に失敗しました", detail: error.localizedDescription)
        }
    }

    private func reveal(_ entry: HistoryEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([history.fileURL(for: entry)])
    }

    private func showHistory() {
        windows.show(id: "history", title: "撮影履歴", size: NSSize(width: 760, height: 520)) {
            HistoryGridView(
                history: history,
                thumbnails: thumbnails,
                actions: .init(
                    copy: { [weak self] in self?.copy($0) },
                    save: { [weak self] in self?.save($0) },
                    annotate: { [weak self] in self?.openEditor(for: $0) },
                    reveal: { [weak self] in self?.reveal($0) },
                    delete: { [weak self] in self?.delete($0) }
                )
            )
        }
    }

    private func showSettings() {
        windows.show(id: "settings", title: "Snapsol の設定", size: NSSize(width: 520, height: 480)) {
            SettingsView(settings: settings, hotkeys: hotkeys)
        }
    }

    private func delete(_ entry: HistoryEntry) {
        preview.dismiss(entry.id)
        Task {
            do { try await history.delete(entry) } catch { logger.error("削除に失敗: \(error)") }
        }
    }
}
