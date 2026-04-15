import SwiftUI

struct MorningCoachingSection: View {
    let suggestions: [NextUpSuggestion]
    let onConfirm: (NextUpSuggestion) -> Void
    let onDismiss: (NextUpSuggestion) -> Void
    var aiReasonTexts: [String: String] = [:]
    var limitationWarning: LimitationWarning? = nil
    var onDismissWarning: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vorschläge für heute")
                .font(.headline)

            ForEach(suggestions) { suggestion in
                VStack(alignment: .leading, spacing: 4) {
                    suggestionTaskRow(suggestion.planItem)

                    Text(aiReasonTexts[suggestion.id] ?? NextUpSuggestionService.reasonText(for: suggestion.planItem))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.leading, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        onConfirm(suggestion)
                    } label: {
                        Label("Heute", systemImage: "calendar.badge.plus")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        onDismiss(suggestion)
                    } label: {
                        Label("Entfernen", systemImage: "eye.slash")
                    }
                    .tint(.orange)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suggestionRow_\(suggestion.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("morningCoachingSection")
    }

    private func suggestionTaskRow(_ item: PlanItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let cat = TaskCategory(rawValue: item.taskType) {
                        Label(cat.localizedName, systemImage: cat.icon)
                            .font(.caption2)
                            .foregroundStyle(cat.color)
                    }
                    if let duration = item.estimatedDuration {
                        Text("\(duration) Min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let due = item.dueDate {
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if item.importance == 3 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
