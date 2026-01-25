import SwiftUI

struct BacklogRow: View {
    let item: PlanItem
    var onDurationTap: (() -> Void)?
    var onAddToNextUp: (() -> Void)?
    var onTap: (() -> Void)?

    private var importanceIcon: String {
        guard let importance = item.importance else { return "" }
        switch importance {
        case 1: return "🟦"
        case 2: return "🟨"
        case 3: return "🔴"
        default: return ""
        }
    }

    private var urgencyBadgeColor: Color {
        item.urgency == "urgent" ? .red : .gray
    }

    var body: some View {
        HStack(spacing: 8) {
            // Importance Icon
            Text(importanceIcon)
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                // Title (kursiv bei unvollständigen Tasks)
                Text(item.title)
                    .font(.body)
                    .italic(item.isTbd)
                    .lineLimit(2)

                // Tags + Due Date
                HStack(spacing: 6) {
                    // TBD Tag (als erstes, wenn Task unvollständig)
                    if item.isTbd {
                        Text("tbd")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundStyle(.secondary)
                            .cornerRadius(4)
                    }

                    // Tags as chips
                    if !item.tags.isEmpty {
                        ForEach(item.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .cornerRadius(4)
                        }
                        if item.tags.count > 2 {
                            Text("+\(item.tags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Due Date Badge
                    if let dueDate = item.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                            Text(dueDateText(dueDate))
                        }
                        .font(.caption2)
                        .foregroundStyle(isDueToday(dueDate) ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Next Up Button (only show if not already in Next Up)
            if let onAddToNextUp, !item.isNextUp {
                Button {
                    onAddToNextUp()
                } label: {
                    Image(systemName: "arrow.up.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zu Next Up hinzufügen")
            }

            // Duration Badge
            DurationBadge(
                minutes: item.effectiveDuration,
                isDefault: item.durationSource == .default,
                onTap: onDurationTap
            )
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Heute"
        } else if calendar.isDateInTomorrow(date) {
            return "Morgen"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            formatter.locale = Locale(identifier: "de_DE")
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "de_DE")
            return formatter.string(from: date)
        }
    }

    private func isDueToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
