import XCTest
import SwiftData
@testable import FocusBlox

/// Umfassende Tests für das gesamte Keyword-Erkennungssystem.
///
/// Deckt ab:
/// - Urgency-Keywords: "dringend", "urgent", "asap", "sofort", "eilig"
/// - Importance-Keywords: "wichtig", "unwichtig" (TODO: nicht implementiert)
/// - Datum-Keywords: "heute", "morgen", Wochentage etc.
/// - Dauer-Keywords: Zeitangaben im Titel (TODO: nicht implementiert)
/// - Standalone-Keyword-Stripping: Keywords OHNE Klammern/Doppelpunkt
/// - Negative Tests: Tasks OHNE Keywords dürfen keine deterministischen Attribute bekommen
/// - Kombinations-Tests: Mehrere Keywords gleichzeitig
/// - Word-Boundary-Tests: Teilwörter dürfen nicht matchen
@MainActor
final class KeywordSystemTests: XCTestCase {

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

    // MARK: - 1. URGENCY KEYWORD STRIPPING (Standalone)

    /// User tippt "Dringend ein paar Aufgaben erledigen".
    /// Erwartet: "dringend" wird aus dem Titel ENTFERNT.
    /// Bricht wenn: stripKeywords() standalone "dringend" nicht entfernt (nur Klammer/Prefix-Format)
    func test_stripKeywords_removesStandaloneDringend() {
        let result = TaskTitleEngine.stripKeywords("Dringend ein paar Aufgaben erledigen")
        XCTAssertFalse(result.lowercased().contains("dringend"),
                       "Standalone 'Dringend' muss aus dem Titel entfernt werden, got: '\(result)'")
        XCTAssertTrue(result.contains("Aufgaben erledigen"),
                      "Der Rest des Titels muss erhalten bleiben")
    }

    /// "sofort Arzt anrufen" — standalone sofort muss entfernt werden
    func test_stripKeywords_removesStandaloneSofort() {
        let result = TaskTitleEngine.stripKeywords("sofort Arzt anrufen")
        XCTAssertFalse(result.lowercased().contains("sofort"),
                       "Standalone 'sofort' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Arzt anrufen")
    }

    /// "eilig Paket abholen" — standalone eilig muss entfernt werden
    func test_stripKeywords_removesStandaloneEilig() {
        let result = TaskTitleEngine.stripKeywords("eilig Paket abholen")
        XCTAssertFalse(result.lowercased().contains("eilig"),
                       "Standalone 'eilig' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Paket abholen")
    }

    /// "Server urgent fixen" — standalone urgent in der Mitte
    func test_stripKeywords_removesStandaloneUrgentInMiddle() {
        let result = TaskTitleEngine.stripKeywords("Server urgent fixen")
        XCTAssertFalse(result.lowercased().contains("urgent"),
                       "Standalone 'urgent' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Server fixen")
    }

    /// "Steuern ASAP abgeben" — standalone ASAP
    func test_stripKeywords_removesStandaloneASAP() {
        let result = TaskTitleEngine.stripKeywords("Steuern ASAP abgeben")
        XCTAssertFalse(result.lowercased().contains("asap"),
                       "Standalone 'ASAP' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Steuern abgeben")
    }

    /// Case-insensitiv: "DRINGEND Steuern machen"
    func test_stripKeywords_removesStandaloneDringendCaseInsensitive() {
        let result = TaskTitleEngine.stripKeywords("DRINGEND Steuern machen")
        XCTAssertFalse(result.lowercased().contains("dringend"),
                       "'DRINGEND' (uppercase) muss entfernt werden, got: '\(result)'")
    }

    /// "Aufgabe am Ende dringend" — Keyword am Satzende
    func test_stripKeywords_removesStandaloneDringendAtEnd() {
        let result = TaskTitleEngine.stripKeywords("Aufgabe am Ende dringend")
        XCTAssertFalse(result.lowercased().contains("dringend"),
                       "'dringend' am Satzende muss entfernt werden, got: '\(result)'")
    }

    // MARK: - 2. IMPORTANCE KEYWORD STRIPPING

    /// User tippt "Wichtig Steuer machen".
    /// Erwartet: "wichtig" wird aus dem Titel entfernt.
    /// Bricht wenn: stripKeywords() "wichtig" nicht als Keyword kennt
    func test_stripKeywords_removesStandaloneWichtig() {
        let result = TaskTitleEngine.stripKeywords("Wichtig Steuer machen")
        XCTAssertFalse(result.lowercased().contains("wichtig"),
                       "Standalone 'Wichtig' muss aus dem Titel entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Steuer machen")
    }

    /// "(wichtig) Steuer machen" — Klammer-Format
    func test_stripKeywords_removesParenthesizedWichtig() {
        let result = TaskTitleEngine.stripKeywords("Steuer machen (wichtig)")
        XCTAssertFalse(result.lowercased().contains("wichtig"),
                       "'(wichtig)' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Steuer machen")
    }

    /// "wichtig: Steuer machen" — Prefix-Format
    func test_stripKeywords_removesWichtigPrefix() {
        let result = TaskTitleEngine.stripKeywords("wichtig: Steuer machen")
        XCTAssertFalse(result.lowercased().contains("wichtig"),
                       "'wichtig:' Prefix muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Steuer machen")
    }

    /// "important: Fix the build" — englisches Keyword
    func test_stripKeywords_removesImportantPrefix() {
        let result = TaskTitleEngine.stripKeywords("important: Fix the build")
        XCTAssertFalse(result.lowercased().contains("important"),
                       "'important:' Prefix muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Fix the build")
    }

    /// "Fix the build (important)" — englisch in Klammern
    func test_stripKeywords_removesParenthesizedImportant() {
        let result = TaskTitleEngine.stripKeywords("Fix the build (important)")
        XCTAssertFalse(result.lowercased().contains("important"),
                       "'(important)' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Fix the build")
    }

    /// "unwichtig Schublade aufräumen" — niedrige Wichtigkeit
    func test_stripKeywords_removesStandaloneUnwichtig() {
        let result = TaskTitleEngine.stripKeywords("unwichtig Schublade aufräumen")
        XCTAssertFalse(result.lowercased().contains("unwichtig"),
                       "'unwichtig' muss aus dem Titel entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Schublade aufräumen")
    }

    // MARK: - 3. IMPORTANCE KEYWORD EXTRACTION (Attribute setzen)

    /// "Wichtig Steuer machen" → importance=3 setzen
    /// Bricht wenn: improveTitleIfNeeded() keine Importance-Keyword-Erkennung hat
    func test_improveTitleIfNeeded_setsImportanceHigh_whenWichtigPresent() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Wichtig Steuer machen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.importance, 3,
                       "Keyword 'Wichtig' muss importance=3 setzen, got: \(task.importance as Any)")
    }

    /// "(important) Fix the build" → importance=3
    func test_improveTitleIfNeeded_setsImportanceHigh_whenImportantPresent() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Fix the build (important)")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.importance, 3,
                       "Keyword 'important' muss importance=3 setzen, got: \(task.importance as Any)")
    }

    /// "unwichtig Schublade aufräumen" → importance=1
    func test_improveTitleIfNeeded_setsImportanceLow_whenUnwichtigPresent() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "unwichtig Schublade aufräumen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.importance, 1,
                       "Keyword 'unwichtig' muss importance=1 setzen, got: \(task.importance as Any)")
    }

    /// User hat importance=2 manuell gesetzt + "wichtig" im Titel → User-Wert bleibt
    func test_improveTitleIfNeeded_doesNotOverwriteExistingImportance() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Wichtig Steuern machen", importance: 2)
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.importance, 2,
                       "User-gesetzte Importance darf nicht überschrieben werden")
    }

    // MARK: - 4. NEGATIVE TESTS — Kein Keyword → kein Attribut

    /// "Rattenfalle neu mit Erdnussbutter bestücken" — KEIN Keyword.
    /// Erwartet: importance bleibt nil, urgency bleibt nil (deterministisch).
    /// Bricht wenn: Code pauschal Attribute setzt ohne Keyword-Erkennung
    func test_improveTitleIfNeeded_doesNotSetImportance_forGenericTitle() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Rattenfalle neu mit Erdnussbutter bestücken")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        // Deterministisch darf KEIN importance gesetzt werden
        // (AI darf es später setzen, aber improveTitleIfNeeded darf es nicht deterministisch)
        // Prüfen ob der deterministische Schritt importance auf nil lässt:
        // Hinweis: Wenn AI verfügbar ist, setzt enrichWithSuggestions suggestedCategory/Duration,
        // aber NICHT importance direkt.
        XCTAssertNil(task.importance,
                     "Task ohne Importance-Keyword darf deterministisch keine Importance bekommen, got: \(task.importance as Any)")
    }

    /// "Einkaufen gehen" — Kein Urgency-Keyword → urgency bleibt nil
    func test_improveTitleIfNeeded_doesNotSetUrgency_forGenericTitle() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen gehen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertNil(task.urgency,
                     "Task ohne Urgency-Keyword darf deterministisch keine Urgency bekommen, got: \(task.urgency as Any)")
    }

    /// Normaler Titel → Titel bleibt UNVERÄNDERT
    func test_stripKeywords_leavesGenericTitleCompletelyUnchanged() {
        let title = "Rattenfalle neu mit Erdnussbutter bestücken"
        let result = TaskTitleEngine.stripKeywords(title)
        XCTAssertEqual(result, title,
                       "Titel ohne Keywords darf nicht verändert werden")
    }

    /// Noch ein normaler Titel
    func test_stripKeywords_leavesAnotherGenericTitleUnchanged() {
        let title = "Flash-U Aufgaben erledigen"
        let result = TaskTitleEngine.stripKeywords(title)
        XCTAssertEqual(result, title,
                       "Titel ohne Keywords darf nicht verändert werden, got: '\(result)'")
    }

    // MARK: - 5. WORD-BOUNDARY TESTS (Teilwort-Schutz)

    /// "Wichtigtuerei vermeiden" — "wichtig" als Teilwort darf NICHT matchen
    func test_stripKeywords_preservesWichtigAsPartOfWord() {
        let result = TaskTitleEngine.stripKeywords("Wichtigtuerei vermeiden")
        XCTAssertEqual(result, "Wichtigtuerei vermeiden",
                       "'Wichtigtuerei' enthält 'wichtig' als Substring — darf NICHT entfernt werden")
    }

    /// "Dringlichkeit besprechen" — "dringend"-Substring darf nicht matchen
    func test_stripKeywords_preservesDringlichkeit() {
        let result = TaskTitleEngine.stripKeywords("Dringlichkeit besprechen")
        XCTAssertEqual(result, "Dringlichkeit besprechen",
                       "'Dringlichkeit' darf nicht als 'dringend'-Keyword erkannt werden")
    }

    /// "Morgengymnastik machen" — bereits getestet, hier zur Vollständigkeit
    func test_stripKeywords_preservesMorgengymnastik() {
        let result = TaskTitleEngine.stripKeywords("Morgengymnastik machen")
        XCTAssertEqual(result, "Morgengymnastik machen",
                       "'Morgengymnastik' darf nicht 'Morgen' verlieren")
    }

    /// "Unwichtiges Zeug wegwerfen" — Teilwort darf nicht matchen
    func test_stripKeywords_preservesUnwichtigesAsPartOfWord() {
        let result = TaskTitleEngine.stripKeywords("Unwichtiges Zeug wegwerfen")
        XCTAssertEqual(result, "Unwichtiges Zeug wegwerfen",
                       "'Unwichtiges' (Adjektiv) ist kein exaktes Keyword 'unwichtig'")
    }

    // MARK: - 6. KOMBINATIONS-TESTS (Mehrere Keywords gleichzeitig)

    /// User-Beispiel: "Dringend und wichtig ein paar Flash-U Aufgaben erledigen"
    /// Erwartet: Beide Keywords entfernt, urgency + importance gesetzt
    func test_stripKeywords_removesBothDringendAndWichtig() {
        let result = TaskTitleEngine.stripKeywords("Dringend und wichtig ein paar Flash-U Aufgaben erledigen")
        XCTAssertFalse(result.lowercased().contains("dringend"),
                       "'Dringend' muss entfernt werden, got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("wichtig"),
                       "'wichtig' muss entfernt werden, got: '\(result)'")
        // "und" darf auch entfernt werden wenn es als Verbinder zwischen Keywords steht
        XCTAssertTrue(result.contains("Flash-U Aufgaben erledigen"),
                      "Der eigentliche Inhalt muss erhalten bleiben, got: '\(result)'")
    }

    /// End-to-End: "Dringend und wichtig ein paar Flash-U Aufgaben erledigen"
    /// → urgency="urgent", importance=3, sauberer Titel
    func test_improveTitleIfNeeded_setsUrgencyAndImportance_whenBothKeywordsPresent() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Dringend und wichtig ein paar Flash-U Aufgaben erledigen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.urgency, "urgent",
                       "'Dringend' muss urgency='urgent' setzen, got: \(task.urgency as Any)")
        XCTAssertEqual(task.importance, 3,
                       "'wichtig' muss importance=3 setzen, got: \(task.importance as Any)")
        XCTAssertFalse(task.title.lowercased().contains("dringend"),
                       "'Dringend' muss aus dem Titel entfernt sein, got: '\(task.title)'")
        XCTAssertFalse(task.title.lowercased().contains("wichtig"),
                       "'wichtig' muss aus dem Titel entfernt sein, got: '\(task.title)'")
    }

    /// "Heute dringend wichtig Klingel demontieren"
    /// → dueDate=heute, urgency=urgent, importance=3, Titel="Klingel demontieren"
    func test_improveTitleIfNeeded_handlesTripleKeywordCombination() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Heute dringend wichtig Klingel demontieren")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertNotNil(task.dueDate,
                        "'Heute' muss dueDate setzen")
        XCTAssertEqual(task.urgency, "urgent",
                       "'dringend' muss urgency='urgent' setzen")
        XCTAssertEqual(task.importance, 3,
                       "'wichtig' muss importance=3 setzen")
        XCTAssertFalse(task.title.lowercased().contains("heute"),
                       "'Heute' muss aus dem Titel entfernt sein")
        XCTAssertFalse(task.title.lowercased().contains("dringend"),
                       "'dringend' muss aus dem Titel entfernt sein")
        XCTAssertFalse(task.title.lowercased().contains("wichtig"),
                       "'wichtig' muss aus dem Titel entfernt sein")
        XCTAssertTrue(task.title.contains("Klingel demontieren"),
                      "Der eigentliche Inhalt muss erhalten bleiben")
    }

    /// "(dringend) (wichtig) Steuer machen" — Klammer-Format für beide
    func test_stripKeywords_removesBothParenthesizedKeywords() {
        let result = TaskTitleEngine.stripKeywords("(dringend) (wichtig) Steuer machen")
        XCTAssertFalse(result.contains("dringend"), "got: '\(result)'")
        XCTAssertFalse(result.contains("wichtig"), "got: '\(result)'")
        XCTAssertEqual(result, "Steuer machen")
    }

    // MARK: - 7. DAUER-KEYWORD-ERKENNUNG

    /// "30min Einkaufen gehen" → estimatedDuration=30, Keyword entfernt
    /// Bricht wenn: Dauer-Keywords nicht implementiert sind
    func test_stripKeywords_removesDurationKeyword_30min() {
        let result = TaskTitleEngine.stripKeywords("30min Einkaufen gehen")
        XCTAssertFalse(result.contains("30min"),
                       "'30min' muss aus dem Titel entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Einkaufen gehen")
    }

    /// "Einkaufen (45 min)" → Duration-Keyword in Klammern
    func test_stripKeywords_removesDurationInParentheses() {
        let result = TaskTitleEngine.stripKeywords("Einkaufen (45 min)")
        XCTAssertFalse(result.contains("45"),
                       "'(45 min)' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Einkaufen")
    }

    /// "1h Meeting vorbereiten" → estimatedDuration=60
    func test_stripKeywords_removesDurationKeyword_1h() {
        let result = TaskTitleEngine.stripKeywords("1h Meeting vorbereiten")
        XCTAssertFalse(result.contains("1h"),
                       "'1h' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Meeting vorbereiten")
    }

    /// "Meeting vorbereiten 15 Minuten" → Langform
    func test_stripKeywords_removesDurationKeyword_minuten() {
        let result = TaskTitleEngine.stripKeywords("Meeting vorbereiten 15 Minuten")
        XCTAssertFalse(result.contains("15"),
                       "'15 Minuten' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Meeting vorbereiten")
    }

    /// Dauer-Extraktion als Attribut
    func test_improveTitleIfNeeded_setsDuration_whenDurationKeywordPresent() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "30min Einkaufen gehen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.estimatedDuration, 30,
                       "'30min' muss estimatedDuration=30 setzen, got: \(task.estimatedDuration as Any)")
    }

    /// "1h Deep Work Session" → 60 Minuten
    func test_improveTitleIfNeeded_setsDuration_1hour() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "1h Deep Work Session")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.estimatedDuration, 60,
                       "'1h' muss estimatedDuration=60 setzen, got: \(task.estimatedDuration as Any)")
    }

    /// Keine Dauer im Titel → estimatedDuration bleibt nil
    func test_improveTitleIfNeeded_doesNotSetDuration_forGenericTitle() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen gehen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertNil(task.estimatedDuration,
                     "Task ohne Dauer-Keyword darf keine estimatedDuration bekommen (deterministisch)")
    }

    /// User hat Dauer manuell gesetzt → nicht überschreiben
    func test_improveTitleIfNeeded_doesNotOverwriteExistingDuration() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "30min Einkaufen gehen")
        task.estimatedDuration = 45
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.estimatedDuration, 45,
                       "User-gesetzte Duration darf nicht überschrieben werden")
    }

    // MARK: - 8. SIRI/SHORTCUTS INTENT — End-to-End

    /// CreateTaskIntent mit "Dringend und wichtig Flash-U Aufgaben erledigen"
    /// → Nach improveTitleIfNeeded: urgency + importance gesetzt, Keywords entfernt
    func test_createTaskIntent_keywordsProcessedOnImprovement() async throws {
        let context = container.mainContext

        // Simuliere was CreateTaskIntent tut:
        let title = "Dringend und wichtig Flash-U Aufgaben erledigen"
        let task = LocalTask(title: title)
        task.dueDate = TaskTitleEngine.extractDeterministicDueDate(from: title)
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        // Simuliere was beim nächsten App-Start passiert:
        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.urgency, "urgent",
                       "Intent-Task mit 'Dringend' muss urgency='urgent' bekommen")
        XCTAssertEqual(task.importance, 3,
                       "Intent-Task mit 'wichtig' muss importance=3 bekommen")
        XCTAssertFalse(task.title.lowercased().contains("dringend"),
                       "'Dringend' muss aus dem Titel entfernt sein nach Improvement")
        XCTAssertFalse(task.title.lowercased().contains("wichtig"),
                       "'wichtig' muss aus dem Titel entfernt sein nach Improvement")
    }

    /// CreateTaskIntent mit normalem Titel — KEINE Attribute setzen
    func test_createTaskIntent_noKeywords_noAttributes() async throws {
        let context = container.mainContext

        let title = "Flash-U Aufgaben erledigen"
        let task = LocalTask(title: title)
        task.dueDate = TaskTitleEngine.extractDeterministicDueDate(from: title)
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertNil(task.urgency,
                     "Ohne Urgency-Keyword darf deterministisch keine Urgency gesetzt werden")
        XCTAssertNil(task.importance,
                     "Ohne Importance-Keyword darf deterministisch keine Importance gesetzt werden")
        XCTAssertEqual(task.title, "Flash-U Aufgaben erledigen",
                       "Titel ohne Keywords darf nicht verändert werden")
    }

    // MARK: - 8b. DETERMINISTISCH VOR AI — Reihenfolge-Tests

    /// Kerntest: Wenn importance=nil und "wichtig" im Titel → importance=3 setzen
    /// Bricht wenn: deterministic Extraktion "wichtig" nicht erkennt
    func test_deterministicExtraction_setsImportance_whenNilAndKeywordPresent() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Wichtig Steuern machen")
        // importance ist nil — deterministic soll 3 setzen
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.importance, 3,
                       "'Wichtig' im Titel muss importance=3 setzen wenn nil")
    }

    /// Wenn urgency=nil und "dringend" im Titel → urgency="urgent" setzen
    func test_deterministicExtraction_setsUrgency_whenNilAndKeywordPresent() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Dringend Arzt anrufen")
        // urgency ist nil — deterministic soll "urgent" setzen
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.urgency, "urgent",
                       "'Dringend' im Titel muss urgency='urgent' setzen wenn nil")
    }

    /// Kein Keyword → AI-Wert bleibt erhalten (deterministic darf NICHT überschreiben)
    func test_deterministicExtraction_preservesAI_whenNoKeyword() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen gehen")
        // Simuliere: AI hat importance=2 gesetzt
        task.importance = 2
        task.urgency = "not_urgent"
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.importance, 2,
                       "Ohne Keyword darf deterministic den AI-Wert nicht ändern")
        XCTAssertEqual(task.urgency, "not_urgent",
                       "Ohne Keyword darf deterministic den AI-Wert nicht ändern")
    }

    /// Full-Pipeline-Test: createTask() mit Keywords → deterministisch extrahiert, Titel sauber
    /// Simuliert den echten Flow: stripKeywords → create → (kein AI in Test) → improveTitleIfNeeded
    func test_fullPipeline_createTask_withKeywords() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let task = try await source.createTask(title: "Dringend und wichtig 30min Flash-U Aufgaben erledigen")

        // Titel muss sauber sein
        XCTAssertFalse(task.title.lowercased().contains("dringend"),
                       "'Dringend' muss aus Titel entfernt sein, got: '\(task.title)'")
        XCTAssertFalse(task.title.lowercased().contains("wichtig"),
                       "'wichtig' muss aus Titel entfernt sein, got: '\(task.title)'")
        XCTAssertFalse(task.title.contains("30min"),
                       "'30min' muss aus Titel entfernt sein, got: '\(task.title)'")

        // Attribute müssen gesetzt sein
        XCTAssertEqual(task.urgency, "urgent",
                       "'Dringend' muss urgency='urgent' setzen")
        XCTAssertEqual(task.importance, 3,
                       "'wichtig' muss importance=3 setzen")
        XCTAssertEqual(task.estimatedDuration, 30,
                       "'30min' muss estimatedDuration=30 setzen")
    }

    /// Full-Pipeline-Test: createTask() OHNE Keywords → KEINE deterministischen Attribute
    func test_fullPipeline_createTask_withoutKeywords() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let task = try await source.createTask(title: "Flash-U Aufgaben erledigen")

        XCTAssertEqual(task.title, "Flash-U Aufgaben erledigen",
                       "Titel ohne Keywords darf nicht verändert werden")
        // Deterministisch dürfen KEINE Attribute gesetzt werden
        // (AI darf sie setzen, aber das ist ein separater Schritt)
    }

    /// aiScoringEnabled=false → Deterministische Extraktion MUSS trotzdem laufen
    /// Bricht wenn: Guard in improveTitleIfNeeded() deterministische Schritte blockiert
    func test_deterministicExtraction_worksWithoutAI() async throws {
        // AI scoring deaktivieren
        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")
        defer { UserDefaults.standard.set(true, forKey: "aiScoringEnabled") }

        let context = container.mainContext
        let task = LocalTask(title: "Dringend wichtig 30min Steuer machen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        // Auch ohne AI müssen deterministische Keywords verarbeitet werden
        XCTAssertEqual(task.urgency, "urgent",
                       "Deterministische Urgency muss auch ohne AI funktionieren")
        XCTAssertEqual(task.importance, 3,
                       "Deterministische Importance muss auch ohne AI funktionieren")
        XCTAssertEqual(task.estimatedDuration, 30,
                       "Deterministische Duration muss auch ohne AI funktionieren")
        XCTAssertFalse(task.title.lowercased().contains("dringend"),
                       "Keywords müssen auch ohne AI aus Titel entfernt werden")
    }

    // MARK: - 9. REANALYZE — Nachträgliche Keyword-Verarbeitung

    /// reanalyzeTask mit "wichtig Steuer machen" → Keywords entfernt + importance gesetzt
    func test_reanalyzeTask_extractsImportanceKeyword() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "wichtig Steuer machen")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        XCTAssertTrue(changed, "Task mit Keyword muss als geändert markiert werden")
        XCTAssertFalse(task.title.lowercased().contains("wichtig"),
                       "'wichtig' muss nach Reanalyse aus dem Titel entfernt sein")
    }

    /// reanalyzeTask mit normalem Titel und allen Attributen → Titel unverändert
    func test_reanalyzeTask_doesNotChangeGenericTitle() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen gehen")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        task.importance = 2
        task.urgency = "not_urgent"
        task.estimatedDuration = 30
        task.taskType = "maintenance"
        task.aiEnergyLevel = "low"
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        XCTAssertFalse(changed, "Voll attributierter Task ohne Keywords darf nicht geändert werden")
        XCTAssertEqual(task.title, "Einkaufen gehen")
        XCTAssertEqual(task.importance, 2, "Importance darf nicht geändert werden")
        XCTAssertEqual(task.urgency, "not_urgent", "Urgency darf nicht geändert werden")
    }

    // MARK: - 10. REALE SIRI-EINGABEN (Real-World Szenarien)

    /// Siri: "Erstelle einen Task dringend Zahnarzt anrufen"
    func test_realWorldSiri_dringendZahnarzt() {
        let result = TaskTitleEngine.stripKeywords("dringend Zahnarzt anrufen")
        XCTAssertEqual(result, "Zahnarzt anrufen",
                       "Siri-Eingabe: 'dringend' am Anfang muss entfernt werden")
    }

    /// Siri: "Neuer Task wichtig und dringend Steuer abgeben bis Freitag"
    func test_realWorldSiri_wichtigDringendMitDatum() {
        let result = TaskTitleEngine.stripKeywords("wichtig und dringend Steuer abgeben bis Freitag")
        XCTAssertFalse(result.lowercased().contains("wichtig"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("dringend"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("freitag"), "got: '\(result)'")
        XCTAssertTrue(result.contains("Steuer abgeben"), "Kerninhalt muss bleiben")
    }

    /// Siri: "Task heute 30 Minuten joggen gehen" — Datum + Dauer
    func test_realWorldSiri_heuteMitDauer() {
        let result = TaskTitleEngine.stripKeywords("heute 30 Minuten joggen gehen")
        XCTAssertFalse(result.lowercased().contains("heute"), "got: '\(result)'")
        XCTAssertFalse(result.contains("30"), "'30 Minuten' muss entfernt werden, got: '\(result)'")
        XCTAssertTrue(result.lowercased().contains("joggen"), "Kerninhalt muss bleiben")
    }

    /// Siri (Englisch): "Create task urgent important call dentist tomorrow"
    func test_realWorldSiri_englishUrgentImportant() {
        let result = TaskTitleEngine.stripKeywords("urgent important call dentist tomorrow")
        XCTAssertFalse(result.lowercased().contains("urgent"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("important"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("tomorrow"), "got: '\(result)'")
        XCTAssertTrue(result.lowercased().contains("call dentist"), "Kerninhalt muss bleiben")
    }

    // MARK: - 11. EDGE CASES

    /// Titel besteht NUR aus Keywords → leerer String oder sinnvoller Fallback
    func test_stripKeywords_handlesKeywordsOnlyTitle() {
        let result = TaskTitleEngine.stripKeywords("Dringend wichtig heute")
        // Nach Entfernen aller Keywords darf kein kaputter Titel übrig bleiben
        XCTAssertFalse(result.lowercased().contains("dringend"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("wichtig"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("heute"), "got: '\(result)'")
        // Leerer String ist akzeptabel
        XCTAssertEqual(result.trimmingCharacters(in: .whitespaces), result,
                       "Kein Leading/Trailing Whitespace")
    }

    /// Doppelte Keywords: "dringend dringend Steuern machen"
    func test_stripKeywords_handlesDoubleKeyword() {
        let result = TaskTitleEngine.stripKeywords("dringend dringend Steuern machen")
        XCTAssertFalse(result.lowercased().contains("dringend"),
                       "Beide 'dringend' müssen entfernt werden, got: '\(result)'")
    }

    /// Keyword mit Satzzeichen: "Dringend! Steuern machen"
    func test_stripKeywords_handlesKeywordWithPunctuation() {
        let result = TaskTitleEngine.stripKeywords("Dringend! Steuern machen")
        // Mindestens das Keyword sollte entfernt werden
        XCTAssertFalse(result.lowercased().contains("dringend"),
                       "'Dringend!' muss erkannt und entfernt werden, got: '\(result)'")
    }

    /// Gemischte Sprachen: "Urgent Einkaufen gehen morgen"
    func test_stripKeywords_handlesMixedLanguages() {
        let result = TaskTitleEngine.stripKeywords("Urgent Einkaufen gehen morgen")
        XCTAssertFalse(result.lowercased().contains("urgent"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("morgen"), "got: '\(result)'")
        XCTAssertTrue(result.contains("Einkaufen gehen"), "Kerninhalt muss bleiben")
    }

    // MARK: - 12. DAUER-KEYWORDS — Erweiterte Varianten

    /// "2h Steuererklärung machen" → 120 Minuten
    func test_stripKeywords_removesDurationKeyword_2h() {
        let result = TaskTitleEngine.stripKeywords("2h Steuererklärung machen")
        XCTAssertFalse(result.contains("2h"),
                       "'2h' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Steuererklärung machen")
    }

    /// "90min Yoga Session" → Nicht nur 5/15/30/60
    func test_stripKeywords_removesDurationKeyword_90min() {
        let result = TaskTitleEngine.stripKeywords("90min Yoga Session")
        XCTAssertFalse(result.contains("90min"),
                       "'90min' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "Yoga Session")
    }

    /// "2 Stunden aufräumen" → Deutsche Langform
    func test_stripKeywords_removesDurationKeyword_stunden() {
        let result = TaskTitleEngine.stripKeywords("2 Stunden aufräumen")
        XCTAssertFalse(result.contains("2"),
                       "'2 Stunden' muss entfernt werden, got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("stunden"),
                       "'Stunden' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "aufräumen")
    }

    /// "1 Stunde lesen" → Singular
    func test_stripKeywords_removesDurationKeyword_stunde() {
        let result = TaskTitleEngine.stripKeywords("1 Stunde lesen")
        XCTAssertFalse(result.contains("1"),
                       "'1 Stunde' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "lesen")
    }

    /// "30 minutes meeting" → Englische Langform
    func test_stripKeywords_removesDurationKeyword_minutes() {
        let result = TaskTitleEngine.stripKeywords("30 minutes meeting")
        XCTAssertFalse(result.contains("30"),
                       "'30 minutes' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "meeting")
    }

    /// "1 hour deep work" → Englisch Singular
    func test_stripKeywords_removesDurationKeyword_hour() {
        let result = TaskTitleEngine.stripKeywords("1 hour deep work")
        XCTAssertFalse(result.contains("1"),
                       "'1 hour' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "deep work")
    }

    /// "2 hours coding" → Englisch Plural
    func test_stripKeywords_removesDurationKeyword_hours() {
        let result = TaskTitleEngine.stripKeywords("2 hours coding")
        XCTAssertFalse(result.contains("2"),
                       "'2 hours' muss entfernt werden, got: '\(result)'")
        XCTAssertEqual(result, "coding")
    }

    /// Dauer-Extraktion: "2h Steuererklärung" → 120 Minuten
    func test_improveTitleIfNeeded_setsDuration_2hours() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "2h Steuererklärung machen")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.estimatedDuration, 120,
                       "'2h' muss estimatedDuration=120 setzen, got: \(task.estimatedDuration as Any)")
    }

    /// Dauer-Extraktion: "90min Yoga" → 90 Minuten
    func test_improveTitleIfNeeded_setsDuration_90min() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "90min Yoga Session")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.estimatedDuration, 90,
                       "'90min' muss estimatedDuration=90 setzen, got: \(task.estimatedDuration as Any)")
    }

    /// Dauer-Extraktion: "15 Minuten Meditation" → 15 Minuten
    func test_improveTitleIfNeeded_setsDuration_15minuten() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "15 Minuten Meditation")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.estimatedDuration, 15,
                       "'15 Minuten' muss estimatedDuration=15 setzen, got: \(task.estimatedDuration as Any)")
    }

    /// Word-Boundary: "Minutenzeiger reparieren" → darf NICHT als Dauer erkannt werden
    func test_stripKeywords_preservesMinutenAsPartOfWord() {
        let result = TaskTitleEngine.stripKeywords("Minutenzeiger reparieren")
        XCTAssertEqual(result, "Minutenzeiger reparieren",
                       "'Minutenzeiger' darf nicht als Dauer-Keyword erkannt werden")
    }

    /// Word-Boundary: "Stundenplan erstellen" → darf NICHT als Dauer erkannt werden
    func test_stripKeywords_preservesStundenAsPartOfWord() {
        let result = TaskTitleEngine.stripKeywords("Stundenplan erstellen")
        XCTAssertEqual(result, "Stundenplan erstellen",
                       "'Stundenplan' darf nicht als Dauer-Keyword erkannt werden")
    }

    // MARK: - 13. cleanTitle() mit neuen Keyword-Typen

    /// cleanTitle muss auch Importance-Keywords entfernen (ruft stripKeywords auf)
    func test_cleanTitle_removesImportanceKeyword() {
        let result = TaskTitleEngine.cleanTitle("wichtig Steuer machen")
        XCTAssertFalse(result.lowercased().contains("wichtig"),
                       "cleanTitle muss 'wichtig' entfernen (via stripKeywords), got: '\(result)'")
    }

    /// cleanTitle muss auch Dauer-Keywords entfernen
    func test_cleanTitle_removesDurationKeyword() {
        let result = TaskTitleEngine.cleanTitle("30min Einkaufen gehen")
        XCTAssertFalse(result.contains("30min"),
                       "cleanTitle muss '30min' entfernen (via stripKeywords), got: '\(result)'")
    }

    /// cleanTitle mit Floskel + Importance + Datum
    func test_cleanTitle_handlesFullKeywordCombination() {
        let result = TaskTitleEngine.cleanTitle("Erinnere mich daran wichtig morgen Steuer machen")
        XCTAssertFalse(result.lowercased().contains("erinnere"), "Floskel muss weg, got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("wichtig"), "Importance muss weg, got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("morgen"), "Datum muss weg, got: '\(result)'")
        XCTAssertTrue(result.contains("Steuer machen"), "Kerninhalt muss bleiben, got: '\(result)'")
    }

    // MARK: - 14. REANALYZE — Batch mit allen Keyword-Typen

    /// reanalyzeTask mit Dauer-Keyword → Duration deterministisch extrahiert
    func test_reanalyzeTask_extractsDurationKeyword() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "30min Einkaufen gehen")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        XCTAssertTrue(changed, "Task mit Dauer-Keyword muss als geändert gelten")
        XCTAssertFalse(task.title.contains("30min"),
                       "'30min' muss aus dem Titel entfernt sein nach Reanalyse")
        XCTAssertEqual(task.estimatedDuration, 30,
                       "estimatedDuration muss deterministisch auf 30 gesetzt werden")
    }

    /// reanalyzeTask mit allen Keyword-Typen gleichzeitig
    func test_reanalyzeTask_handlesAllKeywordTypes() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Heute dringend wichtig 1h Steuererklärung abgeben")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.reanalyzeTask(task)

        // Titel: alle Keywords entfernt
        XCTAssertFalse(task.title.lowercased().contains("heute"), "Datum-Keyword muss weg")
        XCTAssertFalse(task.title.lowercased().contains("dringend"), "Urgency-Keyword muss weg")
        XCTAssertFalse(task.title.lowercased().contains("wichtig"), "Importance-Keyword muss weg")
        XCTAssertFalse(task.title.contains("1h"), "Dauer-Keyword muss weg")
        XCTAssertTrue(task.title.contains("Steuererklärung abgeben"), "Kerninhalt muss bleiben")

        // Attribute: deterministisch gesetzt
        XCTAssertNotNil(task.dueDate, "'Heute' muss dueDate setzen")
        XCTAssertEqual(task.urgency, "urgent", "'dringend' muss urgency='urgent' setzen")
        XCTAssertEqual(task.importance, 3, "'wichtig' muss importance=3 setzen")
        XCTAssertEqual(task.estimatedDuration, 60, "'1h' muss estimatedDuration=60 setzen")
    }

    /// reanalyzeTask: Task ohne Keywords + alle Attribute bereits gesetzt → keine Änderung
    func test_reanalyzeTask_noChangeWhenFullyAttributed() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen gehen")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        task.importance = 2
        task.urgency = "not_urgent"
        task.estimatedDuration = 30
        task.taskType = "maintenance"
        task.aiEnergyLevel = "low"
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        XCTAssertFalse(changed, "Voll attributierter Task ohne Keywords darf nicht geändert werden")
        XCTAssertEqual(task.estimatedDuration, 30, "Bestehende Duration bleibt")
        XCTAssertEqual(task.importance, 2, "Bestehende Importance bleibt")
    }

    /// reanalyzeTask: User hat Duration manuell gesetzt → "30min" im Titel aber Duration bleibt
    func test_reanalyzeTask_doesNotOverwriteExistingDuration() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "30min Meditation machen")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        task.estimatedDuration = 20  // User hat 20 gesetzt
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.reanalyzeTask(task)

        XCTAssertEqual(task.estimatedDuration, 20,
                       "User-gesetzte Duration darf nicht überschrieben werden")
    }

    // MARK: - 15. SIRI Real-World — Erweitert

    /// Siri: "Erstelle Task 30 Minuten joggen gehen wichtig"
    func test_realWorldSiri_dauerUndWichtig() {
        let result = TaskTitleEngine.stripKeywords("30 Minuten joggen gehen wichtig")
        XCTAssertFalse(result.contains("30"), "'30 Minuten' muss weg, got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("minuten"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("wichtig"), "got: '\(result)'")
        XCTAssertTrue(result.lowercased().contains("joggen"), "Kerninhalt muss bleiben")
    }

    /// Siri: "1 Stunde Spanisch lernen morgen"
    func test_realWorldSiri_stundeUndMorgen() {
        let result = TaskTitleEngine.stripKeywords("1 Stunde Spanisch lernen morgen")
        XCTAssertFalse(result.contains("1"), "'1 Stunde' muss weg, got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("stunde"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("morgen"), "got: '\(result)'")
        XCTAssertTrue(result.contains("Spanisch lernen"), "Kerninhalt muss bleiben")
    }

    /// Siri (Englisch): "45 minutes review pull request urgent"
    func test_realWorldSiri_englishDurationUrgent() {
        let result = TaskTitleEngine.stripKeywords("45 minutes review pull request urgent")
        XCTAssertFalse(result.contains("45"), "'45 minutes' muss weg, got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("minutes"), "got: '\(result)'")
        XCTAssertFalse(result.lowercased().contains("urgent"), "got: '\(result)'")
        XCTAssertTrue(result.contains("review pull request"), "Kerninhalt muss bleiben")
    }

    // MARK: - 16. INTENT End-to-End mit Dauer

    /// CreateTaskIntent: "1h Deep Work für Projekt" → Duration + sauberer Titel
    func test_createTaskIntent_durationExtracted() async throws {
        let context = container.mainContext
        let title = "1h Deep Work für Projekt"
        let task = LocalTask(title: title)
        task.dueDate = TaskTitleEngine.extractDeterministicDueDate(from: title)
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.estimatedDuration, 60,
                       "'1h' muss estimatedDuration=60 setzen")
        XCTAssertFalse(task.title.contains("1h"),
                       "'1h' muss aus dem Titel entfernt sein")
    }

    /// CreateTaskIntent: Volle Kombination — alle 4 Keyword-Typen
    func test_createTaskIntent_allKeywordTypes() async throws {
        let context = container.mainContext
        let title = "Morgen dringend wichtig 30min Bewerbung schreiben"
        let task = LocalTask(title: title)
        task.dueDate = TaskTitleEngine.extractDeterministicDueDate(from: title)
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertNotNil(task.dueDate, "'Morgen' muss dueDate setzen")
        XCTAssertEqual(task.urgency, "urgent", "'dringend' muss urgency setzen")
        XCTAssertEqual(task.importance, 3, "'wichtig' muss importance setzen")
        XCTAssertEqual(task.estimatedDuration, 30, "'30min' muss Duration setzen")
        XCTAssertEqual(task.title, "Bewerbung schreiben",
                       "Alle Keywords müssen entfernt sein, nur Kerninhalt bleibt")
    }
}
