import SwiftUI

/// Compact card showing the Monster Coach status in the Review tab.
struct MonsterStatusView: View {
    let coach: MonsterCoach

    var body: some View {
        VStack(spacing: 16) {
            // Monster header: icon + name + level
            HStack {
                Image(systemName: coach.evolutionIcon)
                    .font(.title)
                    .foregroundStyle(evolutionColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(coach.name)
                        .font(.headline)
                    Text("\(coach.evolutionName) · \(coach.totalXP) XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Lvl \(coach.evolutionLevel)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(evolutionColor)
            }

            // Discipline XP bars
            VStack(spacing: 8) {
                ForEach(Discipline.allCases, id: \.self) { discipline in
                    disciplineRow(discipline)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .accessibilityIdentifier("monsterStatusCard")
    }

    private func disciplineRow(_ discipline: Discipline) -> some View {
        let xp = coach.xp[discipline.rawValue, default: 0]
        return HStack(spacing: 8) {
            Image(systemName: discipline.icon)
                .foregroundStyle(discipline.color)
                .frame(width: 20)

            Text(discipline.displayName)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            Text("\(xp)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var evolutionColor: Color {
        switch coach.evolutionLevel {
        case 0: .secondary
        case 1: .green
        case 2: .blue
        case 3: .orange
        default: .purple
        }
    }
}
