//
//  MacSettingsView.swift
//  FocusBloxMac
//
//  Settings/Preferences for macOS App
//

import SwiftUI
import EventKit

struct MacSettingsView: View {
    // MARK: - AppStorage

    @AppStorage("selectedCalendarID") private var selectedCalendarID: String = ""
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("warningEnabled") private var warningEnabled: Bool = true
    @AppStorage("warningTiming") private var warningTimingRaw: Int = 80
    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = true
    @AppStorage("defaultTaskDuration") private var defaultTaskDuration: Int = 15

    // MARK: - State

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
                            MacCalendarRow(calendar: cal)
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
                        Toggle(isOn: calendarBinding(for: cal.calendarIdentifier)) {
                            MacCalendarRow(calendar: cal)
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
                Toggle("Mit Apple Erinnerungen synchronisieren", isOn: $remindersSyncEnabled)
                    .accessibilityIdentifier("remindersSyncToggle")
            } header: {
                Text("Synchronisation")
            } footer: {
                Text("Tasks aus Apple Erinnerungen werden automatisch in den Backlog importiert.")
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
                        Toggle(isOn: reminderListBinding(for: list.id)) {
                            MacReminderListRow(list: list)
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
        }
        .formStyle(.grouped)
        .padding()
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

    // MARK: - Bindings

    private func calendarBinding(for calendarID: String) -> Binding<Bool> {
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

    private func reminderListBinding(for listID: String) -> Binding<Bool> {
        Binding(
            get: { visibleReminderListIDs.contains(listID) },
            set: { isVisible in
                if isVisible {
                    visibleReminderListIDs.insert(listID)
                } else {
                    visibleReminderListIDs.remove(listID)
                }
            }
        )
    }

    // MARK: - Save

    private func saveSettings() {
        UserDefaults.standard.set(Array(visibleCalendarIDs), forKey: "visibleCalendarIDs")
        UserDefaults.standard.set(Array(visibleReminderListIDs), forKey: "visibleReminderListIDs")
    }
}

// MARK: - Calendar Row

struct MacCalendarRow: View {
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

// MARK: - Reminder List Row

struct MacReminderListRow: View {
    let list: ReminderListInfo

    var body: some View {
        HStack(spacing: 8) {
            if let hex = list.colorHex {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 12, height: 12)
            }
            Text(list.title)
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (128, 128, 128)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

#Preview {
    MacSettingsView()
}
