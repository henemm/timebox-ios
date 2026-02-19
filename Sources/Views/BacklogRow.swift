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

    // State for inline title editing (double-tap)
    @State private var isEditingTitle = false
    @State private var editableTitle: String = ""
    @FocusState private var titleFieldFocused: Bool

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
        .contentShape(Rectangle())
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

    // MARK: - Metadata Row (fixed size badges, no nested ScrollView to avoid scroll issues)

    private var metadataRow: some View {
        HStack(spacing: 6) {
            // 1. Importance Badge (always visible, gray "?" if not set)
            importanceBadge

            // 2. Urgency Badge
            urgencyBadge

            // 3. Category Badge
            categoryBadge

            // 3b. Recurrence Badge (only if recurring)
            if let pattern = item.recurrencePattern, pattern != "none" {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(RecurrencePattern(rawValue: pattern)?.displayName ?? pattern)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.purple.opacity(0.2))
                )
            }

            // 4. Tags (max 2, dann "+N") - plain text, no chips
            if !item.tags.isEmpty {
                ForEach(item.tags.prefix(2), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                if item.tags.count > 2 {
                    Text("+\(item.tags.count - 2)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 5. Duration Badge
            durationBadge

            // 6. Priority Score Badge
            priorityScoreBadge

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
        .clipped()
    }

    // MARK: - Importance Badge (tappable, cycles 1 → 2 → 3 → 1)
    // Always visible: shows gray "?" when not set

    private var importanceBadge: some View {
        Button {
            let current = item.importance ?? 0
            let next = current >= 3 ? 1 : current + 1
            onImportanceCycle?(next)
        } label: {
            Image(systemName: importanceSFSymbol)
                .font(.system(size: 14))
                .foregroundStyle(importanceColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(importanceColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .sensoryFeedback(.impact(weight: .light), trigger: item.importance)
        .accessibilityIdentifier("importanceBadge_\(item.id)")
        .accessibilityLabel("Wichtigkeit: \(importanceLabel). Tippen zum Ändern.")
    }

    private var importanceSFSymbol: String {
        ImportanceUI.icon(for: item.importance)
    }

    private var importanceColor: Color {
        ImportanceUI.color(for: item.importance)
    }

    private var importanceLabel: String {
        ImportanceUI.label(for: item.importance)
    }

    // MARK: - Urgency Badge (tappable, cycles: nil → not_urgent → urgent → nil)

    private var isUrgent: Bool {
        item.urgency == "urgent"
    }

    private var isUrgencySet: Bool {
        item.urgency != nil
    }

    private var urgencyBadge: some View {
        Button {
            // Cycle: nil → not_urgent → urgent → nil
            let newUrgency: String?
            switch item.urgency {
            case nil: newUrgency = "not_urgent"
            case "not_urgent": newUrgency = "urgent"
            case "urgent": newUrgency = nil
            default: newUrgency = nil
            }
            onUrgencyToggle?(newUrgency)
        } label: {
            Image(systemName: urgencyIcon)
                .font(.system(size: 14))
                .foregroundStyle(urgencyColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(urgencyColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .sensoryFeedback(.impact(weight: .medium), trigger: item.urgency)
        .accessibilityIdentifier("urgencyBadge_\(item.id)")
        .accessibilityLabel(urgencyAccessibilityLabel)
    }

    private var urgencyIcon: String {
        UrgencyUI.icon(for: item.urgency)
    }

    private var urgencyColor: Color {
        UrgencyUI.color(for: item.urgency)
    }

    private var urgencyAccessibilityLabel: String {
        switch item.urgency {
        case "urgent": return "Dringend. Tippen zum Entfernen."
        case "not_urgent": return "Nicht dringend. Tippen für Dringend."
        default: return "Dringlichkeit nicht gesetzt. Tippen zum Setzen."
        }
    }

    // MARK: - Category Badge

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

    // MARK: - Priority Score Badge

    private var priorityScoreBadge: some View {
        let score = item.priorityScore
        let tier = item.priorityTier
        let color: Color = switch tier {
        case .doNow: .red
        case .planSoon: .orange
        case .eventually: .yellow
        case .someday: .gray
        }
        return HStack(spacing: 2) {
            Image(systemName: "chart.bar.fill")
            Text("\(score)")
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.2))
        )
        .accessibilityIdentifier("priorityScoreBadge_\(item.id)")
    }

    // MARK: - Duration Badge
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
