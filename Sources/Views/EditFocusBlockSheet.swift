import SwiftUI

struct EditFocusBlockSheet: View {
    let block: FocusBlock
    let onSave: (Date, Date) -> Void
    let onDelete: () -> Void

    @State private var startTime: Date
    @State private var endTime: Date
    @Environment(\.dismiss) private var dismiss

    init(block: FocusBlock, onSave: @escaping (Date, Date) -> Void, onDelete: @escaping () -> Void) {
        self.block = block
        self.onSave = onSave
        self.onDelete = onDelete
        _startTime = State(initialValue: block.startDate)
        _endTime = State(initialValue: block.endDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    Text("Dauer: \(durationText)")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Block löschen", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Block bearbeiten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(startTime, endTime)
                        dismiss()
                    }
                    .disabled(endTime <= startTime)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var durationText: String {
        let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
        if minutes < 60 {
            return "\(minutes) Min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) Std"
            } else {
                return "\(hours) Std \(remainingMinutes) Min"
            }
        }
    }
}
