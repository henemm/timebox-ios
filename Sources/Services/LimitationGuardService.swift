import SwiftUI

/// Ergebnis der Limitation-Pruefung — nil bedeutet kein Problem.
struct LimitationWarning: Equatable {
    /// Anzahl Tasks die sich der User vorgenommen hat.
    let plannedTasks: Int
    /// Summe der effectiveDuration aller Next-Up-Tasks (Minuten).
    let plannedMinutes: Int
    /// Historischer Durchschnitt Tasks/Tag.
    let avgTasks: Double
    /// Historischer Durchschnitt Minuten/Tag.
    let avgMinutes: Double
}

enum LimitationGuardService {

    /// Prueft ob die uebergebene Task-Liste den historischen Schnitt ueberschreitet.
    /// - Returns: `LimitationWarning` wenn Ueberschreitung vorliegt, sonst nil.
    static func evaluate(
        tasks: [PlanItem],
        profile: BehavioralProfile
    ) -> LimitationWarning? {
        let avgTasks = profile.avgTasksPerDay
        let avgMinutes = profile.avgMinutesPerDay

        // Beide nil → zu wenig Daten
        guard avgTasks != nil || avgMinutes != nil else { return nil }

        // Leere Liste → nie warnen
        guard !tasks.isEmpty else { return nil }

        let plannedTasks = tasks.count
        let plannedMinutes = tasks.map(\.effectiveDuration).reduce(0, +)

        let tasksExceed: Bool = {
            guard let avg = avgTasks else { return false }
            return plannedTasks > Int((avg * 1.5).rounded())
        }()

        let minutesExceed: Bool = {
            guard let avg = avgMinutes else { return false }
            return plannedMinutes > Int((avg * 1.5).rounded())
        }()

        guard tasksExceed || minutesExceed else { return nil }

        return LimitationWarning(
            plannedTasks: plannedTasks,
            plannedMinutes: plannedMinutes,
            avgTasks: avgTasks ?? 0,
            avgMinutes: avgMinutes ?? 0
        )
    }
}

// MARK: - Banner View

/// Nicht-modaler Inline-Banner fuer die Limitation-Warnung.
struct LimitationWarningBanner: View {
    let warning: LimitationWarning
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.title3)

            Text(warningText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("limitationWarningText")

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("limitationWarningDismissButton")
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("limitationWarningBanner")
    }

    private var warningText: String {
        let planned = formatDuration(warning.plannedMinutes)
        let avg = formatDuration(Int(warning.avgMinutes))
        return "Du hast dir \(warning.plannedTasks) Tasks / \(planned) vorgenommen. Dein Schnitt liegt bei \(Int(warning.avgTasks)) Tasks / \(avg)."
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) Min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return "\(hours) Std"
        }
        return "\(hours) Std \(remaining) Min"
    }
}
