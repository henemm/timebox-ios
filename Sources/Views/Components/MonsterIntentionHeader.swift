import SwiftUI

/// Shared Monster header component for Coach Backlog views (iOS + macOS).
/// Shows the monster image for the active coach, or a fallback prompt.
struct MonsterIntentionHeader: View {
    let selectedCoach: String
    var imageHeight: CGFloat = 100

    private var coach: CoachType? {
        CoachBacklogViewModel.parseCoach(selectedCoach)
    }

    var body: some View {
        VStack(spacing: 8) {
            if let coach {
                Image(coach.monsterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: imageHeight)
                    .clipShape(Circle())

                Text("\(coach.displayName) — \(coach.subtitle)")
                    .font(.headline)
                    .foregroundStyle(coach.color)
            } else {
                Image(systemName: "sun.and.horizon")
                    .font(.system(size: imageHeight > 90 ? 48 : 36))
                    .foregroundStyle(.secondary)

                Text("Starte deinen Tag unter Mein Tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, imageHeight > 90 ? 12 : 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachMonsterHeader")
    }
}
