import AppIntents
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
    @AppStorage("taskSuggestionsEnabled") private var taskSuggestionsEnabled: Bool = true
    @AppStorage("dueDateMorningReminderEnabled") private var dueDateMorningReminderEnabled: Bool = true
    @AppStorage("dueDateMorningReminderHour") private var dueDateMorningReminderHour: Int = 9
    @AppStorage("dueDateMorningReminderMinute") private var dueDateMorningReminderMinute: Int = 0
    @AppStorage("dueDateAdvanceReminderEnabled") private var dueDateAdvanceReminderEnabled: Bool = false
    @AppStorage("dueDateAdvanceReminderMinutes") private var dueDateAdvanceReminderMinutes: Int = 60
    @AppStorage("notificationProfile") private var notificationProfileRaw: String = "balanced"
    @AppStorage("morningReminderHour") private var morningReminderHour: Int = 8
    @AppStorage("morningReminderMinute") private var morningReminderMinute: Int = 0
    @AppStorage("eveningReflectionHour") private var eveningReflectionHour: Int = 20
    @AppStorage("eveningReflectionMinute") private var eveningReflectionMinute: Int = 0
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.modelContext) private var modelContext
    @State private var isEnriching = false
    @State private var enrichResult: Int?
    @State private var visibleCalendarIDs: Set<String> = []
    @State private var visibleReminderListIDs: Set<String> = []
    @State private var allCalendars: [EKCalendar] = []
    @State private var writableCalendars: [EKCalendar] = []
    @State private var allReminderLists: [ReminderListInfo] = []
    @AppStorage("siriTipCompleteTaskVisible") private var showCompleteTaskTip = true
    @AppStorage("taskDebugModeEnabled") private var taskDebugModeEnabled: Bool = false
    @AppStorage("backlogStaleAgeDays") private var backlogStaleAgeDays: Int = 14
    @AppStorage("backlogStaleRescheduleCount") private var backlogStaleRescheduleCount: Int = 3
    @AppStorage("useCoachTabLayout") private var useCoachTabLayout: Bool = false
    @State private var showLifecycleLogSheet = false
    @State private var showClearLogConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // Section: Notification Profile
                Section {
                    Picker("Benachrichtigungsprofil", selection: $notificationProfileRaw) {
                        Text("Leise").tag("quiet")
                        Text("Ausgeglichen").tag("balanced")
                        Text("Aktiv").tag("active")
                    }
                    .accessibilityIdentifier("notificationProfilePicker")
                } header: {
                    Text("Profil")
                } footer: {
                    Text("Leise — Nur Focus-Block-Timer (5 Min vorher + Ende).\nAusgeglichen — Timer + Frist-Erinnerungen + Dein Tag + Abend-Reflexion.\nAktiv — Alles oben.")
                }

                if notificationProfileRaw != "quiet" {
                    Section {
                        DatePicker("Dein Tag", selection: morningReminderTimeBinding, displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("morningReminderTimePicker")
                        DatePicker("Abend-Reflexion", selection: eveningReflectionTimeBinding, displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("eveningReflectionTimePicker")
                    } header: {
                        Text("Erinnerungszeiten")
                    } footer: {
                        Text("Uhrzeiten für den täglichen Dein Tag und die Abend-Reflexion.")
                    }
                }

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

                // Section: Backlog Hygiene
                Section {
                    Stepper("Nach \(AppSettings.shared.backlogStaleAgeDays) Tagen", value: $backlogStaleAgeDays, in: 7...90)
                        .accessibilityIdentifier("staleAgeDaysStepper")
                    Stepper("Nach \(AppSettings.shared.backlogStaleRescheduleCount)× verschieben", value: $backlogStaleRescheduleCount, in: 1...10)
                        .accessibilityIdentifier("staleRescheduleCountStepper")
                } header: {
                    Text("Backlog-Hygiene")
                } footer: {
                    Text("Tasks werden zum Aufräumen vorgeschlagen wenn sie zu lange im Backlog liegen oder zu oft verschoben wurden.")
                }

                // Section: Automatic Task Analysis (always visible — deterministic steps work without AI)
                Section {
                    Toggle("Task-Vorschläge", isOn: $taskSuggestionsEnabled)
                        .accessibilityIdentifier("taskSuggestionsToggle")

                    if SmartTaskEnrichmentService.isAvailable {
                        Toggle("KI Task-Enrichment", isOn: $aiScoringEnabled)
                            .accessibilityIdentifier("aiScoringToggle")
                    }

                    Button {
                        Task {
                            isEnriching = true
                            enrichResult = nil
                            let service = SmartTaskEnrichmentService(modelContext: modelContext)
                            let count = await service.reanalyzeAllTasks()
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
                                    .accessibilityIdentifier("enrichResultLabel")
                            }
                        }
                    }
                    .disabled(isEnriching)
                    .accessibilityIdentifier("batchEnrichButton")
                } header: {
                    Text("Automatische Task-Analyse")
                } footer: {
                    Text("Bereinigt Titel, extrahiert Datumsangaben und ergänzt fehlende Attribute (Wichtigkeit, Dringlichkeit, Kategorie, Dauer) automatisch.")
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

                // ITB-G4: Siri Tip for task completion shortcut
                Section {
                    SiriTipView(intent: CompleteTaskIntent(), isVisible: $showCompleteTaskTip)
                } header: {
                    Text("Siri Shortcuts")
                }

                // Section: Info
                Section {
                    LabeledContent("Version") {
                        Text(BuildInfo.versionDisplay)
                    }

                    LabeledContent("Build") {
                        Text(BuildInfo.build)
                    }
                } header: {
                    Text("Info")
                }

                // Section: Developer Tools (below Info)
                Section {
                    Toggle("Coach-Tab Layout", isOn: $useCoachTabLayout)
                        .accessibilityIdentifier("coachTabLayoutToggle")

                    Toggle("Task Debug Mode", isOn: $taskDebugModeEnabled)
                        .accessibilityIdentifier("taskDebugModeToggle")

                    if taskDebugModeEnabled {
                        Button {
                            showLifecycleLogSheet = true
                        } label: {
                            Text("Lifecycle Log anzeigen")
                        }
                        .accessibilityIdentifier("showLifecycleLogButton")

                        Button(role: .destructive) {
                            showClearLogConfirmation = true
                        } label: {
                            Text("Log löschen")
                        }
                        .accessibilityIdentifier("clearLifecycleLogButton")
                        .confirmationDialog("Lifecycle Log löschen?", isPresented: $showClearLogConfirmation) {
                            Button("Löschen", role: .destructive) {
                                TaskLifecycleLogger.shared.clearLog()
                            }
                        }
                    }
                } header: {
                    Text("Entwickler")
                } footer: {
                    Text("Zeichnet alle Task-Änderungen (Erstellen, Bearbeiten, Löschen) in eine Log-Datei auf.")
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
            .onChange(of: notificationProfileRaw) { _, _ in
                Task {
                    await SmartNotificationEngine.reconcile(
                        reason: .profileChanged,
                        context: modelContext,
                        eventKitRepo: eventKitRepo
                    )
                }
            }
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
            .sheet(isPresented: $showLifecycleLogSheet) {
                NavigationStack {
                    ScrollView {
                        let logContent = TaskLifecycleLogger.shared.getLog()
                        Text(logContent.isEmpty ? "Noch keine Einträge." : logContent)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .accessibilityIdentifier("lifecycleLogContent")
                    }
                    .navigationTitle("Lifecycle Log")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Schließen") {
                                showLifecycleLogSheet = false
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            ShareLink(item: TaskLifecycleLogger.shared.getLog())
                        }
                    }
                }
            }
        }
    }


    private var morningReminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = morningReminderHour
                comps.minute = morningReminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                morningReminderHour = comps.hour ?? 8
                morningReminderMinute = comps.minute ?? 0
            }
        )
    }

    private var eveningReflectionTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = eveningReflectionHour
                comps.minute = eveningReflectionMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                eveningReflectionHour = comps.hour ?? 20
                eveningReflectionMinute = comps.minute ?? 0
            }
        )
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

