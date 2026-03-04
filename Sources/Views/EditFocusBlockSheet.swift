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
        _startTime = State(initialValue: FocusBlock.snapToQuarterHour(block.startDate))
        _endTime = State(initialValue: FocusBlock.snapToQuarterHour(block.endDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) {
                            endTime = FocusBlock.normalizeEndTime(startTime: startTime, endTime: endTime)
                        }
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
            .onChange(of: startTime) { oldStart, newStart in
                let duration = endTime.timeIntervalSince(oldStart)
                endTime = newStart.addingTimeInterval(duration)
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
                        onSave(FocusBlock.snapToQuarterHour(startTime),
                               FocusBlock.snapToQuarterHour(endTime))
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
