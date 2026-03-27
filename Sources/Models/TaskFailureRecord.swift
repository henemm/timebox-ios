import Foundation
import SwiftData

/// Grund warum ein Task nicht erledigt wurde.
/// Als String gespeichert fuer CloudKit-Kompatibilitaet.
enum FailureReason: String, Codable, CaseIterable {
    case noTime
    case tooTired
    case blocked
    case notRelevant
    case forgotAboutIt
    case other

    var displayName: String {
        switch self {
        case .noTime:        "Keine Zeit"
        case .tooTired:      "Zu muede"
        case .blocked:       "Blockiert"
        case .notRelevant:   "Nicht relevant"
        case .forgotAboutIt: "Vergessen"
        case .other:         "Anderes"
        }
    }

    var systemImage: String {
        switch self {
        case .noTime:        "clock"
        case .tooTired:      "battery.25percent"
        case .blocked:       "xmark.octagon"
        case .notRelevant:   "arrow.uturn.backward"
        case .forgotAboutIt: "questionmark.circle"
        case .other:         "ellipsis.circle"
        }
    }
}

@Model
final class TaskFailureRecord {
    #Index<TaskFailureRecord>([\.date], [\.reasonRaw])

    var taskID: String = ""
    var date: Date = Date()
    var reasonRaw: String = FailureReason.other.rawValue

    var reason: FailureReason {
        get { FailureReason(rawValue: reasonRaw) ?? .other }
        set { reasonRaw = newValue.rawValue }
    }

    init(taskID: String, date: Date, reason: FailureReason) {
        self.taskID = taskID
        self.date = date
        self.reasonRaw = reason.rawValue
    }
}
