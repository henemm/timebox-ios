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

    // MARK: - Monster Coach

    /// Whether Monster Coach mode is enabled
    @AppStorage("coachModeEnabled") var coachModeEnabled: Bool = false

    /// Whether morning intention reminder is enabled
    @AppStorage("coachIntentionReminderEnabled") var coachIntentionReminderEnabled: Bool = true

    /// Hour for morning intention reminder (0-23)
    @AppStorage("coachIntentionReminderHour") var coachIntentionReminderHour: Int = 7

    /// Minute for morning intention reminder (0-59)
    @AppStorage("coachIntentionReminderMinute") var coachIntentionReminderMinute: Int = 0

    /// Whether daily intention nudge notifications are enabled
    @AppStorage("coachDailyNudgesEnabled") var coachDailyNudgesEnabled: Bool = true

    /// Maximum number of daily nudge notifications (1, 2 or 3)
    @AppStorage("coachDailyNudgesMaxCount") var coachDailyNudgesMaxCount: Int = 2

    /// Hour for nudge window start (0-23)
    @AppStorage("coachNudgeWindowStartHour") var coachNudgeWindowStartHour: Int = 10

    /// Hour for nudge window end (0-23)
    @AppStorage("coachNudgeWindowEndHour") var coachNudgeWindowEndHour: Int = 18
}
