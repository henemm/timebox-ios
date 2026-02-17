import SwiftUI
@preconcurrency import EventKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCalendarID") private var selectedCalendarID: String = ""
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("warningEnabled") private var warningEnabled: Bool = true
    @AppStorage("warningTiming") private var warningTimingRaw: Int = WarningTiming.standard.rawValue
    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = false
    @AppStorage("defaultTaskDuration") private var defaultTaskDuration: Int = 15
    @AppStorage("aiScoringEnabled") private var aiScoringEnabled: Bool = false
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var visibleCalendarIDs: Set<String> = []
    @State private var visibleReminderListIDs: Set<String> = []
    @State private var allCalendars: [EKCalendar] = []
    @State private var writableCalendars: [EKCalendar] = []
    @State private var allReminderLists: [ReminderListInfo] = []

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

                // Section 0.5: Warning Settings
                Section {
                    Toggle(isOn: $warningEnabled) {
                        Text("Vorwarnung")
                    }
                    .accessibilityIdentifier("warningToggle")

                    if warningEnabled {
                        Picker("Zeitpunkt", selection: $warningTimingRaw) {
                            ForEach(WarningTiming.allCases, id: \.rawValue) { timing in
                                Text(timing.label).tag(timing.rawValue)
                            }
                        }
                        .accessibilityIdentifier("warningTimingPicker")
                    }
                } header: {
                    Text("Vorwarnung")
                } footer: {
                    Text("Sound und Vibration vor Block-Ende.")
                }

                // Section: Task Settings
                Section {
                    Picker("Standard-Dauer für neue Tasks", selection: $defaultTaskDuration) {
                        Text("5 Minuten").tag(5)
                        Text("10 Minuten").tag(10)
                        Text("15 Minuten").tag(15)
                        Text("30 Minuten").tag(30)
                        Text("60 Minuten").tag(60)
                    }
                    .accessibilityIdentifier("defaultDurationPicker")
                } header: {
                    Text("Tasks")
                }

                // Section: Apple Intelligence (only visible when available)
                if AITaskScoringService.isAvailable {
                    Section {
                        Toggle("KI Task-Scoring", isOn: $aiScoringEnabled)
                            .accessibilityIdentifier("aiScoringToggle")
                    } header: {
                        Text("Apple Intelligence")
                    } footer: {
                        Text("Bewertet und sortiert Tasks automatisch nach Priorität und Energie-Level.")
                    }
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
                        Toggle(isOn: setMembershipBinding(for: cal.calendarIdentifier, in: $visibleCalendarIDs)) {
                            CalendarRow(calendar: cal)
                        }
                    }
                } header: {
                    Text("Sichtbare Kalender")
                } footer: {
                    Text("Nur ausgewählte Kalender werden in der Timeline angezeigt.")
                }

                // Section 3: Apple Reminders Sync
                Section {
                    Toggle(isOn: $remindersSyncEnabled) {
                        Text("Mit Erinnerungen synchronisieren")
                    }
                    .accessibilityIdentifier("remindersSyncToggle")
                } header: {
                    Text("Apple Erinnerungen")
                } footer: {
                    Text("Tasks aus Apple Erinnerungen werden in den Backlog importiert.")
                }

                // Section 4: Visible Reminder Lists (only shown when sync enabled)
                if remindersSyncEnabled && !allReminderLists.isEmpty {
                    Section {
                        ForEach(allReminderLists) { list in
                            Toggle(isOn: setMembershipBinding(for: list.id, in: $visibleReminderListIDs)) {
                                ReminderListRow(list: list)
                            }
                            .accessibilityIdentifier("reminderList_\(list.title)")
                        }
                    } header: {
                        Text("Sichtbare Erinnerungslisten")
                    } footer: {
                        Text("Nur ausgewählte Listen werden in den Backlog importiert.")
                    }
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


    private func loadCalendars() {
        allCalendars = eventKitRepo.getAllCalendars()
        writableCalendars = eventKitRepo.getWritableCalendars()
        allReminderLists = eventKitRepo.getAllReminderLists()

        // Load saved visible calendars or default to all
        if let saved = UserDefaults.standard.array(forKey: "visibleCalendarIDs") as? [String] {
            visibleCalendarIDs = Set(saved)
        } else {
            visibleCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
        }

        // Load saved visible reminder lists or default to all
        if let savedReminders = UserDefaults.standard.array(forKey: "visibleReminderListIDs") as? [String] {
            visibleReminderListIDs = Set(savedReminders)
        } else {
            visibleReminderListIDs = Set(allReminderLists.map(\.id))
        }
    }

    private func saveVisibleCalendars() {
        UserDefaults.standard.set(Array(visibleCalendarIDs), forKey: "visibleCalendarIDs")
        UserDefaults.standard.set(Array(visibleReminderListIDs), forKey: "visibleReminderListIDs")
        UserDefaults.standard.synchronize()
    }
}

