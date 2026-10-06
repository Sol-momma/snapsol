import Foundation
import Observation

/// ユーザー設定。UserDefaults に保存し、SwiftUI の設定画面から直接バインドできるよう @Observable にする
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let afterCapture = "afterCapture"
        static let cardLifetime = "cardLifetime"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var afterCapture: AfterCaptureActions {
        didSet { defaults.set(afterCapture.rawValue, forKey: Key.afterCapture) }
    }

    /// プレビューカードを自動で閉じるまでの秒数。0 なら閉じない
    var cardLifetime: Double {
        didSet { defaults.set(cardLifetime, forKey: Key.cardLifetime) }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        afterCapture = (defaults.object(forKey: Key.afterCapture) as? Int).map(AfterCaptureActions.init) ?? .default
        cardLifetime = defaults.object(forKey: Key.cardLifetime) as? Double ?? 6
    }
}
