import AppIntents

/// Siri intent: "Setz meine Intention auf Fokus" — sets the daily intention.
struct SetDailyIntentionIntent: AppIntent {
    static let title: LocalizedStringResource = "Intention setzen"
    static let description = IntentDescription("Setzt deine Tages-Intention.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Intention")
    var intention: IntentionOptionEnum

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let option = intention.asIntentionOption
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        var daily = DailyIntention(date: dateString, selections: [option])
        daily.save()

        return .result(dialog: "Intention auf \(option.label) gesetzt. Viel Erfolg heute!")
    }
}
