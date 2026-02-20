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

    // MARK: - Due Date Notifications

    /// Whether morning reminder on due date day is enabled
    @AppStorage("dueDateMorningReminderEnabled") var dueDateMorningReminderEnabled: Bool = true

    /// Hour for morning reminder (0-23)
    @AppStorage("dueDateMorningReminderHour") var dueDateMorningReminderHour: Int = 9

    /// Minute for morning reminder (0-59)
    @AppStorage("dueDateMorningReminderMinute") var dueDateMorningReminderMinute: Int = 0

    /// Whether advance reminder before due date is enabled
    @AppStorage("dueDateAdvanceReminderEnabled") var dueDateAdvanceReminderEnabled: Bool = false

    /// Minutes before due date for advance reminder
    @AppStorage("dueDateAdvanceReminderMinutes") var dueDateAdvanceReminderMinutes: Int = 60

    // MARK: - AI Task Scoring (Apple Intelligence)

    /// Whether AI-powered task scoring is enabled
    @AppStorage("aiScoringEnabled") var aiScoringEnabled: Bool = true
}
