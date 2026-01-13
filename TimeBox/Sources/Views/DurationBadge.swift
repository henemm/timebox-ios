import SwiftUI

struct DurationBadge: View {
    let minutes: Int
    let isDefault: Bool
    var onTap: (() -> Void)?

    var body: some View {
        Text("\(minutes)m")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isDefault ? .yellow.opacity(0.3) : .blue.opacity(0.2))
            .clipShape(Capsule())
            .onTapGesture {
                onTap?()
            }
    }
}
