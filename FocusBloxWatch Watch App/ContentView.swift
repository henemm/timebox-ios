import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<LocalTask> { !$0.isCompleted },
        sort: \LocalTask.createdAt,
        order: .reverse
    ) private var recentTasks: [LocalTask]

    @State private var showingInput = false
    @State private var showingConfirmation = false
    @State private var pendingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showingInput = true
                } label: {
                    Label("Task hinzufuegen", systemImage: "plus.circle.fill")
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("addTaskButton")

                if !recentTasks.isEmpty {
                    Section("Letzte Tasks") {
                        ForEach(recentTasks.prefix(5)) { task in
                            Text(task.title)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("FocusBlox")
            .sheet(isPresented: $showingInput, onDismiss: {
                if pendingConfirmation {
                    pendingConfirmation = false
                    showingConfirmation = true
                }
            }) {
                VoiceInputSheet { title in
                    saveTask(title: title)
                    pendingConfirmation = true
                }
            }
            .sheet(isPresented: $showingConfirmation) {
                ConfirmationView()
            }
        }
    }

    private func saveTask(title: String) {
        let task = LocalTask(title: title)
        modelContext.insert(task)
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
}
