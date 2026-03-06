import SwiftUI

struct BacklogRow: View {
    let item: PlanItem
    var onComplete: (() -> Void)?  // Mark task as completed
    var onDurationTap: (() -> Void)?
    var onAddToNextUp: (() -> Void)?
    var onTap: (() -> Void)?
    var onImportanceCycle: ((Int) -> Void)?  // Cycles: 1 → 2 → 3 → 1
    var onUrgencyToggle: ((String?) -> Void)?  // Cycles: nil → not_urgent → urgent → nil
    var onCategoryTap: (() -> Void)?
    var onEditTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?
    var onTitleSave: ((String) -> Void)?  // Inline title edit callback
    var isPendingResort: Bool = false  // Deferred sort: shows border when item changed but not yet re-sorted

    // State for inline title editing (double-tap)
    @State private var isEditingTitle = false
    @State private var editableTitle: String = ""
    @FocusState private var titleFieldFocused: Bool
    @State private var pendingPulse = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Completion Checkbox
            Button {
                onComplete?()
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("completeButton_\(item.id)")
            .accessibilityLabel("Als erledigt markieren")

            // Content (Title + Metadata) - full width, no right column
            // Swipe actions handle Next Up (right) and Edit/Delete (left)
            contentSection
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            if isPendingResort {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.orange, lineWidth: pendingPulse ? 2.5 : 1.5)
                    .opacity(pendingPulse ? 0.9 : 0.4)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("pendingResortBorder_\(item.id)")
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
        .contentShape(Rectangle())
        .userActivity(TaskEntity.activityType, isActive: !item.isCompleted) { activity in
            activity.title = item.title
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.targetContentIdentifier = "task://\(item.id)"
            activity.userInfo = ["entityID": item.id]
        }
        // NOTE: No accessibilityIdentifier on parent - children have their own identifiers
        // Parent identifier would override all child identifiers in SwiftUI
    }

    // MARK: - Content Section (Left Column)

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title (bold, max 2 lines, italic + gray if TBD)
            titleView
                .accessibilityIdentifier("taskTitle_\(item.id)")

            // Metadata Row
            metadataRow
        }
    }

    // MARK: - Title View (italic if TBD, double-tap to edit)

    @ViewBuilder
    private var titleView: some View {
        if isEditingTitle {
            // Inline title editing mode
            TextField("Titel", text: $editableTitle)
                .font(.system(.body).weight(.semibold))
                .foregroundStyle(.primary)
                .focused($titleFieldFocused)
                .onSubmit {
                    saveTitle()
                }
                .onChange(of: titleFieldFocused) { _, focused in
                    if !focused {
                        saveTitle()
                    }
                }
                .accessibilityIdentifier("inlineTitleField_\(item.id)")
        } else if item.isTbd {
            Text(item.title)
                .font(.system(.body).weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .italic()
                .onTapGesture(count: 2) {
                    startTitleEdit()
                }
        } else {
            Text(item.title)
                .font(.system(.body).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .onTapGesture(count: 2) {
                    startTitleEdit()
                }
        }
    }

    // MARK: - Title Edit Helpers

    private func startTitleEdit() {
        editableTitle = item.title
        isEditingTitle = true
        titleFieldFocused = true
    }

    private func saveTitle() {
        let trimmed = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != item.title {
            onTitleSave?(trimmed)
        }
        isEditingTitle = false
    }

    // MARK: - Metadata Row (FlowLayout wraps badges to next line when they exceed available width)

    private var metadataRow: some View {
        FlowLayout(spacing: 6) {
            // 1. Importance Badge
            ImportanceBadge(importance: item.importance, taskId: item.id) { next in
                onImportanceCycle?(next)
            }

            // 2. Urgency Badge
            UrgencyBadge(urgency: item.urgency, taskId: item.id) { next in
                onUrgencyToggle?(next)
            }

            // 3. Category Badge
            categoryBadge

            // 3b. Recurrence Badge (only if recurring)
            if let pattern = item.recurrencePattern, pattern != "none" {
                RecurrenceBadge(pattern: pattern, taskId: item.id)
            }

            // 4. Tags
            if !item.tags.isEmpty {
                TagsBadge(tags: item.tags, taskId: item.id)
            }

            // 5. Duration Badge
            durationBadge

            // 6. Priority Score Badge
            PriorityScoreBadge(score: item.priorityScore, tier: item.priorityTier, taskId: item.id)

            // 7. Due Date Badge
            if let dueDate = item.dueDate {
                HStack(spacing: 2) {
                    Image(systemName: "calendar")
                    Text(dueDate.dueDateText())
                }
                .font(.caption2)
                .foregroundStyle(dueDate.isDueToday ? .red : .secondary)
                .lineLimit(1)
            }
        }
    }

    // MARK: - Category Badge (platform-specific: iOS uses Button+Callback)

    private var categoryBadge: some View {
        Button {
            onCategoryTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: categoryIcon)
                Text(categoryLabel)
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(categoryColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(categoryColor.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("categoryBadge_\(item.id)")
        .accessibilityLabel("Kategorie: \(categoryLabel)")
    }

    private var categoryColor: Color {
        TaskCategory(rawValue: item.taskType)?.color ?? .gray
    }

    private var categoryIcon: String {
        TaskCategory(rawValue: item.taskType)?.icon ?? "questionmark.circle"
    }

    private var categoryLabel: String {
        TaskCategory(rawValue: item.taskType)?.displayName ?? item.taskType.capitalized
    }

    // MARK: - Duration Badge (platform-specific: iOS uses Button+Callback)
    // Gray "?" = duration NOT set (TBD), Blue = duration IS set

    private var isDurationSet: Bool {
        item.estimatedDuration != nil
    }

    private var durationBadgeColor: Color {
        isDurationSet ? .blue : .gray
    }

    private var durationBadgeBackground: Color {
        isDurationSet ? .blue.opacity(0.2) : .gray.opacity(0.2)
    }

    private var durationBadge: some View {
        Button {
            onDurationTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isDurationSet ? "timer" : "questionmark")
                if isDurationSet {
                    Text("\(item.effectiveDuration)m")
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(durationBadgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(durationBadgeBackground)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("durationBadge_\(item.id)")
        .accessibilityLabel(isDurationSet ? "Dauer: \(item.effectiveDuration) Minuten" : "Dauer nicht gesetzt")
    }

}
