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

            // 4. Tags (max 2, dann "+N") - plain text, no chips
            if !item.tags.isEmpty {
                ForEach(item.tags.prefix(2), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                if item.tags.count > 2 {
                    Text("+\(item.tags.count - 2)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }

            // 5. Duration Badge
            durationBadge

            // 6. Due Date Badge
            if let dueDate = item.dueDate {
                HStack(spacing: 2) {
                    Image(systemName: "calendar")
                    Text(dueDateText(dueDate))
                }
                .font(.caption2)
                .foregroundStyle(isDueToday(dueDate) ? .red : .secondary)
                .fixedSize()
            }
        }
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
        switch item.importance {
        case 3: return "exclamationmark.3"
        case 2: return "exclamationmark.2"
        case 1: return "exclamationmark"
        default: return "questionmark"
        }
    }

    private var importanceColor: Color {
        switch item.importance {
        case 3: return .red
        case 2: return .yellow
        case 1: return .blue
        default: return .gray
        }
    }

    private var importanceLabel: String {
        switch item.importance {
        case 1: return "Niedrig"
        case 2: return "Mittel"
        case 3: return "Hoch"
        default: return "Nicht gesetzt"
        }
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
        switch item.urgency {
        case "urgent": return "flame.fill"
        case "not_urgent": return "flame"
        default: return "questionmark"  // TBD
        }
    }

    private var urgencyColor: Color {
        switch item.urgency {
        case "urgent": return .orange
        case "not_urgent": return .gray
        default: return .gray  // TBD
        }
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
        .fixedSize()
        .accessibilityIdentifier("categoryBadge_\(item.id)")
        .accessibilityLabel("Kategorie: \(categoryLabel)")
    }

    private var categoryColor: Color {
        switch item.taskType {
        case "income": return .green
        case "maintenance": return .orange
        case "recharge": return .cyan
        case "learning": return .purple
        case "giving_back": return .pink
        default: return .gray
        }
    }

    private var categoryIcon: String {
        switch item.taskType {
        case "income": return "dollarsign.circle"
        case "maintenance": return "wrench.and.screwdriver.fill"
        case "recharge": return "battery.100"
        case "learning": return "book"
        case "giving_back": return "gift"
        case "deep_work": return "brain"
        case "shallow_work": return "tray"
        case "meetings": return "person.2"
        case "creative": return "paintbrush"
        case "strategic": return "lightbulb"
        default: return "questionmark.circle"
        }
    }

    private var categoryLabel: String {
        switch item.taskType {
        case "income": return "Geld"
        case "maintenance": return "Pflege"
        case "recharge": return "Energie"
        case "learning": return "Lernen"
        case "giving_back": return "Geben"
        case "deep_work": return "Deep Work"
        case "shallow_work": return "Shallow"
        case "meetings": return "Meeting"
        case "creative": return "Kreativ"
        case "strategic": return "Strategie"
        default: return "Typ"
        }
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

    // MARK: - Helper Functions

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
