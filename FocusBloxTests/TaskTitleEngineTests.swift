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

    /// Verhalten: Wenn aiScoringEnabled == false, wird der Titel NICHT veraendert
    /// Bricht wenn: TaskTitleEngine.improveTitleIfNeeded() den Guard `AppSettings.shared.aiScoringEnabled` entfernt
    func test_improveTitleIfNeeded_skipsWhenAiDisabled() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Re: Fwd: Meeting")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.title, "Re: Fwd: Meeting", "Title should remain unchanged when AI is disabled")
        XCTAssertTrue(task.needsTitleImprovement, "Flag should remain true when skipped")
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
    func test_improveAllPendingTitles_returnsZeroWhenDisabled() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Some task")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")

        let engine = TaskTitleEngine(modelContext: context)
        let count = await engine.improveAllPendingTitles()

        XCTAssertEqual(count, 0, "Should return 0 when AI is disabled")
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

    /// Verhalten: "uebermorgen" wird zu +2 Tage gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() den case "uebermorgen" entfernt
    func test_relativeDateFrom_uebermorgen() {
        let result = TaskTitleEngine.relativeDateFrom("uebermorgen")
        let expected = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date()))
        XCTAssertEqual(result, expected, "uebermorgen should map to start of day +2")
    }

    /// Verhalten: "naechste woche" wird zum naechsten Montag gemappt
    /// Bricht wenn: TaskTitleEngine.relativeDateFrom() den case "naechste woche" entfernt
    func test_relativeDateFrom_naechsteWoche() {
        let result = TaskTitleEngine.relativeDateFrom("naechste woche")
        XCTAssertNotNil(result, "naechste woche should return a date")
        if let date = result {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 2, "naechste woche should be a Monday (weekday 2)")
            XCTAssertTrue(date > Date(), "naechste woche should be in the future")
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

    // MARK: - AI Title Improvement (nur wenn verfuegbar)

    /// Verhalten: KI verbessert kryptischen E-Mail-Subject zu actionable Titel
    /// Bricht wenn: performImprovement() den KI-Call oder die Titel-Zuweisung entfernt
    func test_improveTitleIfNeeded_improvesEmailSubject_whenAvailable() async throws {
        guard TaskTitleEngine.isAvailable else {
            // Test nur sinnvoll wenn Apple Intelligence verfuegbar
            throw XCTSkip("Apple Intelligence not available on this device")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Re: Fwd: AW: WG: Quarterly Budget Review Meeting")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        // Titel sollte verbessert sein (keine Re:/Fwd:/AW:/WG: Artefakte mehr)
        XCTAssertFalse(task.title.contains("Re:"), "Improved title should not contain 'Re:'")
        XCTAssertFalse(task.title.contains("Fwd:"), "Improved title should not contain 'Fwd:'")
        XCTAssertFalse(task.title.contains("AW:"), "Improved title should not contain 'AW:'")
        XCTAssertFalse(task.needsTitleImprovement, "Flag should be false after improvement")
        XCTAssertNotNil(task.taskDescription, "Original should be saved in description")
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

    // MARK: - Safety Guard: shouldAcceptImprovedTitle (Bug: Title prefix removed)

    /// Verhalten: AI-Output das signifikant kuerzer ist OHNE bekannte Muster wird abgelehnt
    /// Bricht wenn: shouldAcceptImprovedTitle() nicht existiert oder immer true liefert
    func test_shouldAcceptImprovedTitle_rejectsAggressiveShortening() {
        let accepted = TaskTitleEngine.shouldAcceptImprovedTitle(
            original: "Lohnsteuererklärung: Rechnungsübersicht erstellen",
            improved: "Rechnungsübersicht erstellen"
        )
        XCTAssertFalse(accepted,
                       "Should reject when AI removes significant content without known removable patterns")
    }

    /// Verhalten: AI-Output das bekannte Artefakte entfernt wird akzeptiert (auch wenn viel kuerzer)
    /// Bricht wenn: shouldAcceptImprovedTitle() E-Mail-Artefakt-Entfernung blockiert
    func test_shouldAcceptImprovedTitle_allowsKnownPatternRemoval() {
        let accepted = TaskTitleEngine.shouldAcceptImprovedTitle(
            original: "Re: Fwd: AW: WG: Quarterly Budget Review",
            improved: "Quarterly Budget Review"
        )
        XCTAssertTrue(accepted,
                      "Should accept when removed content is known email artifacts")
    }

    /// Verhalten: AI-Output das Einleitungsfloskeln entfernt wird akzeptiert
    /// Bricht wenn: shouldAcceptImprovedTitle() Floskel-Entfernung blockiert
    func test_shouldAcceptImprovedTitle_allowsIntroPhrasesRemoval() {
        let accepted = TaskTitleEngine.shouldAcceptImprovedTitle(
            original: "Erinnere mich daran Herrn Mueller anzurufen",
            improved: "Herrn Mueller anrufen"
        )
        XCTAssertTrue(accepted,
                      "Should accept when removed content is intro phrases")
    }

    /// Verhalten: Minimale Aenderungen werden immer akzeptiert
    /// Bricht wenn: shouldAcceptImprovedTitle() minimale Aenderungen blockiert
    func test_shouldAcceptImprovedTitle_allowsMinorChanges() {
        let accepted = TaskTitleEngine.shouldAcceptImprovedTitle(
            original: "Einkaufen gehen ",
            improved: "Einkaufen gehen"
        )
        XCTAssertTrue(accepted,
                      "Should accept minor whitespace changes")
    }

    /// Verhalten: Titel mit "Projekt:" Prefix wird geschuetzt
    /// Bricht wenn: Safety Guard beliebige Doppelpunkt-Prefixe nicht erkennt
    func test_shouldAcceptImprovedTitle_rejectsProjektPrefixRemoval() {
        let accepted = TaskTitleEngine.shouldAcceptImprovedTitle(
            original: "Projekt: Aufgabe erledigen",
            improved: "Aufgabe erledigen"
        )
        XCTAssertFalse(accepted,
                       "Should reject removal of 'Projekt:' prefix — it's user content, not metadata")
    }

    /// Verhalten: AI-Output das Urgency-Keywords entfernt wird akzeptiert
    /// Bricht wenn: shouldAcceptImprovedTitle() Urgency-Entfernung blockiert
    func test_shouldAcceptImprovedTitle_allowsUrgencyRemoval() {
        let accepted = TaskTitleEngine.shouldAcceptImprovedTitle(
            original: "Dringend: Server-Problem fixen ASAP!",
            improved: "Server-Problem fixen"
        )
        XCTAssertTrue(accepted,
                      "Should accept when removed content is urgency keywords")
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

    /// Verhalten: Titel mit "naechste Woche" gibt true zurueck
    /// Bricht wenn: titleContainsDateKeyword() zusammengesetzte Phrasen nicht erkennt
    func test_titleContainsDateKeyword_returnsTrue_forNaechsteWocheTitle() {
        XCTAssertTrue(TaskTitleEngine.titleContainsDateKeyword("Naechste Woche Meeting planen"),
                      "Title containing 'naechste woche' should return true")
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
