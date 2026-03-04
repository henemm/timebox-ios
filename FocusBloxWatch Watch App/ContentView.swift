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
    @State private var hasAutoOpened = false

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
            .onAppear {
                if !hasAutoOpened {
                    hasAutoOpened = true
                    showingInput = true
                }
            }
            .sheet(isPresented: $showingInput) {
                VoiceInputSheet(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
}
