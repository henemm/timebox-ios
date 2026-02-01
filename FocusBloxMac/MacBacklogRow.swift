//
//  MacBacklogRow.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

/// Compact task row optimized for macOS list display
/// Aligned with iOS BacklogRow styling and functionality
struct MacBacklogRow: View {
    let task: LocalTask
    var onToggleComplete: (() -> Void)?
    var onImportanceCycle: ((Int) -> Void)?
    var onUrgencyToggle: ((String?) -> Void)?
    var onCategoryTap: (() -> Void)?
    var onDurationTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Completion Toggle
            Button {
                onToggleComplete?()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("completeButton_\(task.id)")

            // Title + Metadata
            VStack(alignment: .leading, spacing: 4) {
                // Title (italic if TBD)
                Text(task.title)
                    .lineLimit(1)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : (task.isTbd ? .secondary : .primary))
                    .italic(task.isTbd)

                // Metadata Row (aligned with iOS)
                metadataRow
            }

            Spacer()

            // TBD Indicator
            if task.isTbd {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
            }

            // Next Up Indicator
            if task.isNextUp {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Metadata Row (iOS-aligned)

    private var metadataRow: some View {
        HStack(spacing: 6) {
            // 1. Importance Badge (tappable, cycles 1 → 2 → 3 → 1)
            importanceBadge

            // 2. Urgency Badge (tappable)
            urgencyBadge

            // 3. Category Badge (tappable)
            categoryBadge

            // 4. Duration Badge
            durationBadge

            // 5. Due Date Badge
            if let dueDate = task.dueDate {
                dueDateBadge(dueDate)
            }
        }
    }

    // MARK: - Importance Badge (iOS-aligned)

    private var importanceBadge: some View {
        Button {
            let current = task.importance ?? 0
            let next = current >= 3 ? 1 : current + 1
            onImportanceCycle?(next)
        } label: {
            Image(systemName: importanceSFSymbol)
                .font(.system(size: 12))
                .foregroundStyle(importanceColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(importanceColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("importanceBadge_\(task.id)")
    }

    private var importanceSFSymbol: String {
        switch task.importance {
        case 3: return "exclamationmark.3"
        case 2: return "exclamationmark.2"
        case 1: return "exclamationmark"
        default: return "questionmark"
        }
    }

    private var importanceColor: Color {
        switch task.importance {
        case 3: return .red
        case 2: return .yellow
        case 1: return .blue
        default: return .gray
        }
    }

    // MARK: - Urgency Badge (iOS-aligned)

    private var urgencyBadge: some View {
        Button {
            // Cycle: nil → not_urgent → urgent → nil
            let newUrgency: String?
            switch task.urgency {
            case nil: newUrgency = "not_urgent"
            case "not_urgent": newUrgency = "urgent"
            case "urgent": newUrgency = nil
            default: newUrgency = nil
            }
            onUrgencyToggle?(newUrgency)
        } label: {
            Image(systemName: urgencyIcon)
                .font(.system(size: 12))
                .foregroundStyle(urgencyColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(urgencyColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("urgencyBadge_\(task.id)")
    }

    private var urgencyIcon: String {
        switch task.urgency {
        case "urgent": return "flame.fill"
        case "not_urgent": return "flame"
        default: return "questionmark"
        }
    }

    private var urgencyColor: Color {
        switch task.urgency {
        case "urgent": return .orange
        case "not_urgent": return .gray
        default: return .gray
        }
    }

    // MARK: - Category Badge (iOS-aligned, all 10 categories)

    private var categoryBadge: some View {
        Button {
            onCategoryTap?()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: categoryIcon)
                Text(categoryLabel)
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(categoryColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(categoryColor.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("categoryBadge_\(task.id)")
    }

    private var categoryColor: Color {
        switch task.taskType {
        case "income": return .green
        case "maintenance": return .orange
        case "recharge": return .cyan
        case "learning": return .purple
        case "giving_back": return .pink
        default: return .gray
        }
    }

    private var categoryIcon: String {
        switch task.taskType {
        case "income": return "dollarsign.circle"
        case "maintenance": return "wrench.and.screwdriver.fill"
        case "recharge": return "battery.100"
        case "learning": return "book"
        case "giving_back": return "gift"
        default: return "questionmark.circle"
        }
    }

    private var categoryLabel: String {
        switch task.taskType {
        case "income": return "Geld"
        case "maintenance": return "Pflege"
        case "recharge": return "Energie"
        case "learning": return "Lernen"
        case "giving_back": return "Geben"
        default: return "Typ"
        }
    }

    // MARK: - Duration Badge (iOS-aligned)

    private var isDurationSet: Bool {
        task.estimatedDuration != nil
    }

    private var durationBadge: some View {
        Button {
            onDurationTap?()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: isDurationSet ? "timer" : "questionmark")
                if let duration = task.estimatedDuration {
                    Text("\(duration)m")
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(isDurationSet ? .blue : .gray)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill((isDurationSet ? Color.blue : Color.gray).opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("durationBadge_\(task.id)")
    }

    // MARK: - Due Date Badge

    private func dueDateBadge(_ date: Date) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
            Text(dueDateText(date))
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(isDueToday(date) ? .red : .secondary)
        .fixedSize()
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

// MARK: - Category Badge (standalone for reuse in other views)

struct CategoryBadge: View {
    let taskType: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(label)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(0.2))
        )
        .fixedSize()
    }

    private var color: Color {
        switch taskType {
        case "income": return .green
        case "maintenance": return .orange
        case "recharge": return .cyan
        case "learning": return .purple
        case "giving_back": return .pink
        default: return .gray
        }
    }

    private var icon: String {
        switch taskType {
        case "income": return "dollarsign.circle"
        case "maintenance": return "wrench.and.screwdriver.fill"
        case "recharge": return "battery.100"
        case "learning": return "book"
        case "giving_back": return "gift"
        default: return "questionmark.circle"
        }
    }

    private var label: String {
        switch taskType {
        case "income": return "Geld"
        case "maintenance": return "Pflege"
        case "recharge": return "Energie"
        case "learning": return "Lernen"
        case "giving_back": return "Geben"
        default: return "Typ"
        }
    }
}

#Preview {
    List {
        MacBacklogRow(task: LocalTask(title: "Sample Task", importance: 3))
        MacBacklogRow(task: LocalTask(title: "Another Task", estimatedDuration: 30))
    }
    .frame(width: 500)
}
