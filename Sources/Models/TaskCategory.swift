import SwiftUI

/// Central source of truth for task category display properties.
/// Raw values match the strings stored in LocalTask.taskType for data compatibility.
enum TaskCategory: String, CaseIterable {
    case income = "income"
    case essentials = "maintenance"
    case selfCare = "recharge"
    case learn = "learning"
    case social = "giving_back"

    var displayName: String {
        switch self {
        case .income: "Earn"
        case .essentials: "Essentials"
        case .selfCare: "Self Care"
        case .learn: "Learn"
        case .social: "Social"
        }
    }

    var icon: String {
        switch self {
        case .income: "dollarsign.circle"
        case .essentials: "wrench.and.screwdriver.fill"
        case .selfCare: "heart.circle"
        case .learn: "book"
        case .social: "person.2"
        }
    }

    var color: Color {
        switch self {
        case .income: .green
        case .essentials: .orange
        case .selfCare: .cyan
        case .learn: .purple
        case .social: .pink
        }
    }
}
