import SwiftUI
import SwiftData

struct TaskSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let planItem: PlanItem

    @State private var suggestions: [SplitSuggestion] = []
    @State private var isLoading = true
    @State private var durationPickerIndex: Int?
    @State private var showRegenerateAlert = false
    @State private var initialSuggestions: [SplitSuggestion] = []

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

    struct SplitSuggestion: Identifiable, Equatable {
        let id: String
        var title: String
        var minutes: Int

        init(title: String, minutes: Int) {
            self.id = UUID().uuidString
            self.title = title
            self.minutes = minutes
        }
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
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    BacklogRow(
                        item: makePlanItem(from: suggestion),
                        onDurationTap: {
                            durationPickerIndex = index
                        },
                        onDeleteTap: suggestions.count > 1 ? {
                            withAnimation {
                                suggestions.removeAll { $0.id == suggestion.id }
                            }
                        } : nil,
                        onTitleSave: { newTitle in
                            if let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                                suggestions[idx].title = newTitle
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if suggestions.count > 1 {
                            Button(role: .destructive) {
                                withAnimation {
                                    suggestions.removeAll { $0.id == suggestion.id }
                                }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    suggestions.append(SplitSuggestion(title: "", minutes: planItem.estimatedDuration ?? 15))
                } label: {
                    Label("Hinzufügen", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("splitAddButton")
            }
            .listStyle(.plain)

            VStack(spacing: 12) {
                Text("Dein ursprünglicher Task wird als erledigt markiert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("splitInfoText")

                HStack(spacing: 12) {
                    Button {
                        if hasChanges {
                            showRegenerateAlert = true
                        } else {
                            Task { await regenerate() }
                        }
                    } label: {
                        Label("Neu generieren", systemImage: "arrow.clockwise")
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
        .sheet(isPresented: Binding(
            get: { durationPickerIndex != nil },
            set: { if !$0 { durationPickerIndex = nil } }
        )) {
            if let idx = durationPickerIndex {
                DurationPicker(currentDuration: suggestions[idx].minutes) { selected in
                    if let selected {
                        suggestions[idx].minutes = selected
                    }
                    durationPickerIndex = nil
                }
            }
        }
        .alert("Änderungen verwerfen?", isPresented: $showRegenerateAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Neu generieren", role: .destructive) {
                Task { await regenerate() }
            }
        } message: {
            Text("Deine Anpassungen gehen verloren, wenn du neue Vorschläge generierst.")
        }
    }

    // MARK: - PlanItem Builder

    private func makePlanItem(from suggestion: SplitSuggestion) -> PlanItem {
        let temp = LocalTask(title: suggestion.title)
        temp.uuid = UUID(uuidString: suggestion.id) ?? UUID()
        temp.estimatedDuration = suggestion.minutes
        temp.taskType = planItem.taskType
        temp.importance = planItem.importance
        temp.urgency = planItem.urgency
        temp.tags = planItem.tags.isEmpty ? nil : planItem.tags
        temp.dueDate = planItem.dueDate
        return PlanItem(localTask: temp)
    }

    // MARK: - Change Detection

    private var hasChanges: Bool {
        guard suggestions.count == initialSuggestions.count else { return true }
        for (current, initial) in zip(suggestions, initialSuggestions) {
            if current.title != initial.title || current.minutes != initial.minutes {
                return true
            }
        }
        return false
    }

    // MARK: - Actions

    private func loadSuggestions() async {
        isLoading = true
        let result = await TaskSplitService.suggestSplit(for: planItem.title)
        suggestions = result.map { SplitSuggestion(title: $0.title, minutes: $0.minutes) }
        initialSuggestions = suggestions.map { SplitSuggestion(title: $0.title, minutes: $0.minutes) }
        isLoading = false
    }

    private func regenerate() async {
        isLoading = true
        let result = await TaskSplitService.suggestSplit(for: planItem.title)
        suggestions = result.map { SplitSuggestion(title: $0.title, minutes: $0.minutes) }
        initialSuggestions = suggestions.map { SplitSuggestion(title: $0.title, minutes: $0.minutes) }
        isLoading = false
    }

    private func createSubTasks() {
        let tuples = suggestions.map { (title: $0.title, minutes: $0.minutes) }
        TaskSplitService.persistSplit(
            originalTaskID: planItem.id,
            suggestions: tuples,
            taskType: planItem.taskType,
            importance: planItem.importance,
            urgency: planItem.urgency,
            tags: planItem.tags,
            dueDate: planItem.dueDate,
            modelContext: modelContext
        )
        dismiss()
    }
}

