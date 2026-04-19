import SwiftUI

// MARK: - Platform-specific Badge Sizing

#if os(iOS)
private let badgeIconFont: CGFloat = 14
private let badgePaddingH: CGFloat = 6
private let badgePaddingV: CGFloat = 4
private let badgeCornerRadius: CGFloat = 6
private let badgeSpacing: CGFloat = 4
#else
private let badgeIconFont: CGFloat = 12
private let badgePaddingH: CGFloat = 5
private let badgePaddingV: CGFloat = 3
private let badgeCornerRadius: CGFloat = 5
private let badgeSpacing: CGFloat = 3
#endif

// MARK: - ImportanceBadge

struct ImportanceBadge: View {
    let importance: Int?
    let taskId: String
    var onCycle: ((Int) -> Void)?

    static func nextImportance(current: Int?) -> Int {
        let value = current ?? 0
        return value >= 3 ? 1 : value + 1
    }

    var body: some View {
        Button {
            onCycle?(Self.nextImportance(current: importance))
        } label: {
            Image(systemName: ImportanceUI.icon(for: importance))
                .font(.system(size: badgeIconFont))
                .foregroundStyle(ImportanceUI.color(for: importance))
                .padding(.horizontal, badgePaddingH)
                .padding(.vertical, badgePaddingV)
                .background(
                    RoundedRectangle(cornerRadius: badgeCornerRadius)
                        .fill(ImportanceUI.color(for: importance).opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        #if os(iOS)
        .sensoryFeedback(.impact(weight: .light), trigger: importance)
        .accessibilityLabel("Wichtigkeit: \(ImportanceUI.label(for: importance)). Tippen zum Ändern.")
        #endif
        .accessibilityIdentifier("importanceBadge_\(taskId)")
    }
}

// MARK: - UrgencyBadge

struct UrgencyBadge: View {
    let urgency: String?
    let taskId: String
    var onToggle: ((String?) -> Void)?

    static func nextUrgency(current: String?) -> String? {
        switch current {
        case nil: return "not_urgent"
        case "not_urgent": return "urgent"
        case "urgent": return nil
        default: return nil
        }
    }

    var body: some View {
        Button {
            onToggle?(Self.nextUrgency(current: urgency))
        } label: {
            Image(systemName: UrgencyUI.icon(for: urgency))
                .font(.system(size: badgeIconFont))
                .foregroundStyle(UrgencyUI.color(for: urgency))
                .padding(.horizontal, badgePaddingH)
                .padding(.vertical, badgePaddingV)
                .background(
                    RoundedRectangle(cornerRadius: badgeCornerRadius)
                        .fill(UrgencyUI.color(for: urgency).opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        #if os(iOS)
        .sensoryFeedback(.impact(weight: .medium), trigger: urgency)
        .accessibilityLabel(urgencyAccessibilityLabel)
        #endif
        .accessibilityIdentifier("urgencyBadge_\(taskId)")
    }

    private var urgencyAccessibilityLabel: String {
        switch urgency {
        case "urgent": "Dringend. Tippen zum Entfernen."
        case "not_urgent": "Nicht dringend. Tippen für Dringend."
        default: "Dringlichkeit nicht gesetzt. Tippen zum Setzen."
        }
    }
}

// MARK: - RecurrenceBadge

struct RecurrenceBadge: View {
    let pattern: String
    let taskId: String

    var body: some View {
        HStack(spacing: badgeSpacing) {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text(RecurrencePattern(rawValue: pattern)?.displayName ?? pattern)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.purple)
        .padding(.horizontal, badgePaddingH)
        .padding(.vertical, badgePaddingV)
        .background(
            RoundedRectangle(cornerRadius: badgeCornerRadius)
                .fill(.purple.opacity(0.2))
        )
        .fixedSize()
        .accessibilityIdentifier("recurrenceBadge_\(taskId)")
    }
}

// MARK: - TagsBadge

struct TagsBadge: View {
    let tags: [String]
    let taskId: String

    var body: some View {
        ForEach(Array(tags.prefix(2).enumerated()), id: \.offset) { index, tag in
            Text(tag)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
                .fixedSize()
                .accessibilityIdentifier("tag_\(taskId)_\(index)")
        }

        if tags.count > 2 {
            Text("+\(tags.count - 2)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
                .fixedSize()
                .accessibilityIdentifier("tagOverflow_\(taskId)")
        }
    }
}

// MARK: - DueDateBadge

struct DueDateBadge: View {
    let date: Date
    let taskId: String

    var body: some View {
        HStack(spacing: badgeSpacing) {
            Image(systemName: "calendar")
            Text(date.dueDateText())
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle((date.isDueToday || date.isOverdue) ? .red : .secondary)
        .fixedSize()
        .accessibilityIdentifier("dueDateBadge_\(taskId)")
    }
}

// MARK: - StackingBadge

struct StackingBadge: View {
    let count: Int
    let taskId: String

    var body: some View {
        Text("x\(count)")
            .font(.caption2.weight(count >= 2 ? .bold : .regular))
            .foregroundStyle(count >= 2 ? .orange : .secondary)
            .padding(.horizontal, badgePaddingH)
            .padding(.vertical, badgePaddingV)
            .background(
                Capsule()
                    .fill(count >= 2 ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.15))
            )
            .accessibilityIdentifier("stackingBadge_\(taskId)")
            .accessibilityLabel("\(count) aufgelaufene Instanzen")
    }
}

// MARK: - CategoryDisplayLabel

struct CategoryDisplayLabel: View {
    let taskType: String

    var body: some View {
        HStack(spacing: badgeSpacing) {
            Image(systemName: icon)
            Text(label)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, badgePaddingH)
        .padding(.vertical, badgePaddingV)
        .background(
            RoundedRectangle(cornerRadius: badgeCornerRadius)
                .fill(color.opacity(0.2))
        )
    }

    private var color: Color {
        TaskCategory(rawValue: taskType)?.color ?? .gray
    }

    private var icon: String {
        TaskCategory(rawValue: taskType)?.icon ?? "questionmark.circle"
    }

    private var label: String {
        TaskCategory(rawValue: taskType)?.displayName ?? taskType.capitalized
    }
}

// MARK: - DurationDisplayLabel

struct DurationDisplayLabel: View {
    let duration: Int?

    private var isDurationSet: Bool { duration != nil }

    var body: some View {
        HStack(spacing: badgeSpacing) {
            Image(systemName: isDurationSet ? "timer" : "questionmark")
            if let duration {
                Text("\(duration)m")
                    .lineLimit(1)
            }
        }
        .font(.caption2)
        .foregroundStyle(isDurationSet ? .blue : .gray)
        .padding(.horizontal, badgePaddingH)
        .padding(.vertical, badgePaddingV)
        .background(
            Capsule()
                .fill((isDurationSet ? Color.blue : Color.gray).opacity(0.2))
        )
    }
}

// MARK: - PriorityScoreBadge

struct PriorityScoreBadge: View {
    let score: Int
    let tier: TaskPriorityScoringService.PriorityTier
    let taskId: String

    static func color(for tier: TaskPriorityScoringService.PriorityTier) -> Color {
        switch tier {
        case .doNow: .red
        case .planSoon: .orange
        case .eventually: .yellow
        case .someday: .gray
        }
    }

    var body: some View {
        let badgeColor = Self.color(for: tier)
        HStack(spacing: 2) {
            Image(systemName: "chart.bar.fill")
            Text("\(score)")
        }
        .font(.caption2)
        .foregroundStyle(badgeColor)
        .padding(.horizontal, badgePaddingH)
        .padding(.vertical, badgePaddingV - 1)
        .background(
            RoundedRectangle(cornerRadius: badgeCornerRadius)
                .fill(badgeColor.opacity(0.2))
        )
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("priorityScoreBadge_\(taskId)")
        .accessibilityLabel("\(score)")
    }
}
