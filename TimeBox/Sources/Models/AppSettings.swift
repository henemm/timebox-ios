import SwiftUI

/// App-wide settings stored in UserDefaults
@MainActor
class AppSettings: ObservableObject {
    /// Shared singleton instance
    static let shared = AppSettings()

    /// Whether sound is enabled for block-end notifications
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
}
