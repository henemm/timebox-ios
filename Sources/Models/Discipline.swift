import SwiftUI

/// Training disciplines for the Monster Coach system.
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
