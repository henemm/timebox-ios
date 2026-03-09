//
//  MacBacklogRow.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData

/// Compact task row optimized for macOS list display
/// Aligned with iOS BacklogRow styling and functionality
struct MacBacklogRow: View {
    let task: LocalTask
    var onToggleComplete: (() -> Void)?
    var onImportanceCycle: ((Int) -> Void)?
    var onUrgencyToggle: ((String?) -> Void)?
    var onCategorySelect: ((String) -> Void)?  // Direct category selection (macOS Menu)
    var onDurationSelect: ((Int?) -> Void)?    // Direct duration selection (macOS Menu)
    var isPendingResort: Bool = false  // Deferred sort: shows border when item changed but not yet re-sorted
    @State private var pendingPulse = false

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

            // Title + Metadata (fills available width, like iOS BacklogRow contentSection)
            VStack(alignment: .leading, spacing: 4) {
                // Title (italic if TBD)
                Text(task.title)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : (task.isTbd ? .secondary : .primary))
                    .italic(task.isTbd)

                // Metadata Row (aligned with iOS)
                metadataRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .overlay {
            if isPendingResort {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.orange, lineWidth: pendingPulse ? 2.5 : 1.5)
                    .opacity(pendingPulse ? 0.9 : 0.4)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("pendingResortBorder_\(task.uuid.uuidString)")
            }
        }
        .animation(.easeOut(duration: 0.3), value: isPendingResort)
        .onChange(of: isPendingResort) { _, pending in
            if pending {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pendingPulse = true
                }
            } else {
                pendingPulse = false
            }
        }
        .userActivity("com.henning.focusblox.viewTask", isActive: !task.isCompleted) { activity in
            activity.title = task.title
            activity.isEligibleForSearch = true
            activity.targetContentIdentifier = "task://\(task.uuid.uuidString)"
            activity.userInfo = ["entityID": task.uuid.uuidString]
        }
    }

    // MARK: - Metadata Row (iOS-aligned)

    private var metadataRow: some View {
        HStack(spacing: 6) {
            // 1. Importance Badge
            ImportanceBadge(importance: task.importance, taskId: task.id) { next in
                onImportanceCycle?(next)
            }

            // 2. Urgency Badge
            UrgencyBadge(urgency: task.urgency, taskId: task.id) { next in
                onUrgencyToggle?(next)
            }

            // 3. Category Badge (macOS Menu Picker)
            categoryBadge

            // 4. Recurrence Badge
            if task.recurrencePattern != "none" {
                RecurrenceBadge(pattern: task.recurrencePattern, taskId: task.id)
            }

            // 5. Tags (Bug 78: guard against detached SwiftData objects)
            if task.modelContext != nil, !task.tags.isEmpty {
                TagsBadge(tags: task.tags, taskId: task.id)
            }

            // 6. Duration Badge (macOS Menu Picker)
            durationBadge

            // 7. Priority Score Badge
            let score = TaskPriorityScoringService.calculateScore(
                importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
                createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
                estimatedDuration: task.estimatedDuration, taskType: task.taskType,
                isNextUp: task.isNextUp
            )
            PriorityScoreBadge(
                score: score,
                tier: TaskPriorityScoringService.PriorityTier.from(score: score),
                taskId: task.id
            )

            // 7. Due Date Badge
            if let dueDate = task.dueDate {
                dueDateBadge(dueDate)
            }
        }
    }

    // MARK: - Category Badge (macOS Menu Picker — platform-specific)

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

    // MARK: - Duration Badge (macOS Menu Picker — platform-specific)

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
