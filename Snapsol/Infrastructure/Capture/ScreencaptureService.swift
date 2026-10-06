import Foundation

struct ScreencaptureService: ScreenCapturing {
    static let executable = URL(filePath: "/usr/sbin/screencapture")

    let runner: any ProcessRunning
    let temporaryDirectory: URL
    let displayIndex: @MainActor @Sendable () -> Int

    func capture(_ mode: CaptureMode) async throws -> URL? {
        let output = temporaryDirectory.appending(path: "Snapsol-\(UUID().uuidString).png")
        let arguments = ScreencaptureArguments.make(mode: mode, output: output, displayIndex: await displayIndex())
        let status = try await runner.run(executable: Self.executable, arguments: arguments)

        // Esc でキャンセルするとファイルが作られない。終了コードとファイル有無の両方で判定する
        guard status == 0, FileManager.default.fileExists(atPath: output.path) else {
            try? FileManager.default.removeItem(at: output)
            return nil
        }
        return output
    }
}
