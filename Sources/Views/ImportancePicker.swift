import SwiftUI

enum ImportancePickerOption: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3

    var displayName: String {
        switch self {
        case .low: return "Niedrig"
        case .medium: return "Mittel"
        case .high: return "Hoch"
        }
    }

    var icon: String {
        switch self {
        case .low: return "🟦"
        case .medium: return "🟨"
        case .high: return "🔴"
        }
    }

    var identifierKey: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }

    var tint: Color {
        switch self {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

struct ImportancePicker: View {
    let currentImportance: Int?
    let onSelect: (Int?) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Wichtigkeit")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(ImportancePickerOption.allCases, id: \.rawValue) { option in
                    Button {
                        onSelect(option.rawValue)
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.icon)
                            Text(option.displayName)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentImportance == option.rawValue ? option.tint : .gray)
                    .accessibilityIdentifier("importance-\(option.identifierKey)")
                }
            }

            Button("Zuruecksetzen") {
                onSelect(nil)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importance-picker")
        .presentationDetents([.height(180)])
    }
}
