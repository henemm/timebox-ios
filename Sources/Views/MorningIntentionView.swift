import SwiftUI

/// Morning Intention card shown in the Review tab when Coach mode is enabled.
/// Two states: selection grid (not set) or compact summary (set).
struct MorningIntentionView: View {
    @State private var intention = DailyIntention.load()
    @State private var selectedOptions: Set<IntentionOption> = []
    @State private var isEditing = false
    @AppStorage("intentionFilterOptions") private var intentionFilterOptions: String = ""
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {
            if intention.isSet && !isEditing {
                compactView
            } else {
                selectionView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("morningIntentionCard")
        .onAppear {
            if intention.isSet {
                selectedOptions = Set(intention.selections)
            }
        }
    }

    // MARK: - Compact View (after setting)

    private var compactView: some View {
        HStack {
            if let primary = intention.selections.first {
                Image(primary.monsterDiscipline.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("monsterImage")
            }

            ForEach(intention.selections, id: \.self) { option in
                HStack(spacing: 4) {
                    Image(systemName: option.icon)
                        .foregroundStyle(option.color)
                    Text(option.label)
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button("Aendern") {
                withAnimation(.spring()) {
                    isEditing = true
                }
            }
            .font(.caption)
            .accessibilityIdentifier("editIntentionButton")
        }
    }

    // MARK: - Selection View

    /// The dominant discipline for the currently selected options.
    private var selectedMonsterDiscipline: Discipline? {
        selectedOptions.first?.monsterDiscipline
    }

    private var selectionView: some View {
        VStack(spacing: 16) {
            Text("Wie wird dein Tag?")
                .font(.headline)

            if let discipline = selectedMonsterDiscipline {
                Image(discipline.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("monsterImage")
                    .transition(.scale.combined(with: .opacity))
            }

            Text("Wenn du heute Abend auf diesen Tag zurueckblickst...")
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(IntentionOption.allCases, id: \.self) { option in
                    chipButton(for: option)
                }
            }

            Button {
                let selections = Array(selectedOptions)
                var newIntention = DailyIntention(
                    date: intention.date,
                    selections: selections
                )
                newIntention.save()

                // Write active filter options for BacklogView
                intentionFilterOptions = selections.map(\.rawValue).joined(separator: ",")
                // Signal tab switch to Backlog
                intentionJustSet = true

                // Schedule daily nudge notifications if enabled
                let settings = AppSettings.shared
                if settings.coachModeEnabled,
                   settings.coachDailyNudgesEnabled,
                   !selections.contains(.survival) {
                    // Use first selected intention for gap detection
                    if let primary = selections.first,
                       let gap = IntentionEvaluationService.detectGap(
                           intention: primary, tasks: [], focusBlocks: []
                       ) {
                        NotificationService.scheduleDailyNudges(
                            intention: primary, gap: gap
                        )
                    }
                }

                // Schedule evening reminder if enabled
                if settings.coachModeEnabled,
                   settings.coachEveningReminderEnabled {
                    NotificationService.scheduleEveningReminder(
                        hour: settings.coachEveningReminderHour,
                        minute: settings.coachEveningReminderMinute,
                        intention: selections.first
                    )
                }

                withAnimation(.spring()) {
                    intention = newIntention
                    isEditing = false
                }
            } label: {
                Text("Intention setzen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedOptions.isEmpty)
            .accessibilityIdentifier("setIntentionButton")
        }
    }

    // MARK: - Chip Button

    private func chipButton(for option: IntentionOption) -> some View {
        let isSelected = selectedOptions.contains(option)

        return Button {
            withAnimation(.spring()) {
                if isSelected {
                    selectedOptions.remove(option)
                } else {
                    selectedOptions.insert(option)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                Text(option.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? option.color.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? option.color : .secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .foregroundStyle(isSelected ? option.color : .primary)
        .accessibilityIdentifier("intentionChip_\(option.rawValue)")
    }
}
