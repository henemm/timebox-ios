import SwiftUI

/// Quick duration selection button for CreateTaskView
struct QuickDurationButton: View {
    let minutes: Int
    @Binding var selectedMinutes: Int

    private var isSelected: Bool {
        selectedMinutes == minutes
    }

    var body: some View {
        Button {
            selectedMinutes = minutes
        } label: {
            Text("\(minutes)m")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var duration = 15

    VStack(spacing: 12) {
        Text("Selected: \(duration) minutes")

        HStack(spacing: 12) {
            QuickDurationButton(minutes: 5, selectedMinutes: $duration)
            QuickDurationButton(minutes: 15, selectedMinutes: $duration)
            QuickDurationButton(minutes: 30, selectedMinutes: $duration)
            QuickDurationButton(minutes: 60, selectedMinutes: $duration)
        }
    }
    .padding()
}
