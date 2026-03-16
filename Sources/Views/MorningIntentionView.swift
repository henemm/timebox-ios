import SwiftUI

/// Coach selection card shown in the "Mein Tag" tab when Coach mode is enabled.
/// Two states: 4 coach cards (not set) or compact summary (coach selected).
struct MorningIntentionView: View {
    let allTasks: [PlanItem]

    @State private var selection = DailyCoachSelection.load()
    @State private var selectedCoachType: CoachType?
    @State private var isEditing = false
    @State private var aiPitches: [CoachType: String] = [:]
    @AppStorage("selectedCoach") private var selectedCoach: String = ""
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

    private var previews: [CoachType: CoachPreview] {
        Dictionary(uniqueKeysWithValues:
            CoachType.allCases.map { ($0, CoachMissionService.generatePreview(coach: $0, allTasks: allTasks)) }
        )
    }

    private var recommendedCoach: CoachType? {
        CoachMissionService.recommendedCoach(from: previews)
    }

    var body: some View {
        VStack(spacing: 12) {
            if selection.isSet && !isEditing {
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
            if selection.isSet {
                selectedCoachType = selection.coach
            }
        }
        .task {
            await loadAIPitches()
        }
    }

    // MARK: - Compact View (after selecting a coach)

    private var compactView: some View {
        HStack {
            if let coach = selection.coach {
                Image(coach.monsterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("monsterImage")

                VStack(alignment: .leading, spacing: 2) {
                    Text(coach.displayName)
                        .font(.headline)
                    Text(coach.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Ändern") {
                withAnimation(.spring()) {
                    isEditing = true
                }
            }
            .font(.caption)
            .accessibilityIdentifier("editIntentionButton")
        }
    }

    // MARK: - Selection View (4 Coach Cards — vertical list)

    private var selectionView: some View {
        VStack(spacing: 16) {
            Text("Wähle deinen Coach")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(CoachType.allCases, id: \.self) { coach in
                    coachCard(for: coach)
                }
            }

            // "Ohne Coach" option
            Button {
                saveSelection(coach: nil)
            } label: {
                Text("Ohne Coach weitermachen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("noCoachButton")

            Button {
                guard let coach = selectedCoachType else { return }
                saveSelection(coach: coach)
            } label: {
                Text("Coach wählen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedCoachType?.color ?? .accentColor)
            .disabled(selectedCoachType == nil)
            .accessibilityIdentifier("setIntentionButton")
        }
    }

    // MARK: - Coach Card

    private func coachCard(for coach: CoachType) -> some View {
        let isSelected = selectedCoachType == coach
        let preview = previews[coach] ?? CoachPreview(teaser: coach.shortPitch, taskCount: 0, isEmpty: true)
        let displayText = aiPitches[coach] ?? preview.teaser
        let isRecommended = recommendedCoach == coach

        return Button {
            withAnimation(.spring()) {
                selectedCoachType = coach
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(coach.monsterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(coach.displayName) — \(coach.subtitle)")
                            .font(.subheadline.weight(.semibold))

                        if isRecommended {
                            Text("Empfohlen")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(coach.color.opacity(0.2))
                                .clipShape(Capsule())
                                .accessibilityIdentifier("recommendedBadge_\(coach.rawValue)")
                        }
                    }

                    Text(coach.shortPitch)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(displayText)
                        .font(.callout)
                        .animation(.smooth, value: displayText)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? coach.color.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? coach.color : .secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .foregroundStyle(isSelected ? coach.color : .primary)
        .accessibilityIdentifier("coachSelectionCard_\(coach.rawValue)")
    }

    // MARK: - AI Pitches

    private func loadAIPitches() async {
        await withTaskGroup(of: (CoachType, String?).self) { group in
            for coach in CoachType.allCases {
                group.addTask {
                    let pitch = await CoachPitchService.generatePitch(coach: coach, allTasks: allTasks)
                    return (coach, pitch)
                }
            }
            for await (coach, pitch) in group {
                if let pitch {
                    aiPitches[coach] = pitch
                }
            }
        }
    }

    // MARK: - Save

    private func saveSelection(coach: CoachType?) {
        var newSelection = DailyCoachSelection(date: selection.date, coach: coach)
        newSelection.save()

        // Write AppStorage for BacklogView
        selectedCoach = coach?.rawValue ?? ""
        // Signal tab switch to Backlog
        intentionJustSet = true

        // Sync to iCloud
        let today = DailyCoachSelection.todayKey().replacingOccurrences(of: "dailyCoach_", with: "")
        UserDefaults.standard.set(today, forKey: "selectedCoachDate")
        Task { @MainActor in
            SyncedSettings().pushToCloud()
        }

        // Schedule notifications if coach selected
        if let coach, AppSettings.shared.coachModeEnabled {
            scheduleCoachNotifications(coach: coach)
        }

        withAnimation(.spring()) {
            selection = newSelection
            isEditing = false
        }
    }

    private func scheduleCoachNotifications(coach: CoachType) {
        let settings = AppSettings.shared

        // Schedule evening reminder if enabled
        if settings.coachEveningReminderEnabled {
            NotificationService.scheduleEveningReminder(
                hour: settings.coachEveningReminderHour,
                minute: settings.coachEveningReminderMinute,
                coach: coach
            )
        }
    }
}
