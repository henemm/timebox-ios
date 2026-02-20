import SwiftUI
import SwiftData
@preconcurrency import EventKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCalendarID") private var selectedCalendarID: String = ""
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("warningEnabled") private var warningEnabled: Bool = true
    @AppStorage("warningTiming") private var warningTimingRaw: Int = WarningTiming.standard.rawValue
    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = false
    @AppStorage("remindersMarkCompleteOnImport") private var remindersMarkCompleteOnImport: Bool = true
    @AppStorage("defaultTaskDuration") private var defaultTaskDuration: Int = 15
    @AppStorage("aiScoringEnabled") private var aiScoringEnabled: Bool = true
    @AppStorage("dueDateMorningReminderEnabled") private var dueDateMorningReminderEnabled: Bool = true
    @AppStorage("dueDateMorningReminderHour") private var dueDateMorningReminderHour: Int = 9
    @AppStorage("dueDateMorningReminderMinute") private var dueDateMorningReminderMinute: Int = 0
    @AppStorage("dueDateAdvanceReminderEnabled") private var dueDateAdvanceReminderEnabled: Bool = false
    @AppStorage("dueDateAdvanceReminderMinutes") private var dueDateAdvanceReminderMinutes: Int = 60
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.modelContext) private var modelContext
    @State private var isEnriching = false
    @State private var enrichResult: Int?
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

                // Section: Due Date Reminders
                Section {
                    Toggle(isOn: $dueDateMorningReminderEnabled) {
                        Text("Morgens erinnern")
                    }
                    .accessibilityIdentifier("morningReminderToggle")

                    if dueDateMorningReminderEnabled {
                        DatePicker(
                            "Uhrzeit",
                            selection: morningTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .accessibilityIdentifier("morningTimePicker")
                    }

                    Toggle(isOn: $dueDateAdvanceReminderEnabled) {
                        Text("Vorab erinnern")
                    }
                    .accessibilityIdentifier("advanceReminderToggle")

                    if dueDateAdvanceReminderEnabled {
                        Picker("Vorlaufzeit", selection: $dueDateAdvanceReminderMinutes) {
                            Text("15 Minuten").tag(15)
                            Text("30 Minuten").tag(30)
                            Text("1 Stunde").tag(60)
                            Text("2 Stunden").tag(120)
                            Text("1 Tag").tag(1440)
                        }
                        .accessibilityIdentifier("advanceDurationPicker")
                    }
                } header: {
                    Text("Frist-Erinnerungen")
                } footer: {
                    Text("Push-Benachrichtigungen für Tasks mit Fälligkeitsdatum.")
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
                if SmartTaskEnrichmentService.isAvailable {
                    Section {
                        Toggle("KI Task-Enrichment", isOn: $aiScoringEnabled)
                            .accessibilityIdentifier("aiScoringToggle")

                        if aiScoringEnabled {
                            Button {
                                Task {
                                    isEnriching = true
                                    enrichResult = nil
                                    let service = SmartTaskEnrichmentService(modelContext: modelContext)
                                    let count = await service.enrichAllTbdTasks()
                                    enrichResult = count
                                    isEnriching = false
                                }
                            } label: {
                                HStack {
                                    Text("Bestehende Tasks analysieren")
                                    Spacer()
                                    if isEnriching {
                                        ProgressView()
                                    } else if let result = enrichResult {
                                        Text("\(result) aktualisiert")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(isEnriching)
                            .accessibilityIdentifier("batchEnrichButton")
                        }
                    } header: {
                        Text("Apple Intelligence")
                    } footer: {
                        Text("Ergänzt fehlende Task-Attribute (Wichtigkeit, Dringlichkeit, Kategorie) automatisch aus dem Titel.")
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

                // Section 3: Apple Reminders Import
                Section {
                    Toggle(isOn: $remindersSyncEnabled) {
                        Text("Erinnerungen importieren")
                    }
                    .accessibilityIdentifier("remindersSyncToggle")

                    if remindersSyncEnabled {
                        Toggle(isOn: $remindersMarkCompleteOnImport) {
                            Text("Nach Import abhaken")
                        }
                        .accessibilityIdentifier("remindersMarkCompleteToggle")
                    }
                } header: {
                    Text("Apple Erinnerungen")
                } footer: {
                    Text("Ermöglicht manuellen Import von Apple Erinnerungen als lokale Tasks. Importierte Erinnerungen können optional in Apple Erinnerungen als erledigt markiert werden.")
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


    private var morningTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = dueDateMorningReminderHour
                comps.minute = dueDateMorningReminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                dueDateMorningReminderHour = comps.hour ?? 9
                dueDateMorningReminderMinute = comps.minute ?? 0
            }
        )
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

