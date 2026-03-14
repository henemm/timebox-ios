import AppIntents

/// AppEnum for Siri parameter — maps to CoachType model enum.
enum CoachTypeEnum: String, AppEnum, CaseIterable {
    case troll
    case feuer
    case eule
    case golem

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Coach")

    static let caseDisplayRepresentations: [CoachTypeEnum: DisplayRepresentation] = [
        .troll: "Troll — Der Aufräumer",
        .feuer: "Feuer — Der Herausforderer",
        .eule: "Eule — Der Fokussierer",
        .golem: "Golem — Der Balancer"
    ]

    var asCoachType: CoachType {
        CoachType(rawValue: rawValue)!
    }
}
