import SwiftUI

struct BacklogRow: View {
    let item: PlanItem
    var onDurationTap: (() -> Void)?
    var onAddToNextUp: (() -> Void)?
    var onTap: (() -> Void)?
    var onImportanceCycle: ((Int) -> Void)?  // Cycles: 1 → 2 → 3 → 1
    var onUrgencyToggle: ((String) -> Void)?  // Toggles: "urgent" ↔ "not_urgent"
    var onCategoryTap: (() -> Void)?
    var onEditTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?
    var onSaveInline: ((String, Int) -> Void)?  // title, duration

    @State private var isExpanded = false
    @State private var editableTitle: String = ""
    @State private var editableDuration: Int = 15

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 12) {
                // Left Column: Content (Title + Metadata)
                contentSection

                Spacer(minLength: 8)

                // Right Column: 2 Buttons (Next Up + Menu)
                rightColumnButtons
            }

            // Inline Edit Section (when expanded)
            if isExpanded {
                inlineEditSection
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            editableTitle = item.title
            editableDuration = item.effectiveDuration
            withAnimation(.spring(duration: 0.3)) {
                isExpanded.toggle()
            }
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

    // MARK: - Title View (italic if TBD)

    @ViewBuilder
    private var titleView: some View {
        if item.isTbd {
            Text(item.title)
                .font(.system(.body).weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .italic()
        } else {
            Text(item.title)
                .font(.system(.body).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }

    // MARK: - Metadata Row (Scrollable, fixed size badges)

    private var metadataRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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

    // MARK: - Urgency Badge (tappable, toggles urgent ↔ not_urgent)

    private var isUrgent: Bool {
        item.urgency == "urgent"
    }

    private var urgencyBadge: some View {
        Button {
            let newUrgency = isUrgent ? "not_urgent" : "urgent"
            onUrgencyToggle?(newUrgency)
        } label: {
            Image(systemName: isUrgent ? "flame.fill" : "flame")
                .font(.system(size: 14))
                .foregroundStyle(isUrgent ? .orange : .gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isUrgent ? .orange.opacity(0.2) : .gray.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .sensoryFeedback(.impact(weight: .medium), trigger: item.urgency)
        .accessibilityIdentifier("urgencyBadge_\(item.id)")
        .accessibilityLabel(isUrgent ? "Dringend. Tippen zum Entfernen." : "Nicht dringend. Tippen für Dringend.")
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
    // Gray = duration NOT set (TBD), Blue = duration IS set

    private var durationBadgeColor: Color {
        item.durationSource == .default ? .gray : .blue
    }

    private var durationBadgeBackground: Color {
        item.durationSource == .default ? .gray.opacity(0.2) : .blue.opacity(0.2)
    }

    private var durationBadge: some View {
        Button {
            onDurationTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text("\(item.effectiveDuration)m")
                    .lineLimit(1)
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
        .accessibilityLabel("Dauer: \(item.effectiveDuration) Minuten")
    }

    // MARK: - Right Column (2 Buttons Vertical)

    private var rightColumnButtons: some View {
        VStack(spacing: 0) {
            // Next Up Button (hidden if already in Next Up)
            if !item.isNextUp {
                nextUpButton
            }

            // Actions Menu
            actionsMenu
        }
        .frame(width: 44)
    }

    // MARK: - Next Up Button

    private var nextUpButton: some View {
        Button {
            onAddToNextUp?()
        } label: {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("nextUpButton_\(item.id)")
        .accessibilityLabel("Zu Next Up hinzufuegen")
    }

    // MARK: - Actions Menu (only Edit + Delete)

    private var actionsMenu: some View {
        Menu {
            Button {
                onEditTap?()
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDeleteTap?()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("actionsMenu_\(item.id)")
    }

    // MARK: - Inline Edit Section

    private var inlineEditSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.top, 8)

            // Title Edit Field
            TextField("Titel", text: $editableTitle)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                )
                .accessibilityIdentifier("editTitleField_\(item.id)")

            // Duration Quick-Select Buttons
            HStack(spacing: 8) {
                ForEach([5, 15, 30, 60], id: \.self) { minutes in
                    Button("\(minutes)m") {
                        editableDuration = minutes
                    }
                    .buttonStyle(.bordered)
                    .tint(editableDuration == minutes ? .yellow : .gray)
                    .accessibilityIdentifier("durationQuickSelect_\(minutes)_\(item.id)")
                }
            }

            // Cancel / Save Buttons
            HStack {
                Button("Abbrechen") {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded = false
                    }
                }
                .accessibilityIdentifier("cancelEditButton_\(item.id)")

                Spacer()

                Button("Speichern") {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded = false
                    }
                    onSaveInline?(editableTitle, editableDuration)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("saveEditButton_\(item.id)")
            }
        }
        .padding(.top, 8)
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
