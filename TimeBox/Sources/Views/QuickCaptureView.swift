import SwiftUI
import SwiftData

/// Minimalistic quick capture view for fast task entry from Control Center widget
struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Was gibt es zu tun?", text: $title)
                    .accessibilityIdentifier("quickCaptureTextField")
                    .focused($isFocused)
                    .font(.title2)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .accessibilityIdentifier("quickCaptureCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveTask()
                    }
                    .accessibilityIdentifier("quickCaptureSaveButton")
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true

        Task {
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                _ = try await taskSource.createTask(
                    title: trimmedTitle,
                    priority: 1,
                    duration: 15
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                isSaving = false
            }
        }
    }
}

#Preview {
    QuickCaptureView()
        .modelContainer(for: LocalTask.self, inMemory: true)
}
