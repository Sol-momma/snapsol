import Foundation
import Testing

/// 実際の screencapture は起動せず、終了コードと「ファイルを作るか」を差し替える
private struct FakeRunner: ProcessRunning {
    var status: Int32 = 0
    var createsFile = true
    var error: (any Error)?

    func run(executable: URL, arguments: [String]) async throws -> Int32 {
        if let error { throw error }
        if createsFile, let path = arguments.last {
            FileManager.default.createFile(atPath: path, contents: Data([0x89]))
        }
        return status
    }
}

private struct LaunchFailed: Error {}

struct ScreencaptureServiceTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ScreencaptureServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func service(_ runner: FakeRunner) -> ScreencaptureService {
        ScreencaptureService(runner: runner, temporaryDirectory: directory, displayIndex: { 1 })
    }

    private func filesInDirectory() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path)
    }

    @Test func 成功するとファイルのURLを返す() async throws {
        let url = try #require(try await service(FakeRunner()).capture(.area))
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
    }

    @Test func Escでキャンセルしファイルが無ければnil() async throws {
        let url = try await service(FakeRunner(createsFile: false)).capture(.area)
        #expect(url == nil)
    }

    @Test func 異常終了ならnilでファイルも残さない() async throws {
        let url = try await service(FakeRunner(status: 1)).capture(.window)
        #expect(url == nil)
        #expect(try filesInDirectory().isEmpty)
    }

    @Test func 起動失敗はthrowする() async {
        await #expect(throws: LaunchFailed.self) {
            try await service(FakeRunner(error: LaunchFailed())).capture(.fullscreen)
        }
    }
}
