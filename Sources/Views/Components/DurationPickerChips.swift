import SwiftUI

struct DurationPickerChips: View {
    let defaultDuration: Int
    var onStart: (Int) -> Void

    private let options = [15, 25, 45, 60]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { minutes in
                Button {
                    onStart(minutes)
                } label: {
                    Text("\(minutes) Min")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            minutes == defaultDuration
                                ? Color.accentColor.opacity(0.2)
                                : Color.secondary.opacity(0.1),
                            in: Capsule()
                        )
                        .foregroundStyle(minutes == defaultDuration ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("durationChip_\(minutes)")
            }
        }
    }
}
