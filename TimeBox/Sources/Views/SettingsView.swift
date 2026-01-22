import SwiftUI
@preconcurrency import EventKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCalendarID") private var selectedCalendarID: String = ""
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @State private var visibleCalendarIDs: Set<String> = []
    @State private var eventKitRepo = EventKitRepository()
    @State private var allCalendars: [EKCalendar] = []
    @State private var writableCalendars: [EKCalendar] = []

    var body: some View {
        NavigationStack {
            Form {
                // Section 0: Sound Settings
                Section {
                    Toggle(isOn: $soundEnabled) {
                        Text("Sound bei Block-Ende")
                    }
                    .accessibilityIdentifier("soundToggle")
                } header: {
                    Text("Benachrichtigungen")
                }

                // Section 1: Target Calendar
                Section {
                    Picker("Focus Blocks speichern in", selection: $selectedCalendarID) {
                        Text("Standard").tag("")
                        ForEach(writableCalendars, id: \.calendarIdentifier) { cal in
                            CalendarRow(calendar: cal)
                                .tag(cal.calendarIdentifier)
                        }
                    }
                } header: {
                    Text("Ziel-Kalender")
                } footer: {
                    Text("Neue Focus Blocks werden in diesem Kalender erstellt.")
                }

                // Section 2: Visible Calendars
                Section {
                    ForEach(allCalendars, id: \.calendarIdentifier) { cal in
                        Toggle(isOn: binding(for: cal.calendarIdentifier)) {
                            CalendarRow(calendar: cal)
                        }
                    }
                } header: {
                    Text("Sichtbare Kalender")
                } footer: {
                    Text("Nur ausgewählte Kalender werden in der Timeline angezeigt.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        saveVisibleCalendars()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCalendars()
            }
        }
    }

    private func binding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: { visibleCalendarIDs.contains(calendarID) },
            set: { isVisible in
                if isVisible {
                    visibleCalendarIDs.insert(calendarID)
                } else {
                    visibleCalendarIDs.remove(calendarID)
                }
            }
        )
    }

    private func loadCalendars() {
        allCalendars = eventKitRepo.getAllCalendars()
        writableCalendars = eventKitRepo.getWritableCalendars()

        // Load saved visible calendars or default to all
        if let saved = eventKitRepo.visibleCalendarIDs() {
            visibleCalendarIDs = Set(saved)
        } else {
            visibleCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
        }
    }

    private func saveVisibleCalendars() {
        UserDefaults.standard.set(Array(visibleCalendarIDs), forKey: "visibleCalendarIDs")
    }
}

// MARK: - Calendar Row

struct CalendarRow: View {
    let calendar: EKCalendar

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 12, height: 12)
            Text(calendar.title)
        }
    }
}
