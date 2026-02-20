//
//  MacSettingsView.swift
//  FocusBloxMac
//
//  Settings/Preferences for macOS App
//

import SwiftUI
import SwiftData
import EventKit

struct MacSettingsView: View {
    // MARK: - AppStorage

    @AppStorage("selectedCalendarID") private var selectedCalendarID: String = ""
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("warningEnabled") private var warningEnabled: Bool = true
    @AppStorage("warningTiming") private var warningTimingRaw: Int = 80
    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = true
    @AppStorage("remindersMarkCompleteOnImport") private var remindersMarkCompleteOnImport: Bool = true
    @AppStorage("defaultTaskDuration") private var defaultTaskDuration: Int = 15
    @AppStorage("aiScoringEnabled") private var aiScoringEnabled: Bool = true
    @AppStorage("dueDateMorningReminderEnabled") private var dueDateMorningReminderEnabled: Bool = true
    @AppStorage("dueDateMorningReminderHour") private var dueDateMorningReminderHour: Int = 9
    @AppStorage("dueDateMorningReminderMinute") private var dueDateMorningReminderMinute: Int = 0
    @AppStorage("dueDateAdvanceReminderEnabled") private var dueDateAdvanceReminderEnabled: Bool = false
    @AppStorage("dueDateAdvanceReminderMinutes") private var dueDateAdvanceReminderMinutes: Int = 60

    // MARK: - State

    @Environment(\.modelContext) private var modelContext
    @State private var isEnriching = false
    @State private var enrichResult: Int?
    @State private var visibleCalendarIDs: Set<String> = []
    @State private var visibleReminderListIDs: Set<String> = []
    @State private var allCalendars: [EKCalendar] = []
    @State private var writableCalendars: [EKCalendar] = []
    @State private var allReminderLists: [ReminderListInfo] = []
    @State private var hasCalendarAccess = false
    @State private var hasReminderAccess = false

    @Environment(\.eventKitRepository) private var eventKitRepo

    var body: some View {
        TabView {
            // MARK: - General Tab
            generalTab
                .tabItem {
                    Label("Allgemein", systemImage: "gearshape")
                }

            // MARK: - Calendar Tab
            calendarTab
                .tabItem {
                    Label("Kalender", systemImage: "calendar")
                }

            // MARK: - Reminders Tab
            remindersTab
                .tabItem {
                    Label("Erinnerungen", systemImage: "checklist")
                }

            // MARK: - Notifications Tab
            notificationsTab
                .tabItem {
                    Label("Mitteilungen", systemImage: "bell")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            Task {
                await loadData()
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
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

            // Apple Intelligence (only visible when available)
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
                                        .controlSize(.small)
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

            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }

                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            } header: {
                Text("Info")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Calendar Tab

    private var calendarTab: some View {
        Form {
            if !hasCalendarAccess {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Kein Zugriff auf Kalender")
                        Spacer()
                        Button("Zugriff anfordern") {
                            Task { await requestCalendarAccess() }
                        }
                    }
                }
            } else {
                Section {
                    Picker("Focus Blocks speichern in", selection: $selectedCalendarID) {
                        Text("Standard-Kalender").tag("")
                        ForEach(writableCalendars, id: \.calendarIdentifier) { cal in
                            CalendarRow(calendar: cal)
                                .tag(cal.calendarIdentifier)
                        }
                    }
                    .accessibilityIdentifier("targetCalendarPicker")
                } header: {
                    Text("Ziel-Kalender")
                } footer: {
                    Text("Neue Focus Blocks werden in diesem Kalender erstellt.")
                }

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
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: visibleCalendarIDs) { _, _ in
            saveSettings()
        }
    }

    // MARK: - Reminders Tab

    private var remindersTab: some View {
        Form {
            Section {
                Toggle("Erinnerungen importieren", isOn: $remindersSyncEnabled)
                    .accessibilityIdentifier("remindersSyncToggle")

                if remindersSyncEnabled {
                    Toggle("Nach Import abhaken", isOn: $remindersMarkCompleteOnImport)
                        .accessibilityIdentifier("remindersMarkCompleteToggle")
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Ermöglicht manuellen Import von Apple Erinnerungen als lokale Tasks. Importierte Erinnerungen können optional in Apple Erinnerungen als erledigt markiert werden.")
            }

            if !hasReminderAccess && remindersSyncEnabled {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Kein Zugriff auf Erinnerungen")
                        Spacer()
                        Button("Zugriff anfordern") {
                            Task { await requestReminderAccess() }
                        }
                    }
                }
            }

            if remindersSyncEnabled && hasReminderAccess && !allReminderLists.isEmpty {
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
        .formStyle(.grouped)
        .padding()
        .onChange(of: visibleReminderListIDs) { _, _ in
            saveSettings()
        }
    }

    // MARK: - Notifications Tab

    private var notificationsTab: some View {
        Form {
            Section {
                Toggle("Sound bei Block-Ende", isOn: $soundEnabled)
                    .accessibilityIdentifier("soundToggle")
            } header: {
                Text("Benachrichtigungen")
            }

            Section {
                Toggle("Vorwarnung aktivieren", isOn: $warningEnabled)
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
                Text("Sound und Vibration vor Block-Ende als Erinnerung.")
            }

            Section {
                Toggle("Morgens erinnern", isOn: $dueDateMorningReminderEnabled)
                    .accessibilityIdentifier("morningReminderToggle")

                if dueDateMorningReminderEnabled {
                    DatePicker(
                        "Uhrzeit",
                        selection: morningTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("morningTimePicker")
                }

                Toggle("Vorab erinnern", isOn: $dueDateAdvanceReminderEnabled)
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
        }
        .formStyle(.grouped)
        .padding()
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

    // MARK: - Data Loading

    private func loadData() async {
        // Check calendar access
        do {
            hasCalendarAccess = try await eventKitRepo.requestAccess()
            if hasCalendarAccess {
                allCalendars = eventKitRepo.getAllCalendars()
                writableCalendars = eventKitRepo.getWritableCalendars()
            }
        } catch {
            hasCalendarAccess = false
        }

        // Check reminder access
        do {
            hasReminderAccess = try await eventKitRepo.requestReminderAccess()
            if hasReminderAccess {
                allReminderLists = eventKitRepo.getAllReminderLists()
            }
        } catch {
            hasReminderAccess = false
        }

        // Load saved visible calendars
        if let saved = UserDefaults.standard.array(forKey: "visibleCalendarIDs") as? [String] {
            visibleCalendarIDs = Set(saved)
        } else {
            visibleCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
        }

        // Load saved visible reminder lists
        if let savedReminders = UserDefaults.standard.array(forKey: "visibleReminderListIDs") as? [String] {
            visibleReminderListIDs = Set(savedReminders)
        } else {
            visibleReminderListIDs = Set(allReminderLists.map(\.id))
        }
    }

    private func requestCalendarAccess() async {
        do {
            hasCalendarAccess = try await eventKitRepo.requestAccess()
            if hasCalendarAccess {
                allCalendars = eventKitRepo.getAllCalendars()
                writableCalendars = eventKitRepo.getWritableCalendars()
                visibleCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
            }
        } catch {
            hasCalendarAccess = false
        }
    }

    private func requestReminderAccess() async {
        do {
            hasReminderAccess = try await eventKitRepo.requestReminderAccess()
            if hasReminderAccess {
                allReminderLists = eventKitRepo.getAllReminderLists()
                visibleReminderListIDs = Set(allReminderLists.map(\.id))
            }
        } catch {
            hasReminderAccess = false
        }
    }

    // MARK: - Save

    private func saveSettings() {
        UserDefaults.standard.set(Array(visibleCalendarIDs), forKey: "visibleCalendarIDs")
        UserDefaults.standard.set(Array(visibleReminderListIDs), forKey: "visibleReminderListIDs")
    }
}

#Preview {
    MacSettingsView()
}
