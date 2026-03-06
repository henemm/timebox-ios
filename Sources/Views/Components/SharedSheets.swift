import SwiftUI

// MARK: - Create Focus Block Sheet (shared iOS + macOS)

struct CreateFocusBlockSheet: View {
    let slot: TimeSlot
    let onCreate: (Date, Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date
    @State private var endTime: Date

    init(slot: TimeSlot, onCreate: @escaping (Date, Date) -> Void) {
        self.slot = slot
        self.onCreate = onCreate
        _startTime = State(initialValue: FocusBlock.snapToQuarterHour(slot.startDate))
        _endTime = State(initialValue: FocusBlock.snapToQuarterHour(slot.endDate))
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            formContent
                .navigationTitle("FocusBlox erstellen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        createButton
                    }
                }
        }
        .presentationDetents([.medium])
        #else
        VStack(spacing: 20) {
            Text("FocusBlox erstellen")
                .font(.headline)
            formContent
                .formStyle(.grouped)
            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                createButton
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 280)
        #endif
    }

    private var formContent: some View {
        Form {
            DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
            DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                .onChange(of: endTime) {
                    endTime = FocusBlock.normalizeEndTime(startTime: startTime, endTime: endTime)
                }
            Text("Dauer: \(durationText)")
                .foregroundStyle(.secondary)
        }
        .onChange(of: startTime) { oldStart, newStart in
            let duration = endTime.timeIntervalSince(oldStart)
            endTime = newStart.addingTimeInterval(duration)
        }
    }

    private var createButton: some View {
        Button("Erstellen") {
            onCreate(FocusBlock.snapToQuarterHour(startTime),
                     FocusBlock.snapToQuarterHour(endTime))
            dismiss()
        }
        .disabled(endTime <= startTime)
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

// MARK: - Event Category Sheet (shared iOS + macOS)

struct EventCategorySheet: View {
    let event: CalendarEvent
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        NavigationStack {
            List {
                categoryList
            }
            .navigationTitle("Kategorie wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        #else
        VStack(spacing: 16) {
            Text("Kategorie wählen")
                .font(.headline)

            Text(event.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            VStack(spacing: 8) {
                categoryList
            }

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 300)
        #endif
    }

    @ViewBuilder
    private var categoryList: some View {
        ForEach(TaskCategory.allCases, id: \.self) { category in
            Button {
                onSelect(category.rawValue)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                        .frame(width: 24)

                    Text(category.displayName)
                        .foregroundStyle(.primary)

                    Spacer()

                    if event.category == category.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
                #if os(macOS)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(event.category == category.rawValue
                              ? category.color.opacity(0.1)
                              : Color.clear)
                )
                #endif
            }
            #if os(macOS)
            .buttonStyle(.plain)
            #endif
            .accessibilityIdentifier("categoryOption_\(category.rawValue)")
        }

        if event.category != nil {
            #if os(macOS)
            Divider()
            #endif
            Button(role: .destructive) {
                onSelect(nil)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                        #if os(iOS)
                        .frame(width: 30)
                        #endif

                    Text("Kategorie entfernen")
                        .foregroundStyle(.red)
                }
            }
            #if os(macOS)
            .buttonStyle(.plain)
            #endif
        }
    }
}
