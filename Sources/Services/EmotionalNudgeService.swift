import Foundation

/// Stateless service fuer Emotional Nudge (Micro-Tasks).
/// Prueft Daily-Limits, generiert rotierende Motivationstexte,
/// trackt welche Tasks heute schon genudget wurden.
struct EmotionalNudgeService {

    // MARK: - Statische Nudge-Texte (11 Varianten)

    private static let nudgeTexts: [String] = [
        "Nur 2 Minuten. Einfach anfangen.",
        "Du musst es nicht fertig machen. Nur starten.",
        "2 Minuten — dann entscheidest du.",
        "Der erste Schritt ist der schwerste.",
        "Kurz reinschauen kostet nichts.",
        "Starte. Alles andere kommt danach.",
        "2 Minuten Fokus. Mehr nicht.",
        "Du hast das schon oefter aufgeschoben. Heute anders?",
        "Klein anfangen ist besser als gar nicht anfangen.",
        "Mach einfach kurz auf — du kannst jederzeit aufhoeren.",
        "Nur schauen, wo du gerade stehst."
    ]

    // MARK: - Public API

    /// Prueft ob fuer diesen Task heute ein Nudge angezeigt werden darf.
    /// Max 1 Nudge/Task/Tag, max 3 Nudges/Tag gesamt.
    @MainActor
    static func canShowNudge(for taskID: String) -> Bool {
        let settings = AppSettings.shared
        resetIfNewDay()

        guard settings.nudgeDailyCount < 3 else { return false }

        let alreadyNudged = settings.nudgeTaskIDs
            .split(separator: ",")
            .map(String.init)
            .contains(taskID)
        return !alreadyNudged
    }

    /// Gibt einen rotierenden Nudge-Text zurueck.
    @MainActor
    static func nudgeText() -> String {
        let settings = AppSettings.shared
        let index = settings.nudgeDailyCount % nudgeTexts.count
        return nudgeTexts[index]
    }

    /// Zaehlt den Nudge fuer diesen Task hoch.
    @MainActor
    static func recordNudge(for taskID: String) {
        let settings = AppSettings.shared
        settings.nudgeDailyCount += 1

        var ids = settings.nudgeTaskIDs
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
        ids.append(taskID)
        settings.nudgeTaskIDs = ids.joined(separator: ",")
    }

    /// Reset bei neuem Tag.
    @MainActor
    static func resetIfNewDay() {
        let settings = AppSettings.shared
        let today = isoDate()
        if settings.nudgeLastDate != today {
            settings.nudgeDailyCount = 0
            settings.nudgeTaskIDs = ""
            settings.nudgeLastDate = today
        }
    }

    // MARK: - Private

    private static func isoDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
