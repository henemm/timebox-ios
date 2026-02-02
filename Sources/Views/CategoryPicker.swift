import SwiftUI

enum CategoryPickerOption: String, CaseIterable {
    case income = "income"
    case maintenance = "maintenance"
    case recharge = "recharge"
    case learning = "learning"
    case givingBack = "giving_back"

    var displayName: String {
        switch self {
        case .income: return "Einkommen"
        case .maintenance: return "Maintenance"
        case .recharge: return "Recharge"
        case .learning: return "Lernen"
        case .givingBack: return "Giving Back"
        }
    }

    var sfSymbol: String {
        switch self {
        case .income: return "dollarsign.circle"
        case .maintenance: return "wrench.and.screwdriver"
        case .recharge: return "battery.100"
        case .learning: return "book"
        case .givingBack: return "gift"
        }
    }

    var tint: Color {
        switch self {
        case .income: return .green
        case .maintenance: return .orange
        case .recharge: return .purple
        case .learning: return .blue
        case .givingBack: return .pink
        }
    }
}

struct CategoryPicker: View {
    let currentCategory: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Kategorie")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CategoryPickerOption.allCases, id: \.rawValue) { option in
                    Button {
                        onSelect(option.rawValue)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: option.sfSymbol)
                                .font(.title3)
                            Text(option.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentCategory == option.rawValue ? option.tint : .gray)
                    .accessibilityIdentifier("category-\(option.rawValue)")
                }
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("category-picker")
        .presentationDetents([.height(220)])
    }
}
