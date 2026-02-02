import SwiftUI
import WatchKit

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
                .accessibilityIdentifier("confirmationCheckmark")

            Text("Task gespeichert")
                .font(.headline)
        }
        .onAppear {
            // Haptic feedback
            WKInterfaceDevice.current().play(.success)

            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }
}

#Preview {
    ConfirmationView()
}
