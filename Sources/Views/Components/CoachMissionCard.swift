import SwiftUI

/// Coach Mission Card — shows the monster's daily mission with progress bar.
struct CoachMissionCard: View {
    let coach: CoachType
    let mission: CoachMission

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(coach.monsterImage)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text("\(coach.displayName) — \(coach.subtitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(mission.headline)
                    .font(.headline)

                Text(mission.detail)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.85))

                if mission.progressTotal > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: Double(mission.progressDone),
                                     total: Double(mission.progressTotal))
                            .tint(coach.color)

                        Text("\(mission.progressDone) von \(mission.progressTotal) \(mission.progressLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(coach.color.opacity(0.15))
        )
        .accessibilityIdentifier("coachMissionCard")
    }
}
