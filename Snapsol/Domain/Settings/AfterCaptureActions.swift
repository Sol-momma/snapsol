/// 撮影直後に自動で行うこと。複数を組み合わせられる
struct AfterCaptureActions: OptionSet, Sendable {
    let rawValue: Int

    static let showCard = AfterCaptureActions(rawValue: 1 << 0)
    static let copyToClipboard = AfterCaptureActions(rawValue: 1 << 1)
    static let openEditor = AfterCaptureActions(rawValue: 1 << 2)

    static let `default`: AfterCaptureActions = [.showCard]
}
