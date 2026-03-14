import SwiftUI

/// Evening reflection card shown in the Review tab after 18:00.
/// Displays fulfillment level for the selected coach with reflection text.
struct EveningReflectionCard: View {
    let coach: CoachType
    let tasks: [LocalTask]
    let focusBlocks: [FocusBlock]
    var aiText: String?
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dein Abend-Spiegel")
                .font(.headline)

            coachRow
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .accessibilityIdentifier("eveningReflectionCard")
        .accessibilityElement(children: .contain)
    }

    // MARK: - Coach Row

    private var coachRow: some View {
        let level = IntentionEvaluationService.evaluateFulfillment(
            coach: coach, tasks: tasks, focusBlocks: focusBlocks, now: now
        )
        let template = aiText
            ?? IntentionEvaluationService.fallbackTemplate(coach: coach, level: level)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(coach.monsterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityLabel(coach.displayName)
                    .accessibilityIdentifier("monsterIcon_\(coach.rawValue)")
                Text("\(coach.displayName) — \(coach.subtitle)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                fulfillmentBadge(level)
            }

            if !template.isEmpty {
                Text(template)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("reflectionText_\(coach.rawValue)")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor(for: level))
        )
        .accessibilityIdentifier("eveningResult_\(coach.rawValue)")
    }

    // MARK: - Badge

    private func fulfillmentBadge(_ level: FulfillmentLevel) -> some View {
        let (icon, color) = badgeAttributes(level)
        return Image(systemName: icon)
            .foregroundStyle(color)
            .font(.title3)
            .accessibilityIdentifier("fulfillmentBadge_\(coach.rawValue)")
    }

    private func badgeAttributes(_ level: FulfillmentLevel) -> (String, Color) {
        switch level {
        case .fulfilled:    return ("checkmark.circle.fill", coach.color)
        case .partial:      return ("exclamationmark.circle.fill", coach.color.opacity(0.6))
        case .notFulfilled: return ("xmark.circle", .secondary)
        }
    }

    // MARK: - Colors

    private func backgroundColor(for level: FulfillmentLevel) -> Color {
        switch level {
        case .fulfilled:    return coach.color.opacity(0.15)
        case .partial:      return coach.color.opacity(0.08)
        case .notFulfilled: return Color.secondary.opacity(0.08)
        }
    }
}
