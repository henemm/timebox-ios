import SwiftUI

/// Coach selection card shown in the "Mein Tag" tab when Coach mode is enabled.
/// Two states: 4 coach cards (not set) or compact summary (coach selected).
struct MorningIntentionView: View {
    @State private var selection = DailyCoachSelection.load()
    @State private var selectedCoachType: CoachType?
    @State private var isEditing = false
    @AppStorage("selectedCoach") private var selectedCoach: String = ""
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

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

    // MARK: - Selection View (4 Coach Cards)

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var selectionView: some View {
        VStack(spacing: 16) {
            Text("Wähle deinen Coach")
                .font(.headline)

            if let coach = selectedCoachType {
                Image(coach.monsterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("monsterImage")
                    .transition(.scale.combined(with: .opacity))
            }

            LazyVGrid(columns: columns, spacing: 12) {
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

        return Button {
            withAnimation(.spring()) {
                selectedCoachType = coach
            }
        } label: {
            VStack(spacing: 6) {
                Image(coach.monsterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                    .clipShape(Circle())

                Text(coach.displayName)
                    .font(.subheadline.bold())

                Text(coach.shortPitch)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
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
