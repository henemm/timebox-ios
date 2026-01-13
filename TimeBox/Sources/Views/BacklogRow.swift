import SwiftUI

struct BacklogRow: View {
    let item: PlanItem
    var onDurationTap: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(2)
            }
            Spacer()
            DurationBadge(
                minutes: item.effectiveDuration,
                isDefault: item.durationSource == .default,
                onTap: onDurationTap
            )
        }
        .padding(.vertical, 4)
    }
}
