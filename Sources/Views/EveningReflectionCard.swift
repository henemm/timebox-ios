import SwiftUI

/// Evening reflection card shown in the Review tab after 18:00 (Phase 3c).
/// Displays fulfillment level per selected intention with fallback template text.
struct EveningReflectionCard: View {
    let intentions: [IntentionOption]
    let tasks: [LocalTask]
    let focusBlocks: [FocusBlock]
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dein Abend-Spiegel")
                .font(.headline)

            ForEach(intentions, id: \.self) { intention in
                intentionRow(intention)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .accessibilityIdentifier("eveningReflectionCard")
        .accessibilityElement(children: .contain)
    }

    // MARK: - Intention Row

    @ViewBuilder
    private func intentionRow(_ intention: IntentionOption) -> some View {
        let level = IntentionEvaluationService.evaluateFulfillment(
            intention: intention, tasks: tasks, focusBlocks: focusBlocks, now: now
        )
        let template = IntentionEvaluationService.fallbackTemplate(
            intention: intention, level: level
        )

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: intention.icon)
                    .foregroundStyle(intention.color)
                Text(intention.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                fulfillmentBadge(level, intention: intention)
            }

            if !template.isEmpty {
                Text(template)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("reflectionText_\(intention.rawValue)")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor(for: level, intention: intention))
        )
        .accessibilityIdentifier("eveningResult_\(intention.rawValue)")
        .accessibilityElement(children: .contain)
    }

    // MARK: - Badge

    @ViewBuilder
    private func fulfillmentBadge(_ level: FulfillmentLevel, intention: IntentionOption) -> some View {
        let (icon, color) = badgeAttributes(level, intention: intention)
        Image(systemName: icon)
            .foregroundStyle(color)
            .font(.title3)
            .accessibilityIdentifier("fulfillmentBadge_\(intention.rawValue)")
    }

    private func badgeAttributes(_ level: FulfillmentLevel, intention: IntentionOption) -> (String, Color) {
        switch level {
        case .fulfilled:    return ("checkmark.circle.fill", intention.color)
        case .partial:      return ("exclamationmark.circle.fill", intention.color.opacity(0.6))
        case .notFulfilled: return ("xmark.circle", .secondary)
        }
    }

    // MARK: - Colors

    private func backgroundColor(for level: FulfillmentLevel, intention: IntentionOption) -> Color {
        switch level {
        case .fulfilled:    return intention.color.opacity(0.15)
        case .partial:      return intention.color.opacity(0.08)
        case .notFulfilled: return Color.secondary.opacity(0.08)
        }
    }
}
