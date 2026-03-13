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
        .survival: "Tag ueberleben",
        .fokus: "Fokus",
        .bhag: "Das grosse Ding",
        .balance: "Balance",
        .growth: "Lernen",
        .connection: "Fuer andere"
    ]

    var asIntentionOption: IntentionOption {
        IntentionOption(rawValue: rawValue)!
    }
}
