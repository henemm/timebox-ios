import SwiftUI

/// Shared day progress component for Coach Review views (iOS + macOS).
/// Shows "X Tasks erledigt" with a checkmark icon.
struct DayProgressSection: View {
    let completedCount: Int

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(completedCount) Tasks erledigt")
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .accessibilityIdentifier("coachDayProgress")
    }
}
