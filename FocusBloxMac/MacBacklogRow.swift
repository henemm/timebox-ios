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
    var onCategorySelect: ((String) -> Void)?  // Direct category selection (macOS Menu)
    var onDurationSelect: ((Int?) -> Void)?    // Direct duration selection (macOS Menu)

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

            // 4. Recurrence Badge (only if recurring, iOS-aligned)
            if task.recurrencePattern != "none" {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(recurrenceDisplayName(task.recurrencePattern))
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.purple)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.purple.opacity(0.2))
                )
                .fixedSize()
                .accessibilityIdentifier("recurrenceBadge_\(task.id)")
            }

            // 5. Tags (max 2, dann "+N") - plain text, iOS-aligned
            if !task.tags.isEmpty {
                ForEach(Array(task.tags.prefix(2).enumerated()), id: \.offset) { index, tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .accessibilityIdentifier("tag_\(task.id)_\(index)")
                }

                if task.tags.count > 2 {
                    Text("+\(task.tags.count - 2)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .accessibilityIdentifier("tagOverflow_\(task.id)")
                }
            }

            // 5. Duration Badge
            durationBadge

            // 6. AI Score Badge (only when scored)
            if task.hasAIScoring {
                HStack(spacing: 2) {
                    Image(systemName: "wand.and.stars")
                    Text("\(task.aiScore ?? 0)")
                }
                .font(.caption2)
                .foregroundStyle(.purple.opacity(0.7))
                .fixedSize()
                .accessibilityIdentifier("aiScoreBadge_\(task.id)")
            }

            // 7. Due Date Badge
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
        ImportanceUI.icon(for: task.importance)
    }

    private var importanceColor: Color {
        ImportanceUI.color(for: task.importance)
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
        UrgencyUI.icon(for: task.urgency)
    }

    private var urgencyColor: Color {
        UrgencyUI.color(for: task.urgency)
    }

    // MARK: - Category Badge (macOS Menu Picker)

    private var categoryBadge: some View {
        Menu {
            ForEach(TaskCategory.allCases, id: \.rawValue) { category in
                Button {
                    onCategorySelect?(category.rawValue)
                } label: {
                    Label(category.displayName, systemImage: category.icon)
                }
            }
            Divider()
            Button {
                onCategorySelect?("")
            } label: {
                Label("Nicht gesetzt", systemImage: "questionmark.circle")
            }
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
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityIdentifier("categoryBadge_\(task.id)")
    }

    private var categoryColor: Color {
        TaskCategory(rawValue: task.taskType)?.color ?? .gray
    }

    private var categoryIcon: String {
        TaskCategory(rawValue: task.taskType)?.icon ?? "questionmark.circle"
    }

    private var categoryLabel: String {
        TaskCategory(rawValue: task.taskType)?.displayName ?? "Typ"
    }

    // MARK: - Duration Badge (macOS Menu Picker)

    private var isDurationSet: Bool {
        task.estimatedDuration != nil
    }

    private var durationBadge: some View {
        Menu {
            ForEach([5, 15, 30, 60], id: \.self) { minutes in
                Button {
                    onDurationSelect?(minutes)
                } label: {
                    Label("\(minutes) Min", systemImage: "timer")
                }
            }
            Divider()
            Button {
                onDurationSelect?(nil)
            } label: {
                Label("Nicht gesetzt", systemImage: "questionmark")
            }
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
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityIdentifier("durationBadge_\(task.id)")
    }

    // MARK: - Recurrence Display Name

    private func recurrenceDisplayName(_ pattern: String) -> String {
        switch pattern {
        case "daily": "Täglich"
        case "weekly": "Wöchentlich"
        case "biweekly": "Zweiwöchentlich"
        case "monthly": "Monatlich"
        default: pattern
        }
    }

    // MARK: - Due Date Badge

    private func dueDateBadge(_ date: Date) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
            Text(date.dueDateText())
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(date.isDueToday ? .red : .secondary)
        .fixedSize()
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
        TaskCategory(rawValue: taskType)?.color ?? .gray
    }

    private var icon: String {
        TaskCategory(rawValue: taskType)?.icon ?? "questionmark.circle"
    }

    private var label: String {
        TaskCategory(rawValue: taskType)?.localizedName ?? "Typ"
    }
}

#Preview {
    List {
        MacBacklogRow(task: LocalTask(title: "Sample Task", importance: 3))
        MacBacklogRow(task: LocalTask(title: "Another Task", estimatedDuration: 30))
    }
    .frame(width: 500)
}
