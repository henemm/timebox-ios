import SwiftUI

/// Training disciplines for task classification.
/// Describes which type of resistance a task represents.
enum Discipline: String, CaseIterable, Codable {
    case konsequenz
    case ausdauer
    case mut
    case fokus

    var displayName: String {
        switch self {
        case .konsequenz: "Konsequenz"
        case .ausdauer: "Ausdauer"
        case .mut: "Mut"
        case .fokus: "Fokus"
        }
    }

    var icon: String {
        switch self {
        case .konsequenz: "arrow.trianglehead.counterclockwise"
        case .ausdauer: "figure.walk"
        case .mut: "flame"
        case .fokus: "scope"
        }
    }

    var color: Color {
        switch self {
        case .konsequenz: .green
        case .ausdauer: .gray
        case .mut: .red
        case .fokus: .blue
        }
    }

    /// Resolve discipline for an open task, respecting manual override.
    /// Override takes precedence; falls back to classifyOpen() if nil or invalid.
    static func resolveOpen(
        manualDiscipline: String?,
        rescheduleCount: Int,
        importance: Int?
    ) -> Discipline {
        if let manual = manualDiscipline,
           let discipline = Discipline(rawValue: manual) {
            return discipline
        }
        return classifyOpen(rescheduleCount: rescheduleCount, importance: importance)
    }

    /// Classify an open (not yet completed) task into a discipline.
    /// Simplified variant without duration — fokus is not determinable for open tasks.
    /// Priority: konsequenz (procrastinated) > mut (high importance) > ausdauer (default)
    static func classifyOpen(rescheduleCount: Int, importance: Int?) -> Discipline {
        if rescheduleCount >= 2 {
            return .konsequenz
        }
        if importance == 3 {
            return .mut
        }
        return .ausdauer
    }

    /// Classify a completed task into a discipline based on simple heuristics.
    /// Priority: konsequenz (procrastinated) > mut (high importance) > fokus (within estimate) > ausdauer (default)
    static func classify(
        rescheduleCount: Int,
        importance: Int?,
        effectiveDuration: Int,
        estimatedDuration: Int?
    ) -> Discipline {
        if rescheduleCount >= 2 {
            return .konsequenz
        }
        if importance == 3 {
            return .mut
        }
        if let estimated = estimatedDuration, effectiveDuration <= estimated {
            return .fokus
        }
        return .ausdauer
    }
}
