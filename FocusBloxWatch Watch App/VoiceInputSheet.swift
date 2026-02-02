import SwiftUI

struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskTitle = ""
    @FocusState private var isFocused: Bool

    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Was möchtest du tun?")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("Task eingeben...", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .accessibilityIdentifier("taskTitleField")
            }
            .padding()
            .navigationTitle("Neuer Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        if !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveButton")
                }
            }
            .onAppear {
                // Auto-focus to trigger dictation keyboard on Watch
                isFocused = true
            }
        }
    }
}

#Preview {
    VoiceInputSheet { title in
        print("Saved: \(title)")
    }
}
