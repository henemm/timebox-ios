import SwiftUI

struct BacklogRow: View {
    let item: PlanItem
    var onDurationTap: (() -> Void)?
    var onAddToNextUp: (() -> Void)?
    var onTap: (() -> Void)?
    var onImportanceTap: (() -> Void)?
    var onCategoryTap: (() -> Void)?
    var onEditTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?

    @State private var isExpanded = false
    @State private var editableTitle: String = ""
    @State private var editableDuration: Int = 15

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 12) {
                // Column 1: Importance Button
                importanceButton

                // Column 2: Content
                contentSection

                Spacer(minLength: 8)

                // Column 3: Actions
                actionsMenu
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
        .accessibilityIdentifier("backlogRow_\(item.id)")
    }

    // MARK: - Importance Button

    private var importanceButton: some View {
        Button {
            onImportanceTap?()
        } label: {
            Image(systemName: importanceSFSymbol)
                .font(.system(size: 22))
                .foregroundStyle(importanceColor)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("importanceButton_\(item.id)")
        .accessibilityLabel("Wichtigkeit: \(importanceLabel)")
    }

    private var importanceSFSymbol: String {
        switch item.importance {
        case 1: return "square.fill"
        case 2: return "square.fill"
        case 3: return "circle.fill"
        default: return "questionmark.square"
        }
    }

    private var importanceColor: Color {
        switch item.importance {
        case 1: return .blue
        case 2: return .yellow
        case 3: return .red
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

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(item.title)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .italic(item.isTbd)
                .accessibilityIdentifier("taskTitle_\(item.id)")

            // Metadata Row
            metadataRow
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            // 1. Category Badge (always visible)
            categoryBadge

            // 2. TBD Badge (if incomplete task)
            if item.isTbd {
                Text("tbd")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .foregroundStyle(.secondary)
                    .cornerRadius(4)
                    .accessibilityIdentifier("tbdBadge_\(item.id)")
            }

            // 3. Tags (max 2, no icons - just text)
            if !item.tags.isEmpty {
                ForEach(item.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                        .foregroundStyle(.secondary)
                }

                // Overflow counter
                if item.tags.count > 2 {
                    Text("+\(item.tags.count - 2)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.1)))
                        .foregroundStyle(.secondary)
                }
            }

            // 4. Due Date Badge
            if let dueDate = item.dueDate {
                HStack(spacing: 2) {
                    Image(systemName: "calendar")
                    Text(dueDateText(dueDate))
                }
                .font(.caption2)
                .foregroundStyle(isDueToday(dueDate) ? .red : .secondary)
            }

            // 5. Duration Badge
            durationBadge
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
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("categoryBadge_\(item.id)")
        .accessibilityLabel("Kategorie: \(categoryLabel)")
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

    private var durationBadgeColor: Color {
        item.durationSource == .default ? .yellow : .blue
    }

    private var durationBadgeBackground: Color {
        item.durationSource == .default ? .yellow.opacity(0.2) : .blue.opacity(0.2)
    }

    private var durationBadge: some View {
        Button {
            onDurationTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text("\(item.effectiveDuration)m")
            }
            .font(.caption2)
            .foregroundStyle(durationBadgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(durationBadgeBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("durationBadge_\(item.id)")
        .accessibilityLabel("Dauer: \(item.effectiveDuration) Minuten")
    }

    // MARK: - Actions Menu

    private var actionsMenu: some View {
        Menu {
            Button {
                onEditTap?()
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }

            if !item.isNextUp {
                Button {
                    onAddToNextUp?()
                } label: {
                    Label("Zu Next Up", systemImage: "arrow.up.circle")
                }
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
                    // Save will be handled via onEditTap for now
                    // In future: direct save via callback
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded = false
                    }
                    onEditTap?()
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
