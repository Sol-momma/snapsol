import Foundation

/// `/usr/sbin/screencapture` の引数を組み立てる。
enum ScreencaptureArguments {
    /// - Parameter displayIndex: `-D` に渡す 1 始まりのディスプレイ番号（全画面のときだけ使う）
    static func make(mode: CaptureMode, output: URL, displayIndex: Int) -> [String] {
        let modeArguments: [String] = switch mode {
        case .fullscreen: ["-D", "\(displayIndex)"]
        case .window: ["-w"]
        case .area: ["-s"]
        }
        // -x: シャッター音なし, -t png: 形式指定
        return modeArguments + ["-x", "-t", "png", output.path]
    }
}
