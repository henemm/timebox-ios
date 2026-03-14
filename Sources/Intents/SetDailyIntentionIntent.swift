import AppIntents

/// Siri intent: "Wähle Troll als Coach" — sets the daily coach.
struct SetDailyIntentionIntent: AppIntent {
    static let title: LocalizedStringResource = "Coach wählen"
    static let description = IntentDescription("Wählt deinen Tages-Coach.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Coach")
    var coach: CoachTypeEnum

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coachType = coach.asCoachType
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        var selection = DailyCoachSelection(date: dateString, coach: coachType)
        selection.save()

        return .result(dialog: "\(coachType.displayName) als Coach gewählt. Los geht's!")
    }
}
