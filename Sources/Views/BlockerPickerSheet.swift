import SwiftUI

/// Searchable sheet for selecting a blocker (parent) task.
/// Shared between iOS and macOS.
struct BlockerPickerSheet: View {
    let candidates: [LocalTask]
    @Binding var selectedBlockerID: String?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // "Keine" option — always visible
                Button {
                    selectedBlockerID = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("Keine")
                        Spacer()
                        if selectedBlockerID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .accessibilityIdentifier("blockerOption_none")

                ForEach(filteredCandidates, id: \.id) { task in
                    Button {
                        selectedBlockerID = task.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(task.title)
                                .lineLimit(1)
                            Spacer()
                            if selectedBlockerID == task.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .accessibilityIdentifier("blockerOption_\(task.id)")
                }
            }
            .navigationTitle("Abhängig von")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Task durchsuchen")
        }
    }

    private var filteredCandidates: [LocalTask] {
        let sorted = candidates.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { task in
            task.title.localizedCaseInsensitiveContains(searchText)
        }
    }
}
