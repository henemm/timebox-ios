import SwiftUI
import SwiftData

struct TaskSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let planItem: PlanItem

    @State private var suggestions: [SplitSuggestion] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else {
                    suggestionList
                }
            }
            .navigationTitle("Aufteilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .task {
            await loadSuggestions()
        }
    }

    // MARK: - Model

    struct SplitSuggestion: Identifiable {
        let id = UUID()
        var title: String
        var minutes: Int
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Text(planItem.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("splitOriginalTitle")

            ProgressView("Vorschläge werden generiert...")
                .accessibilityIdentifier("splitLoadingIndicator")
        }
        .padding()
    }

    // MARK: - Suggestion List

    private var suggestionList: some View {
        VStack(spacing: 0) {
            Text(planItem.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("splitOriginalTitle")

            List {
                ForEach($suggestions) { $suggestion in
                    HStack {
                        TextField("Sub-Task Titel", text: $suggestion.title)
                            .accessibilityIdentifier("splitSuggestionTitle_\(suggestionIndex(suggestion))")

                        Spacer()

                        Text("\(suggestion.minutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    suggestions.remove(atOffsets: indexSet)
                }

                Button {
                    suggestions.append(SplitSuggestion(title: "", minutes: 15))
                } label: {
                    Label("Hinzufügen", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("splitAddButton")
            }

            VStack(spacing: 12) {
                Text("Dein ursprünglicher Task wird als erledigt markiert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("splitInfoText")

                HStack(spacing: 12) {
                    Button {
                        Task { await regenerate() }
                    } label: {
                        Label("Nochmal", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("splitRegenerateButton")

                    Button {
                        createSubTasks()
                    } label: {
                        Label("Erstellen", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(suggestions.isEmpty || suggestions.allSatisfy { $0.title.isEmpty })
                    .accessibilityIdentifier("splitCreateButton")
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func suggestionIndex(_ suggestion: SplitSuggestion) -> Int {
        suggestions.firstIndex(where: { $0.id == suggestion.id }) ?? 0
    }

    // MARK: - Actions

    private func loadSuggestions() async {
        isLoading = true
        let result = await TaskSplitService.suggestSplit(for: planItem.title)
        suggestions = result.map { SplitSuggestion(title: $0.title, minutes: $0.minutes) }
        isLoading = false
    }

    private func regenerate() async {
        isLoading = true
        let result = await TaskSplitService.suggestSplit(for: planItem.title)
        suggestions = result.map { SplitSuggestion(title: $0.title, minutes: $0.minutes) }
        isLoading = false
    }

    private func createSubTasks() {
        let tuples = suggestions.map { (title: $0.title, minutes: $0.minutes) }
        TaskSplitService.persistSplit(
            originalTaskID: planItem.id,
            suggestions: tuples,
            taskType: planItem.taskType,
            modelContext: modelContext
        )
        dismiss()
    }
}
