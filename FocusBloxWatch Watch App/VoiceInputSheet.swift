import SwiftUI
import SwiftData
import WatchKit

struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskTitle = ""
    @State private var autoSaveTask: DispatchWorkItem?
    @FocusState private var isFocused: Bool

    let modelContext: ModelContext

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
                    .onChange(of: taskTitle) { _, newValue in
                        scheduleAutoSave(for: newValue)
                    }
            }
            .padding()
            .navigationTitle("Neuer Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        autoSaveTask?.cancel()
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func scheduleAutoSave(for text: String) {
        autoSaveTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let workItem = DispatchWorkItem { [trimmed] in
            saveTask(title: trimmed)
            WKInterfaceDevice.current().play(.success)
            dismiss()
        }
        autoSaveTask = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func saveTask(title: String) {
        let task = LocalTask(title: title)
        task.needsTitleImprovement = true
        modelContext.insert(task)
        try? modelContext.save()
    }
}

#Preview {
    VoiceInputSheet(modelContext: try! ModelContainer(for: LocalTask.self).mainContext)
}
