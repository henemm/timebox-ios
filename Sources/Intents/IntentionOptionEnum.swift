import AppIntents

/// AppEnum for Siri parameter — maps to IntentionOption model enum.
enum IntentionOptionEnum: String, AppEnum, CaseIterable {
    case survival
    case fokus
    case bhag
    case balance
    case growth
    case connection

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intention")

    static let caseDisplayRepresentations: [IntentionOptionEnum: DisplayRepresentation] = [
        .survival: "Tag überleben",
        .fokus: "Nicht verzetteln",
        .bhag: "Das große Ding",
        .balance: "Balance",
        .growth: "Etwas lernen",
        .connection: "Für andere da sein"
    ]

    var asIntentionOption: IntentionOption {
        IntentionOption(rawValue: rawValue)!
    }
}
