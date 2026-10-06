import AppKit

/// 画面収録（TCC）の権限。許可がないと screencapture は壁紙だけの画像を撮ってしまう
@MainActor
enum ScreenCapturePermission {
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 初回だけシステムの許可ダイアログを出す（2 回目以降は何も表示されない）
    static func request() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}
