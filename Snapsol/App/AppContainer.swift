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
    private let renderer = CoreGraphicsAnnotationRenderer()
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
                showSettings: { [weak self] in self?.showSettings() },
                isScreenCaptureGranted: { ScreenCapturePermission.isGranted },
                openScreenCaptureSettings: { ScreenCapturePermission.openSystemSettings() }
            )
        )
        if !ScreenCapturePermission.isGranted {
            ScreenCapturePermission.request()
        }
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
        let url = history.fileURL(for: entry)
        guard let image = renderer.loadImage(at: url) else {
            toast.show("画像を開けませんでした", detail: entry.fileName)
            return
        }
        let session = EditorSession(imageSize: CGSize(width: image.width, height: image.height))
        let windowID = "editor-\(entry.id)"

        windows.show(
            id: windowID,
            title: "注釈 — \(entry.fileName)",
            size: editorWindowSize(for: image),
            shouldClose: { [weak self] in self?.confirmClose(session, entry: entry, windowID: windowID) ?? true }
        ) {
            EditorView(
                session: session,
                baseImage: image,
                mosaicSource: renderer.mosaicSource(for: image),
                renderer: renderer,
                onCopy: { [weak self] in self?.copyAnnotated(session, entry: entry) },
                onSave: { [weak self] in self?.saveAnnotated(session, entry: entry, windowID: windowID) }
            )
        }
    }

    // MARK: - Editor

    /// 画像を等倍（Retina は 2px = 1pt）で収まる大きさにし、画面に収まらなければ縮める
    private func editorWindowSize(for image: CGImage) -> NSSize {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let limit = (NSScreen.main?.visibleFrame.size ?? NSSize(width: 1200, height: 800)).applying(.init(scaleX: 0.85, y: 0.85))
        let toolbarHeight: CGFloat = 52, padding: CGFloat = 32
        let natural = NSSize(width: CGFloat(image.width) / scale + padding, height: CGFloat(image.height) / scale + padding)
        let fit = min(1, limit.width / natural.width, (limit.height - toolbarHeight) / natural.height)
        return NSSize(width: max(640, natural.width * fit), height: max(420, natural.height * fit + toolbarHeight))
    }

    /// 元画像に注釈を焼き込んだ PNG。フル解像度の描画は重いのでメインスレッドの外で行う
    private func renderAnnotated(_ session: EditorSession, entry: HistoryEntry) async throws -> Data {
        let url = history.fileURL(for: entry)
        let annotations = session.annotations
        let renderer = renderer
        return try await Task.detached { try renderer.renderPNG(baseImageAt: url, annotations: annotations) }.value
    }

    private func saveAnnotated(_ session: EditorSession, entry: HistoryEntry, windowID: String) {
        Task {
            do {
                let data = try await renderAnnotated(session, entry: entry)
                _ = try await history.replaceImage(of: entry, with: data)
                session.markSaved()
                windows.close(id: windowID)
                toast.show("注釈を保存しました", detail: nil)
            } catch {
                logger.error("注釈の保存に失敗: \(error)")
                toast.show("保存に失敗しました", detail: error.localizedDescription)
            }
        }
    }

    /// 保存せずに、注釈を焼き込んだ画像をクリップボードへ
    private func copyAnnotated(_ session: EditorSession, entry: HistoryEntry) {
        guard !session.annotations.isEmpty else {
            copy(entry)
            return
        }
        Task {
            do {
                let data = try await renderAnnotated(session, entry: entry)
                // 貼り付け先にファイル名が見えるので、元と同じ名前で一時フォルダに置く
                let directory = FileManager.default.temporaryDirectory.appending(path: "Snapsol-\(UUID().uuidString)", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let file = directory.appending(path: entry.fileName)
                try data.write(to: file)
                try clipboard.copyImage(at: file)
                toast.show("注釈付きの画像をコピーしました", detail: nil)
            } catch {
                logger.error("コピーに失敗: \(error)")
            }
        }
    }

    /// 未保存の注釈があれば確認する。false を返すとウィンドウは閉じない
    private func confirmClose(_ session: EditorSession, entry: HistoryEntry, windowID: String) -> Bool {
        guard session.hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "注釈を保存しますか？"
        alert.informativeText = "保存すると、元の画像に注釈が焼き込まれます。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        alert.addButton(withTitle: "保存しない")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            saveAnnotated(session, entry: entry, windowID: windowID) // 保存が終わったら閉じる
            return false
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
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
