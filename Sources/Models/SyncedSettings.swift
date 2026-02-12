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
