import SwiftUI

struct MorningCoachingSection: View {
    let suggestions: [NextUpSuggestion]
    let onConfirm: (NextUpSuggestion) -> Void
    let onDismiss: (NextUpSuggestion) -> Void
    var limitationWarning: LimitationWarning? = nil
    var onDismissWarning: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorschlaege")
                .font(.headline)

            // Limitation Guard Banner
            if let warning = limitationWarning {
                LimitationWarningBanner(warning: warning, onDismiss: { onDismissWarning?() })
            }

            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("morningCoachingSection")
    }

    private func suggestionRow(_ suggestion: NextUpSuggestion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.planItem.title)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    Text(suggestion.slot.startDate, style: .time)
                    Text("–")
                    Text(suggestion.slot.endDate, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let duration = suggestion.planItem.estimatedDuration {
                Text("\(duration) Min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                onConfirm(suggestion)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
            .accessibilityIdentifier("confirmSuggestion_\(suggestion.id)")
            Button {
                onDismiss(suggestion)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .accessibilityIdentifier("dismissSuggestion_\(suggestion.id)")
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggestionRow_\(suggestion.id)")
    }
}
