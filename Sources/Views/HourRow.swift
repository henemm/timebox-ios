import SwiftUI

struct HourRow: View {
    let hour: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .trailing)

            Rectangle()
                .fill(.secondary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.trailing)
    }
}
