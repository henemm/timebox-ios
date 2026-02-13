import SwiftUI
@preconcurrency import Combine

/// App-wide settings stored in UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    /// Shared singleton instance
    static let shared = AppSettings()

    /// Whether sound is enabled for block-end notifications
    @AppStorage("soundEnabled") var soundEnabled: Bool = true

    // MARK: - Warning Settings

    /// Whether warning sound/haptic is enabled before block end
    @AppStorage("warningEnabled") var warningEnabled: Bool = true

    /// Raw value for warning timing (use warningTiming computed property)
    @AppStorage("warningTiming") var warningTimingRaw: Int = WarningTiming.standard.rawValue

    /// Warning timing setting
    var warningTiming: WarningTiming {
        get { WarningTiming(rawValue: warningTimingRaw) ?? .standard }
        set { warningTimingRaw = newValue.rawValue }
    }

    // MARK: - Task Settings

    /// Default duration for new tasks in minutes
    @AppStorage("defaultTaskDuration") var defaultTaskDuration: Int = 15
}
