import SwiftUI
import SwiftData

struct RefinerTaskCard: View {
    let task: LocalTask
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.title)
                .font(.body.weight(.medium))
                .accessibilityIdentifier("refinerCard_title")

            if hasAnySuggestion {
                suggestionChips
            } else {
                Text("Keine KI-Vorschläge verfügbar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("refinerCard_noSuggestions")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteTask()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            .accessibilityIdentifier("refinerCard_swipeDelete")
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                confirmTask()
            } label: {
                Label("Bestätigen", systemImage: "checkmark")
            }
            .tint(.green)
            .accessibilityIdentifier("refinerCard_swipeConfirm")
        }
        .contextMenu {
            Button("Bestätigen") { confirmTask() }
            Button("Löschen", role: .destructive) { deleteTask() }
        }
    }

    private var hasAnySuggestion: Bool {
        task.suggestedCategory != nil ||
        task.suggestedDuration != nil ||
        task.suggestedImportance != nil ||
        task.suggestedUrgency != nil ||
        task.suggestedEnergyLevel != nil
    }

    private var suggestionChips: some View {
        FlowLayout(spacing: 6) {
            if let cat = task.suggestedCategory {
                SuggestionChip(
                    label: categoryLabel(cat),
                    icon: "tag",
                    accessibilityID: "refinerCard_chip_category"
                )
            }
            if let dur = task.suggestedDuration {
                SuggestionChip(
                    label: "\(dur) Min",
                    icon: "clock",
                    accessibilityID: "refinerCard_chip_duration"
                )
            }
            if let imp = task.suggestedImportance {
                SuggestionChip(
                    label: importanceLabel(imp),
                    icon: "flag",
                    accessibilityID: "refinerCard_chip_importance"
                )
            }
            if let urg = task.suggestedUrgency {
                SuggestionChip(
                    label: urg == "urgent" ? "Dringend" : "Nicht dringend",
                    icon: "bolt",
                    accessibilityID: "refinerCard_chip_urgency"
                )
            }
            if let energy = task.suggestedEnergyLevel {
                SuggestionChip(
                    label: energy == "high" ? "Hohe Energie" : "Niedrige Energie",
                    icon: "brain",
                    accessibilityID: "refinerCard_chip_energy"
                )
            }
        }
    }

    private func confirmTask() {
        task.confirmSuggestions()
        try? modelContext.save()
    }

    private func deleteTask() {
        modelContext.delete(task)
        try? modelContext.save()
    }

    private func categoryLabel(_ raw: String) -> String {
        switch raw {
        case "income":      return "Einnahmen"
        case "maintenance": return "Pflege"
        case "recharge":    return "Erholung"
        case "learning":    return "Lernen"
        case "giving_back": return "Helfen"
        default:            return raw
        }
    }

    private func importanceLabel(_ value: Int) -> String {
        switch value {
        case 1: return "Niedrig"
        case 2: return "Mittel"
        case 3: return "Hoch"
        default: return "\(value)"
        }
    }
}

struct SuggestionChip: View {
    let label: String
    let icon: String
    let accessibilityID: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.blue.opacity(0.12), in: Capsule())
            .foregroundStyle(.blue)
            .accessibilityIdentifier(accessibilityID)
    }
}
