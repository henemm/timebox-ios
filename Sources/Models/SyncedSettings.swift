import Foundation
import EventKit

/// Synchronisiert App-Einstellungen zwischen Geraeten via iCloud KV Store.
/// Kalender-IDs sind geraete-spezifisch, daher wird nach NAME gematchted.
@MainActor
final class SyncedSettings {
    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private let eventStore = EKEventStore()

    // MARK: - Synced Keys (iCloud KV Store)

    private enum CloudKey {
        static let selectedCalendarName = "sync_selectedCalendarName"
        static let visibleCalendarNames = "sync_visibleCalendarNames"
        static let visibleReminderListNames = "sync_visibleReminderListNames"
        static let remindersSyncEnabled = "sync_remindersSyncEnabled"
        static let soundEnabled = "sync_soundEnabled"
        static let warningEnabled = "sync_warningEnabled"
        static let warningTimingRaw = "sync_warningTimingRaw"
        static let defaultTaskDuration = "sync_defaultTaskDuration"
        static let eventCategories = "sync_eventCategories"
        static let selectedCoach = "sync_selectedCoach"
        static let selectedCoachDate = "sync_selectedCoachDate"
    }

    // MARK: - Local Keys (UserDefaults)

    private enum LocalKey {
        static let selectedCalendarID = "selectedCalendarID"
        static let visibleCalendarIDs = "visibleCalendarIDs"
        static let visibleReminderListIDs = "visibleReminderListIDs"
        static let remindersSyncEnabled = "remindersSyncEnabled"
        static let soundEnabled = "soundEnabled"
        static let warningEnabled = "warningEnabled"
        static let warningTimingRaw = "warningTiming"
        static let defaultTaskDuration = "defaultTaskDuration"
        static let eventCategories = "calendarEventCategories"
        static let selectedCoach = "selectedCoach"
        static let selectedCoachDate = "selectedCoachDate"
    }

    // MARK: - Init

    init() {
        // Sync starten
        cloud.synchronize()

        // Auf Aenderungen von anderen Geraeten lauschen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )

        // Bug 102: Proaktiv Remote-Daten holen beim App-Start
        pullFromCloud()
    }

    // MARK: - Push: Lokale Settings → iCloud

    /// Aktuelle lokale Einstellungen in iCloud KV Store schreiben
    func pushToCloud() {
        // Kalender: ID → Name aufloesen
        if let calID = defaults.string(forKey: LocalKey.selectedCalendarID),
           !calID.isEmpty,
           let calendar = eventStore.calendar(withIdentifier: calID) {
            cloud.set(calendar.title, forKey: CloudKey.selectedCalendarName)
        }

        // Sichtbare Kalender: IDs → Namen
        if let calIDs = defaults.array(forKey: LocalKey.visibleCalendarIDs) as? [String] {
            let names = calIDs.compactMap { eventStore.calendar(withIdentifier: $0)?.title }
            cloud.set(names, forKey: CloudKey.visibleCalendarNames)
        }

        // Sichtbare Reminder-Listen: IDs → Namen
        if let listIDs = defaults.array(forKey: LocalKey.visibleReminderListIDs) as? [String] {
            let names = listIDs.compactMap { eventStore.calendar(withIdentifier: $0)?.title }
            cloud.set(names, forKey: CloudKey.visibleReminderListNames)
        }

        // Einfache Bool/Int-Werte direkt kopieren
        cloud.set(defaults.bool(forKey: LocalKey.remindersSyncEnabled), forKey: CloudKey.remindersSyncEnabled)
        cloud.set(defaults.bool(forKey: LocalKey.soundEnabled), forKey: CloudKey.soundEnabled)
        cloud.set(defaults.bool(forKey: LocalKey.warningEnabled), forKey: CloudKey.warningEnabled)
        cloud.set(defaults.integer(forKey: LocalKey.warningTimingRaw), forKey: CloudKey.warningTimingRaw)
        cloud.set(defaults.integer(forKey: LocalKey.defaultTaskDuration), forKey: CloudKey.defaultTaskDuration)

        // Event-Kategorien: Dictionary direkt kopieren (calendarItemIdentifier ist geraetuebergreifend stabil)
        if let catDict = defaults.dictionary(forKey: LocalKey.eventCategories) as? [String: String] {
            cloud.set(catDict, forKey: CloudKey.eventCategories)
        }

        // Bug 102: Coach-Wahl NUR pushen wenn lokales Datum gesetzt ist
        // Verhindert dass leere Werte valide Remote-Daten ueberschreiben
        let localCoachDate = defaults.string(forKey: LocalKey.selectedCoachDate) ?? ""
        if Self.shouldPushCoach(localCoachDate: localCoachDate) {
            cloud.set(defaults.string(forKey: LocalKey.selectedCoach) ?? "", forKey: CloudKey.selectedCoach)
            cloud.set(localCoachDate, forKey: CloudKey.selectedCoachDate)
        }

        cloud.synchronize()
    }

    // MARK: - Pull: iCloud → Lokale Settings

    /// Einstellungen von iCloud in lokale UserDefaults uebernehmen
    @objc nonisolated private func cloudDidChange(_ notification: Notification) {
        Task { @MainActor in
            pullFromCloud()
        }
    }

    func pullFromCloud() {
        // Kalender-Name → lokale ID aufloesen
        if let calName = cloud.string(forKey: CloudKey.selectedCalendarName) {
            if let localID = resolveCalendarID(byName: calName) {
                defaults.set(localID, forKey: LocalKey.selectedCalendarID)
            }
        }

        // Sichtbare Kalender-Namen → lokale IDs
        if let calNames = cloud.array(forKey: CloudKey.visibleCalendarNames) as? [String] {
            let localIDs = calNames.compactMap { resolveCalendarID(byName: $0) }
            if !localIDs.isEmpty {
                defaults.set(localIDs, forKey: LocalKey.visibleCalendarIDs)
            }
        }

        // Sichtbare Reminder-Listen-Namen → lokale IDs
        if let listNames = cloud.array(forKey: CloudKey.visibleReminderListNames) as? [String] {
            let localIDs = listNames.compactMap { resolveReminderListID(byName: $0) }
            if !localIDs.isEmpty {
                defaults.set(localIDs, forKey: LocalKey.visibleReminderListIDs)
            }
        }

        // Einfache Bool/Int-Werte direkt uebernehmen
        defaults.set(cloud.bool(forKey: CloudKey.remindersSyncEnabled), forKey: LocalKey.remindersSyncEnabled)
        defaults.set(cloud.bool(forKey: CloudKey.soundEnabled), forKey: LocalKey.soundEnabled)
        defaults.set(cloud.bool(forKey: CloudKey.warningEnabled), forKey: LocalKey.warningEnabled)
        defaults.set(cloud.object(forKey: CloudKey.warningTimingRaw) as? Int ?? 0, forKey: LocalKey.warningTimingRaw)
        defaults.set(cloud.object(forKey: CloudKey.defaultTaskDuration) as? Int ?? 15, forKey: LocalKey.defaultTaskDuration)

        // Event-Kategorien: Remote-Dict mit lokalem mergen (Remote gewinnt bei Konflikten)
        if let remoteDict = cloud.dictionary(forKey: CloudKey.eventCategories) as? [String: String] {
            var localDict = defaults.dictionary(forKey: LocalKey.eventCategories) as? [String: String] ?? [:]
            localDict.merge(remoteDict) { _, remote in remote }
            defaults.set(localDict, forKey: LocalKey.eventCategories)
        }

        // Bug 102: Coach-Wahl mit Guard-Logik (Remote gewinnt bei neuerem/gleichem Datum)
        let remoteCoachDate = cloud.string(forKey: CloudKey.selectedCoachDate) ?? ""
        let localCoachDate = defaults.string(forKey: LocalKey.selectedCoachDate) ?? ""
        if Self.shouldAcceptRemoteCoach(remoteDate: remoteCoachDate, localDate: localCoachDate) {
            defaults.set(cloud.string(forKey: CloudKey.selectedCoach) ?? "", forKey: LocalKey.selectedCoach)
            defaults.set(remoteCoachDate, forKey: LocalKey.selectedCoachDate)
        }
    }

    // MARK: - Coach Sync Guards (Bug 102)

    /// Guard: Nur pushen wenn lokales Coach-Datum gesetzt ist.
    /// Verhindert dass leere Werte valide Remote-Daten ueberschreiben.
    static func shouldPushCoach(localCoachDate: String) -> Bool {
        !localCoachDate.isEmpty
    }

    /// Merge-Logik: Remote-Coach akzeptieren wenn Remote-Datum neuer oder gleich ist (Last-Writer-Wins).
    /// Leeres Remote-Datum wird immer abgelehnt.
    static func shouldAcceptRemoteCoach(remoteDate: String, localDate: String) -> Bool {
        guard !remoteDate.isEmpty else { return false }
        return remoteDate >= localDate
    }

    // MARK: - Event Category Sync (Bug 80)

    /// Push lokale Event-Kategorien nach iCloud
    func pushEventCategoriesToCloud() {
        if let catDict = defaults.dictionary(forKey: LocalKey.eventCategories) as? [String: String] {
            cloud.set(catDict, forKey: CloudKey.eventCategories)
            cloud.synchronize()
        }
    }

    /// Merge remote Event-Kategorien in lokale UserDefaults.
    /// Remote gewinnt bei Konflikten (neueste Aenderung vom anderen Geraet).
    static func mergeEventCategories(local: [String: String], remote: [String: String]) -> [String: String] {
        var merged = local
        merged.merge(remote) { _, remote in remote }
        return merged
    }

    // MARK: - Calendar Name Resolution

    /// Findet die lokale Kalender-ID anhand des Namens
    func resolveCalendarID(byName name: String) -> String? {
        eventStore.calendars(for: .event)
            .first { $0.title == name }?
            .calendarIdentifier
    }

    /// Findet die lokale Reminder-Listen-ID anhand des Namens
    func resolveReminderListID(byName name: String) -> String? {
        eventStore.calendars(for: .reminder)
            .first { $0.title == name }?
            .calendarIdentifier
    }
}
