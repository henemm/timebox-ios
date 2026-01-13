import SwiftUI

struct MiniTaskCard: View {
    let task: PlanItem

    var body: some View {
        HStack(spacing: 6) {
            Text(task.title)
                .font(.caption)
                .lineLimit(1)

            Text("\(task.effectiveDuration)m")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
