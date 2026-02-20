import Foundation

/// Warning timing options (percentage of block completed)
enum WarningTiming: Int, CaseIterable {
    case short = 90      // "Knapp" - 10% vor Ende
    case standard = 80   // "Standard" - 20% vor Ende
    case early = 70      // "Früh" - 30% vor Ende

    var label: String {
        switch self {
        case .short: return "Kurz vorher"
        case .standard: return "Standard"
        case .early: return "Weit vorher"
        }
    }

    var percentComplete: Double {
        Double(rawValue) / 100.0
    }
}
