import Foundation

protocol ProcessRunning: Sendable {
    /// プロセスを実行し、終了コードを返す。起動に失敗したら throw。
    func run(executable: URL, arguments: [String]) async throws -> Int32
}

/// `waitUntilExit()` でスレッドを塞がず、`terminationHandler` で終了を待つ。
/// Task がキャンセルされたら SIGINT を送る（将来 `screencapture -v` の録画停止にも使える）。
struct ProcessRunner: ProcessRunning {
    func run(executable: URL, arguments: [String]) async throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.interrupt() }
        }
    }
}
