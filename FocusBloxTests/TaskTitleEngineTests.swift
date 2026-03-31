import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class TaskTitleEngineTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        UserDefaults.standard.set(true, forKey: "aiScoringEnabled")
    }

    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "aiScoringEnabled")
    }

    // MARK: - Guard Conditions

    /// Verhalten: Wenn aiScoringEnabled == false, laeuft deterministische Bereinigung TROTZDEM
    /// (Email-Prefixe, Keywords, Datum/Urgency-Extraktion), aber KEINE AI-Suggestions.
    /// Bricht wenn: Deterministische Schritte faelschlich an aiScoringEnabled gekoppelt sind
    func test_improveTitleIfNeeded_runsDeterministicEvenWhenAiDisabled() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Re: Fwd: Meeting")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.title, "Meeting",
                       "Deterministische Bereinigung (Email-Prefixe) muss auch ohne AI laufen")
        XCTAssertFalse(task.needsTitleImprovement,
                       "Flag muss auf false gesetzt werden nach deterministischer Bereinigung")
    }

    /// Verhalten: Wenn needsTitleImprovement == false, wird die Task uebersprungen
    /// Bricht wenn: TaskTitleEngine.improveTitleIfNeeded() den Guard `task.needsTitleImprovement` entfernt
    func test_improveTitleIfNeeded_skipsWhenFlagIsFalse() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Already good title")
        task.needsTitleImprovement = false
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.title, "Already good title", "Title should remain unchanged when flag is false")
        XCTAssertNil(task.taskDescription, "Description should not be touched when skipped")
    }

    // MARK: - Original-Titel Sicherung

    /// Verhalten: Original-Titel wird in taskDescription gesichert BEVOR der Titel ueberschrieben wird
    /// Bricht wenn: performImprovement() die Zeile `task.taskDescription = task.title` entfernt
    func test_improveTitleIfNeeded_savesOriginalToDescription() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Re: AW: Fwd: Quarterly Report")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        if TaskTitleEngine.isAvailable {
            // Wenn KI verfuegbar: Original muss in Description stehen
            XCTAssertEqual(task.taskDescription, "Re: AW: Fwd: Quarterly Report",
                           "Original title must be preserved in taskDescription")
            XCTAssertFalse(task.needsTitleImprovement, "Flag should be false after improvement")
        } else {
            // Wenn KI nicht verfuegbar: Alles bleibt wie es ist
            XCTAssertEqual(task.title, "Re: AW: Fwd: Quarterly Report",
                           "Title should remain unchanged when AI unavailable")
        }
    }

    /// Verhalten: Bestehende taskDescription wird NICHT ueberschrieben
    /// Bricht wenn: performImprovement() den Guard `task.taskDescription == nil || isEmpty` entfernt
    func test_improveTitleIfNeeded_preservesExistingDescription() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Re: Budget Review", taskDescription: "Notizen zum Budget")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.taskDescription, "Notizen zum Budget",
                       "Existing description must NOT be overwritten")
    }

    // MARK: - Batch Processing

    /// Verhalten: Batch holt nur Tasks mit needsTitleImprovement == true und !isCompleted
    /// Bricht wenn: improveAllPendingTitles() das Predicate `needsTitleImprovement && !isCompleted` entfernt
    func test_improveAllPendingTitles_fetchesOnlyFlaggedIncompleteTasks() async throws {
        let context = container.mainContext

        // Task 1: flagged + incomplete → sollte verarbeitet werden
        let task1 = LocalTask(title: "Flagged task")
        task1.needsTitleImprovement = true
        context.insert(task1)

        // Task 2: NOT flagged → sollte uebersprungen werden
        let task2 = LocalTask(title: "Not flagged")
        task2.needsTitleImprovement = false
        context.insert(task2)

        // Task 3: flagged + completed → sollte uebersprungen werden
        let task3 = LocalTask(title: "Completed task", isCompleted: true)
        task3.needsTitleImprovement = true
        context.insert(task3)

        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        let count = await engine.improveAllPendingTitles()

        if TaskTitleEngine.isAvailable {
            XCTAssertEqual(count, 1, "Should only process flagged, incomplete tasks")
        } else {
            XCTAssertEqual(count, 0, "Should return 0 when AI is not available")
        }
    }

    /// Verhalten: Batch gibt 0 zurueck wenn aiScoringEnabled == false
    /// Bricht wenn: improveAllPendingTitles() den Guard `AppSettings.shared.aiScoringEnabled` entfernt
    /// Auch bei aiScoringEnabled=false werden Tasks deterministisch verarbeitet
    /// (Keywords entfernen, Datum/Urgency/Importance/Duration extrahieren).
    /// Nur AI-Suggestions (Kategorie, Energielevel) entfallen.
    func test_improveAllPendingTitles_runsDeterministicWhenAiDisabled() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Dringend Einkaufen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")

        let engine = TaskTitleEngine(modelContext: context)
        let count = await engine.improveAllPendingTitles()

        XCTAssertEqual(count, 1,
                       "Deterministische Verarbeitung muss auch ohne AI laufen")
        XCTAssertEqual(task.urgency, "urgent",
                       "'Dringend' muss deterministisch erkannt werden")
        XCTAssertFalse(task.title.lowercased().contains("dringend"),
                       "'Dringend' muss aus dem Titel entfernt werden")
    }

    // MARK: - Model Property

    /// Verhalten: needsTitleImprovement hat Default false
    /// Bricht wenn: LocalTask.needsTitleImprovement Default von false auf true geaendert wird
    func test_needsTitleImprovement_defaultIsFalse() throws {
        let task = LocalTask(title: "New task")
        XCTAssertFalse(task.needsTitleImprovement,
                       "needsTitleImprovement should default to false")
    }

    // MARK: - Availability

    /// Verhalten: isAvailable gibt konsistenten Bool zurueck
    /// Bricht wenn: isAvailable bei jedem Aufruf unterschiedliche Werte liefert
    func test_isAvailable_returnsConsistentBool() {
        let first = TaskTitleEngine.isAvailable
        let second = TaskTitleEngine.isAvailable
        XCTAssertEqual(first, second, "isAvailable should return consistent results")
    }

    // MARK: - CTC-1b: relativeDateFrom Helper

    /// Verhalten: "today" wird zu heute (startOfDay) gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() nicht existiert oder "today" nicht handled
    func test_relativeDateFrom_today() {
        let result = TaskTitleEngine.relativeDateFrom("today")
        let expected = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(result, expected, "today should map to start of current day")
    }

    /// Verhalten: "tomorrow" wird zu morgen (startOfDay) gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() "tomorrow" nicht handled
    func test_relativeDateFrom_tomorrow() {
        let result = TaskTitleEngine.relativeDateFrom("tomorrow")
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        XCTAssertEqual(result, expected, "tomorrow should map to start of next day")
    }

    /// Verhalten: Unbekannte Werte geben nil zurueck
    /// Bricht wenn: relativeDateFrom() bei unbekanntem String nicht nil liefert
    func test_relativeDateFrom_unknown_returnsNil() {
        XCTAssertNil(TaskTitleEngine.relativeDateFrom(""), "Empty string should return nil")
        XCTAssertNil(TaskTitleEngine.relativeDateFrom(nil), "nil should return nil")
    }

    // MARK: - Erweiterte relative Datumsangaben

    /// Verhalten: "übermorgen" wird zu +2 Tage gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() den case "übermorgen" entfernt
    func test_relativeDateFrom_uebermorgen() {
        let result = TaskTitleEngine.relativeDateFrom("übermorgen")
        let expected = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date()))
        XCTAssertEqual(result, expected, "übermorgen should map to start of day +2")
    }

    /// Verhalten: "nächste woche" wird zum nächsten Montag gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() den case "nächste woche" entfernt
    func test_relativeDateFrom_naechsteWoche() {
        let result = TaskTitleEngine.relativeDateFrom("nächste woche")
        XCTAssertNotNil(result, "nächste woche should return a date")
        if let date = result {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 2, "nächste woche should be a Monday (weekday 2)")
            XCTAssertTrue(date > Date(), "nächste woche should be in the future")
        }
    }

    /// Verhalten: "freitag" wird zum naechsten Freitag gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() Wochentag-Mapping entfernt
    func test_relativeDateFrom_weekday_freitag() {
        let result = TaskTitleEngine.relativeDateFrom("freitag")
        XCTAssertNotNil(result, "freitag should return a date")
        if let date = result {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 6, "freitag should be a Friday (weekday 6)")
            XCTAssertTrue(date > Calendar.current.startOfDay(for: Date()), "freitag should be in the future")
        }
    }

    /// Verhalten: "montag" wird zum naechsten Montag gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() Wochentag-Mapping entfernt
    func test_relativeDateFrom_weekday_montag() {
        let result = TaskTitleEngine.relativeDateFrom("montag")
        XCTAssertNotNil(result, "montag should return a date")
        if let date = result {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 2, "montag should be a Monday (weekday 2)")
        }
    }

    // MARK: - CTC-1b: Metadaten-Extraktion (nur wenn AI verfuegbar)

    /// Verhalten: "heute erledigen!" setzt dueDate auf heute
    /// Bricht wenn: performImprovement() dueDate nicht aus KI-Response uebernimmt
    func test_improveTitleIfNeeded_setsDueDate_whenAvailable() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Bahnfahrt buchen heute erledigen!")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertNotNil(task.dueDate, "dueDate should be set from 'heute erledigen'")
    }

    /// Verhalten: "heute erledigen!" / "dringend" setzt urgency auf "urgent"
    /// Bricht wenn: performImprovement() urgency nicht aus KI-Response uebernimmt
    func test_improveTitleIfNeeded_setsUrgency_whenAvailable() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Dringend: Server-Problem fixen ASAP!")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.urgency, "urgent", "urgency should be 'urgent' for ASAP/dringend tasks")
    }

    /// Verhalten: Bestehende dueDate wird NICHT ueberschrieben
    /// Bricht wenn: performImprovement() den Guard `task.dueDate == nil` entfernt
    func test_improveTitleIfNeeded_doesNotOverwriteExistingDueDate() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        let existingDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let task = LocalTask(title: "Heute erledigen: Report schreiben", dueDate: existingDate)
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.dueDate, existingDate, "Existing dueDate must NOT be overwritten")
    }

    /// Verhalten: Bestehende urgency wird NICHT ueberschrieben
    /// Bricht wenn: performImprovement() den Guard `task.urgency == nil` entfernt
    func test_improveTitleIfNeeded_doesNotOverwriteExistingUrgency() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        let task = LocalTask(title: "ASAP: Budget Review", urgency: "not_urgent")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.urgency, "not_urgent", "Existing urgency must NOT be overwritten")
    }

    // MARK: - RW_1.4: Deterministic Email Cleanup via improveTitleIfNeeded

    /// Verhalten: E-Mail-Artefakte werden deterministisch (nicht AI) aus Titel entfernt
    /// Bricht wenn: improveTitleIfNeeded() cleanTitle() nicht aufruft
    func test_improveTitleIfNeeded_cleansEmailArtifactsDeterministically() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Re: Fwd: AW: WG: Quarterly Budget Review Meeting")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        // Auch ohne AI muessen E-Mail-Artefakte deterministisch entfernt werden
        XCTAssertFalse(task.title.contains("Re:"), "cleanTitle must remove 'Re:'")
        XCTAssertFalse(task.title.contains("Fwd:"), "cleanTitle must remove 'Fwd:'")
        XCTAssertFalse(task.title.contains("AW:"), "cleanTitle must remove 'AW:'")
        XCTAssertFalse(task.title.contains("WG:"), "cleanTitle must remove 'WG:'")
        XCTAssertEqual(task.title, "Quarterly Budget Review Meeting",
                       "RW_1.4: Title should be deterministically cleaned")
    }

    // MARK: - Deterministic Keyword Stripping (Bug: title keywords not removed)

    /// Verhalten: "(dringend)" wird aus dem Titel entfernt
    /// Bricht wenn: stripKeywords() das Pattern "(dringend)" nicht erkennt
    func test_stripKeywords_removesParenthesizedDringend() {
        let result = TaskTitleEngine.stripKeywords("Flüge für Retreat buchen (dringend)")
        XCTAssertEqual(result, "Flüge für Retreat buchen")
    }

    /// Verhalten: "(urgent)" wird aus dem Titel entfernt
    /// Bricht wenn: stripKeywords() das englische Pattern nicht erkennt
    func test_stripKeywords_removesParenthesizedUrgent() {
        let result = TaskTitleEngine.stripKeywords("Book flights (urgent)")
        XCTAssertEqual(result, "Book flights")
    }

    /// Verhalten: "(ASAP)" wird aus dem Titel entfernt (case-insensitive)
    /// Bricht wenn: stripKeywords() Grossschreibung nicht handled
    func test_stripKeywords_removesParenthesizedASAP() {
        let result = TaskTitleEngine.stripKeywords("Server fixen (ASAP)")
        XCTAssertEqual(result, "Server fixen")
    }

    /// Verhalten: "(sofort)" wird aus dem Titel entfernt
    /// Bricht wenn: stripKeywords() "sofort" nicht in der Keyword-Liste hat
    func test_stripKeywords_removesParenthesizedSofort() {
        let result = TaskTitleEngine.stripKeywords("Antwort schreiben (sofort)")
        XCTAssertEqual(result, "Antwort schreiben")
    }

    /// Verhalten: "dringend:" am Anfang wird entfernt
    /// Bricht wenn: stripKeywords() das Prefix-Pattern nicht erkennt
    func test_stripKeywords_removesDringendPrefix() {
        let result = TaskTitleEngine.stripKeywords("dringend: Server-Problem fixen")
        XCTAssertEqual(result, "Server-Problem fixen")
    }

    /// Verhalten: Titel ohne Keywords bleibt unveraendert
    /// Bricht wenn: stripKeywords() normale Titel faelschlicherweise aendert
    func test_stripKeywords_leavesNormalTitleUnchanged() {
        let result = TaskTitleEngine.stripKeywords("Einkaufen gehen")
        XCTAssertEqual(result, "Einkaufen gehen")
    }

    /// Verhalten: Keyword in der Mitte des Titels wird entfernt
    /// Bricht wenn: stripKeywords() nur am Ende matcht
    func test_stripKeywords_removesKeywordInMiddle() {
        let result = TaskTitleEngine.stripKeywords("Flüge (dringend) für Retreat buchen")
        XCTAssertEqual(result, "Flüge für Retreat buchen")
    }

    /// Verhalten: stripKeywords laesst Titel mit Doppelpunkt-Prefix unveraendert
    /// Bricht wenn: stripKeywords() Doppelpunkt-Prefixe generisch entfernt
    func test_stripKeywords_preservesCategoryColonPrefix() {
        let result = TaskTitleEngine.stripKeywords("Lohnsteuererklärung: Rechnungsübersicht erstellen")
        XCTAssertEqual(result, "Lohnsteuererklärung: Rechnungsübersicht erstellen",
                       "Category-style colon prefixes must NOT be stripped")
    }

    // MARK: - BUG_124: stripKeywords() — Datums-Keywords entfernen

    /// Verhalten: "Heute" am Anfang wird aus dem Titel entfernt
    /// Bricht wenn: stripKeywords() keine Datums-Keyword-Regex hat
    func test_stripKeywords_removesHeuteAtStart() {
        let result = TaskTitleEngine.stripKeywords("Heute Klingel demontieren")
        XCTAssertEqual(result, "Klingel demontieren",
                       "User sieht 'Heute' im Titel — muss entfernt werden weil Datum als Badge angezeigt wird")
    }

    /// Verhalten: "Morgen" am Anfang wird aus dem Titel entfernt
    /// Bricht wenn: stripKeywords() "morgen" nicht in der Datums-Keyword-Liste hat
    func test_stripKeywords_removesMorgenAtStart() {
        let result = TaskTitleEngine.stripKeywords("Morgen Termin für Reifenwechsel machen")
        XCTAssertEqual(result, "Termin für Reifenwechsel machen")
    }

    /// Verhalten: "Übermorgen" wird entfernt (Umlaut korrekt)
    /// Bricht wenn: stripKeywords() Umlaute nicht korrekt handled
    func test_stripKeywords_removesUebermorgen() {
        let result = TaskTitleEngine.stripKeywords("Übermorgen Zahnarzt anrufen")
        XCTAssertEqual(result, "Zahnarzt anrufen")
    }

    /// Verhalten: Wochentag am Anfang wird entfernt
    /// Bricht wenn: stripKeywords() keine Wochentag-Keywords hat
    func test_stripKeywords_removesWochentag() {
        let result = TaskTitleEngine.stripKeywords("Freitag Meeting vorbereiten")
        XCTAssertEqual(result, "Meeting vorbereiten")
    }

    /// Verhalten: "Nächste Woche" (zwei Wörter) wird entfernt
    /// Bricht wenn: stripKeywords() Multi-Wort-Keywords nicht handled
    func test_stripKeywords_removesNaechsteWoche() {
        let result = TaskTitleEngine.stripKeywords("Nächste Woche Bericht abgeben")
        XCTAssertEqual(result, "Bericht abgeben")
    }

    /// Verhalten: Datums-Keyword in der Mitte wird entfernt
    /// Bricht wenn: stripKeywords() nur am Anfang matcht
    func test_stripKeywords_removesDateKeywordInMiddle() {
        let result = TaskTitleEngine.stripKeywords("Termin morgen absagen")
        XCTAssertEqual(result, "Termin absagen")
    }

    /// Verhalten: Kombinierte Keywords (Datum + Urgency) werden BEIDE entfernt
    /// Bricht wenn: stripKeywords() nur eine Keyword-Kategorie entfernt
    func test_stripKeywords_removesBothDateAndUrgency() {
        let result = TaskTitleEngine.stripKeywords("Heute (dringend) Klingel demontieren")
        XCTAssertEqual(result, "Klingel demontieren")
    }

    /// Verhalten: Case-insensitive Erkennung von Datums-Keywords
    /// Bricht wenn: stripKeywords() Grossschreibung nicht handled
    func test_stripKeywords_removesDateKeywordCaseInsensitive() {
        let result = TaskTitleEngine.stripKeywords("HEUTE Einkaufen gehen")
        XCTAssertEqual(result, "Einkaufen gehen")
    }

    /// Verhalten: "Morgen" als Teil eines Wortes wird NICHT entfernt
    /// Bricht wenn: stripKeywords() kein Word-Boundary nutzt und Wortteile entfernt
    func test_stripKeywords_preservesMorgenAsPartOfWord() {
        let result = TaskTitleEngine.stripKeywords("Morgengymnastik machen")
        XCTAssertEqual(result, "Morgengymnastik machen",
                       "Keyword 'morgen' als Wortteil darf NICHT entfernt werden")
    }

    /// Verhalten: Englische Datums-Keywords werden entfernt
    /// Bricht wenn: stripKeywords() nur deutsche Keywords kennt
    func test_stripKeywords_removesEnglishDateKeyword() {
        let result = TaskTitleEngine.stripKeywords("Tomorrow fix the build")
        XCTAssertEqual(result, "fix the build")
    }

    // MARK: - RW_1.4: cleanTitle() — Deterministische Titel-Bereinigung

    /// Verhalten: E-Mail-Prefixe (Re:, Fwd:, AW:, WG:, FW:) werden entfernt
    /// Bricht wenn: cleanTitle() das Regex-Pattern fuer E-Mail-Prefixe nicht hat
    func test_cleanTitle_removesEmailPrefixes() {
        let result = TaskTitleEngine.cleanTitle("Re: Fwd: AW: WG: Quarterly Budget Review")
        XCTAssertEqual(result, "Quarterly Budget Review",
                       "All email prefixes (Re:, Fwd:, AW:, WG:) must be removed")
    }

    /// Verhalten: Einleitungsfloskeln werden entfernt
    /// Bricht wenn: cleanTitle() die Floskel-Patterns nicht enthaelt
    func test_cleanTitle_removesIntroPhrases() {
        let result = TaskTitleEngine.cleanTitle("Erinnere mich daran Herrn Mueller anzurufen")
        XCTAssertEqual(result, "Herrn Mueller anzurufen",
                       "Intro phrase 'Erinnere mich daran' must be removed")
    }

    /// Verhalten: "Ich muss noch" Floskel wird entfernt
    /// Bricht wenn: cleanTitle() "Ich muss noch" nicht in der Floskel-Liste hat
    func test_cleanTitle_removesIchMussNoch() {
        let result = TaskTitleEngine.cleanTitle("Ich muss noch Steuern machen")
        XCTAssertEqual(result, "Steuern machen",
                       "Intro phrase 'Ich muss noch' must be removed")
    }

    /// Verhalten: Umlaute und Sonderzeichen bleiben IMMER erhalten
    /// Bricht wenn: cleanTitle() Umlaute/Sonderzeichen veraendert
    func test_cleanTitle_preservesUmlautsAndSpecialChars() {
        let result = TaskTitleEngine.cleanTitle("Flüge für Ärzte & Übernachtung buchen")
        XCTAssertEqual(result, "Flüge für Ärzte & Übernachtung buchen",
                       "Umlauts and special characters must NEVER be modified")
    }

    /// Verhalten: Doppelpunkt-Prefixe die User-Content sind bleiben erhalten
    /// Bricht wenn: cleanTitle() beliebige Doppelpunkt-Prefixe entfernt statt nur E-Mail-Artefakte
    func test_cleanTitle_preservesCategoryColonPrefix() {
        let result = TaskTitleEngine.cleanTitle("Lohnsteuererklärung: Rechnungsübersicht erstellen")
        XCTAssertEqual(result, "Lohnsteuererklärung: Rechnungsübersicht erstellen",
                       "Category-style colon prefix is user content — must NOT be removed")
    }

    /// Verhalten: Whitespace wird normalisiert (mehrfache Leerzeichen → eins)
    /// Bricht wenn: cleanTitle() Whitespace-Normalisierung fehlt
    func test_cleanTitle_normalizesWhitespace() {
        let result = TaskTitleEngine.cleanTitle("Re:   Fwd:   Meeting   planen  ")
        XCTAssertEqual(result, "Meeting planen",
                       "Multiple whitespace should be normalized to single space, trimmed")
    }

    // MARK: - RW_1.4: AI Suggestions (Kategorie + Dauer)

    /// Verhalten: improveTitleIfNeeded setzt suggestedCategory wenn AI verfuegbar
    /// Bricht wenn: enrichWithSuggestions() suggestedCategory nicht aus TaskSuggestion uebernimmt
    func test_improveTitleIfNeeded_setsSuggestedCategory_whenAvailable() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Wohnung putzen und aufräumen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        let validCategories = ["income", "maintenance", "recharge", "learning", "giving_back"]
        XCTAssertNotNil(task.suggestedCategory,
                        "suggestedCategory must be set after enrichment")
        if let cat = task.suggestedCategory {
            XCTAssertTrue(validCategories.contains(cat),
                          "suggestedCategory '\(cat)' must be one of: \(validCategories)")
        }
    }

    /// Verhalten: improveTitleIfNeeded setzt suggestedDuration wenn AI verfuegbar
    /// Bricht wenn: enrichWithSuggestions() suggestedDuration nicht aus TaskSuggestion uebernimmt
    func test_improveTitleIfNeeded_setsSuggestedDuration_whenAvailable() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt Termin wahrnehmen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        let validDurations = [5, 15, 30, 60]
        XCTAssertNotNil(task.suggestedDuration,
                        "suggestedDuration must be set after enrichment")
        if let dur = task.suggestedDuration {
            XCTAssertTrue(validDurations.contains(dur),
                          "suggestedDuration \(dur) must be one of: \(validDurations)")
        }
    }

    // MARK: - RW_1.4: Titel wird NICHT durch AI veraendert

    /// Verhalten: Nach improveTitleIfNeeded wird der Titel nur deterministisch bereinigt, NIE durch AI veraendert
    /// Bricht wenn: performImprovement() den Titel noch per AI-Response ueberschreibt
    func test_improveTitleIfNeeded_titleOnlyCleanedDeterministically() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        // Titel ohne E-Mail-Artefakte oder Floskeln — sollte unveraendert bleiben
        let task = LocalTask(title: "Kruder & Dorfmeister Tickets buchen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.title, "Kruder & Dorfmeister Tickets buchen",
                       "RW_1.4: Title must NOT be changed by AI — only deterministic cleanup allowed")
    }

    // MARK: - Bug 95: titleContainsDateKeyword (deterministische Keyword-Pruefung)

    /// Verhalten: Generischer Titel ohne Datum-Keyword gibt false zurueck
    /// Bricht wenn: TaskTitleEngine.titleContainsDateKeyword() nicht existiert oder bei generischem Titel true liefert
    func test_titleContainsDateKeyword_returnsFalse_forGenericTitle() {
        XCTAssertFalse(TaskTitleEngine.titleContainsDateKeyword("Einkaufen gehen"),
                       "Generic title without date keyword should return false")
    }

    /// Verhalten: Generischer englischer Titel ohne Datum gibt false zurueck
    /// Bricht wenn: titleContainsDateKeyword() bei "Buy groceries" true liefert
    func test_titleContainsDateKeyword_returnsFalse_forEnglishGenericTitle() {
        XCTAssertFalse(TaskTitleEngine.titleContainsDateKeyword("Buy groceries"),
                       "English generic title should return false")
    }

    /// Verhalten: Titel mit "heute" gibt true zurueck
    /// Bricht wenn: titleContainsDateKeyword() "heute" nicht erkennt
    func test_titleContainsDateKeyword_returnsTrue_forHeuteTitle() {
        XCTAssertTrue(TaskTitleEngine.titleContainsDateKeyword("Heute Arzt anrufen"),
                      "Title containing 'heute' should return true")
    }

    /// Verhalten: Titel mit "morgen" gibt true zurueck
    /// Bricht wenn: titleContainsDateKeyword() "morgen" nicht erkennt
    func test_titleContainsDateKeyword_returnsTrue_forMorgenTitle() {
        XCTAssertTrue(TaskTitleEngine.titleContainsDateKeyword("Morgen Steuern machen"),
                      "Title containing 'morgen' should return true")
    }

    /// Verhalten: Titel mit Wochentag gibt true zurueck
    /// Bricht wenn: titleContainsDateKeyword() Wochentage nicht erkennt
    func test_titleContainsDateKeyword_returnsTrue_forWeekdayTitle() {
        XCTAssertTrue(TaskTitleEngine.titleContainsDateKeyword("Bis Freitag Report abgeben"),
                      "Title containing weekday should return true")
    }

    /// Verhalten: Titel mit "Nächste Woche" gibt true zurück
    /// Bricht wenn: titleContainsDateKeyword() zusammengesetzte Phrasen nicht erkennt
    func test_titleContainsDateKeyword_returnsTrue_forNaechsteWocheTitle() {
        XCTAssertTrue(TaskTitleEngine.titleContainsDateKeyword("Nächste Woche Meeting planen"),
                      "Title containing 'nächste woche' should return true")
    }

    /// Verhalten: Titel mit "today" (englisch) gibt true zurueck
    /// Bricht wenn: titleContainsDateKeyword() englische Keywords nicht erkennt
    func test_titleContainsDateKeyword_returnsTrue_forTodayTitle() {
        XCTAssertTrue(TaskTitleEngine.titleContainsDateKeyword("Finish report today"),
                      "Title containing 'today' should return true")
    }

    /// Verhalten: Titel mit "uebermorgen" gibt true zurueck
    /// Bricht wenn: titleContainsDateKeyword() "uebermorgen" nicht erkennt
    func test_titleContainsDateKeyword_returnsTrue_forUebermorgenTitle() {
        XCTAssertTrue(TaskTitleEngine.titleContainsDateKeyword("Uebermorgen Zahnarzt"),
                      "Title containing 'uebermorgen' should return true")
    }

    // MARK: - Bug 97: Deterministic dueDate Extraction (Shortcut-Pfad)

    /// Verhalten: Titel mit "heute" liefert deterministisch startOfDay(today)
    /// Bricht wenn: extractDeterministicDueDate() "heute" nicht auf today mapped
    func test_extractDeterministicDueDate_heute_returnsToday() {
        let result = TaskTitleEngine.extractDeterministicDueDate(from: "Heute dringend LinkedIn Post verfassen")
        let expected = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(result, expected,
                       "Title with 'Heute' should return start of today")
    }

    /// Verhalten: Titel mit "morgen" liefert deterministisch startOfDay(tomorrow)
    /// Bricht wenn: extractDeterministicDueDate() "morgen" nicht auf tomorrow mapped
    func test_extractDeterministicDueDate_morgen_returnsTomorrow() {
        let result = TaskTitleEngine.extractDeterministicDueDate(from: "Morgen Zahnarzt")
        let expected = Calendar.current.date(byAdding: .day, value: 1,
                          to: Calendar.current.startOfDay(for: Date()))
        XCTAssertEqual(result, expected,
                       "Title with 'Morgen' should return start of tomorrow")
    }

    /// Verhalten: Generischer Titel ohne Keywords liefert nil
    /// Bricht wenn: extractDeterministicDueDate() fuer generische Titel ein Datum liefert
    func test_extractDeterministicDueDate_noKeyword_returnsNil() {
        let result = TaskTitleEngine.extractDeterministicDueDate(from: "Einkaufen gehen")
        XCTAssertNil(result,
                     "Generic title should return nil (no date extraction)")
    }

    /// Verhalten: Titel mit Wochentag liefert naechsten Wochentag
    /// Bricht wenn: extractDeterministicDueDate() Wochentage nicht erkennt
    func test_extractDeterministicDueDate_freitag_returnsNextFriday() {
        let result = TaskTitleEngine.extractDeterministicDueDate(from: "Bis Freitag Report abgeben")
        XCTAssertNotNil(result, "Title with 'Freitag' should return a date")
        // Verify it's a Friday (weekday 6 in Calendar)
        if let date = result {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 6,
                           "Should return a Friday (weekday 6)")
        }
    }

    /// Verhalten: Case-insensitive — "HEUTE" funktioniert wie "heute"
    /// Bricht wenn: extractDeterministicDueDate() case-sensitive matched
    func test_extractDeterministicDueDate_caseInsensitive() {
        let result = TaskTitleEngine.extractDeterministicDueDate(from: "HEUTE Arzt anrufen")
        let expected = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(result, expected,
                       "Uppercase 'HEUTE' should still return today")
    }

    /// Verhalten: Englisches "today" funktioniert ebenfalls
    /// Bricht wenn: extractDeterministicDueDate() englische Keywords nicht erkennt
    func test_extractDeterministicDueDate_todayEnglish_returnsToday() {
        let result = TaskTitleEngine.extractDeterministicDueDate(from: "Finish report today")
        let expected = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(result, expected,
                       "English 'today' should return start of today")
    }

    /// Verhalten: AI darf dueDate NICHT setzen wenn Titel kein Datum-Keyword enthaelt
    /// Bricht wenn: performImprovement() den titleContainsDateKeyword-Guard nicht hat
    func test_improveTitleIfNeeded_doesNotSetDueDate_forGenericTitle() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Projekt Dokumentation schreiben")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertNil(task.dueDate,
                     "Bug 95: Generic title must NOT get dueDate set by AI")
    }
}
