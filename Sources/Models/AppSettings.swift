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

    // MARK: - Task Suggestions

    /// Whether autocomplete and duplicate detection is enabled in CreateTaskView
    @AppStorage("taskSuggestionsEnabled") var taskSuggestionsEnabled: Bool = true

    // MARK: - Day View Settings

    /// Hour when morning phase ends (0-23, default 12)
    @AppStorage("morningEndHour") var morningEndHour: Int = 12

    /// Hour when evening phase starts (0-23, default 18)
    @AppStorage("eveningStartHour") var eveningStartHour: Int = 18

    // MARK: - Evening Reset

    /// ISO-8601 date string of the last successful reset (e.g. "2026-03-25").
    /// Empty string = never reset. Used for idempotency.
    @AppStorage("lastResetDate") var lastResetDate: String = ""

    /// Hour of day at which the reset threshold is crossed (0-23, default 0 = midnight).
    @AppStorage("resetHour") var resetHour: Int = 0

    // MARK: - Success Story Cache

    /// Cached success story text for today (empty = not generated yet)
    @AppStorage("cachedSuccessStory") var cachedSuccessStory: String = ""

    /// ISO-8601 date of the cached story (e.g. "2026-03-26")
    @AppStorage("cachedSuccessStoryDate") var cachedSuccessStoryDate: String = ""

    // MARK: - Notification Time Settings

    @AppStorage("morningReminderHour") var morningReminderHour: Int = 8
    @AppStorage("morningReminderMinute") var morningReminderMinute: Int = 0
    @AppStorage("eveningReflectionHour") var eveningReflectionHour: Int = 20
    @AppStorage("eveningReflectionMinute") var eveningReflectionMinute: Int = 0

    // MARK: - Notification Profile

    @AppStorage("notificationProfile") var notificationProfileRaw: String =
        SmartNotificationEngine.NotificationProfile.balanced.rawValue

    var notificationProfile: SmartNotificationEngine.NotificationProfile {
        get {
            SmartNotificationEngine.NotificationProfile(rawValue: notificationProfileRaw) ?? .balanced
        }
        set {
            notificationProfileRaw = newValue.rawValue
        }
    }

}
