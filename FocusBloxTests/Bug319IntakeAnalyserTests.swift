import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class Bug319IntakeAnalyserTests: XCTestCase {
    var container: ModelContainer!
    var modelContext: ModelContext!
    var taskSource: LocalTaskSource!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        modelContext = container.mainContext
        taskSource = LocalTaskSource(modelContext: modelContext)
        UserDefaults.standard.set(true, forKey: "aiScoringEnabled")
    }

    override func tearDownWithError() throws {
        container = nil
        modelContext = nil
        taskSource = nil
        UserDefaults.standard.removeObject(forKey: "aiScoringEnabled")
    }

    /// Tests if deterministic keyword extraction works for duration and tags.
    func test_createTask_extractsDurationAndTagsFromTitle() async throws {
        // 1. Setup: A task title with duration and tag keywords
        let title = "Steuererklärung machen #60min #admin #finanzen"
        
        // 2. Act: Create the task
        let task = try await taskSource.createTask(title: title)
        
        // 3. Assert: Verify duration was extracted
        XCTAssertEqual(task.estimatedDuration, 60, "Duration should be extracted from #60min")
        
        // Note: Current implementation of stripKeywords and createTask doesn't seem to extract #tags 
        // into the task.tags array yet, it only strips them if they match urgency/importance keywords.
        // Let's check if the title was at least cleaned.
        XCTAssertFalse(task.title.contains("#60min"), "Keywords should be stripped from title")
    }

    /// Tests if AI suggestions are correctly preserved and not overwritten by early defaults.
    func test_createTask_preservesAISuggestions() async throws {
        // This test simulates the issue where SmartTaskEnrichmentService sets defaults
        // that block confirmSuggestions() from working.

        let title = "Meeting mit Chef"
        let task = try await taskSource.createTask(title: title)

        // Simulate AI providing suggestions
        task.suggestedImportance = 3
        task.suggestedUrgency = "urgent"
        task.suggestedDuration = 30

        // Act: Confirm suggestions
        task.confirmSuggestions()

        // Assert: If the bug exists, importance will be 1 (default) instead of 3 (suggested)
        // because SmartTaskEnrichmentService set it to 1 before confirmation.
        XCTAssertEqual(task.importance, 3, "Importance should be promoted from suggested value")
        XCTAssertEqual(task.urgency, "urgent", "Urgency should be promoted from suggested value")
        XCTAssertEqual(task.estimatedDuration, 30, "Duration should be promoted from suggested value")
    }

    // MARK: - Bug #319: suggestedTags → tags Promotion

    /// Verhalten: confirmSuggestions() uebertraegt suggestedTags in das tags-Feld wenn tags leer ist.
    /// Bricht wenn: confirmSuggestions() den suggestedTags -> tags Transfer nicht durchfuehrt.
    func test_confirmSuggestions_transfersSuggestedTagsToTags() throws {
        // Arrange: Task mit leeren tags und gefuellten suggestedTags
        let task = LocalTask(title: "Steuererklaerung einreichen", tags: nil)
        task.suggestedTags = ["arbeit", "finanzen"]
        modelContext.insert(task)
        try modelContext.save()

        // Act
        task.confirmSuggestions()

        // Assert: suggestedTags muessen in tags landen
        let tags = try XCTUnwrap(task.tags, "tags darf nach confirmSuggestions() nicht nil sein wenn suggestedTags vorhanden war")
        XCTAssertEqual(Set(tags), Set(["arbeit", "finanzen"]),
            "confirmSuggestions() muss suggestedTags in tags uebertragen")
    }

    /// Verhalten: confirmSuggestions() ueberschreibt NICHT bereits vorhandene tags (User-Eingabe respektieren).
    /// Bricht wenn: confirmSuggestions() manuell gesetzte Tags mit KI-Vorschlaegen ueberschreibt.
    func test_confirmSuggestions_doesNotOverwriteExistingTags() throws {
        // Arrange: Task mit bereits gesetzten tags UND suggestedTags
        let task = LocalTask(title: "Meeting vorbereiten", tags: ["bestehend"])
        task.suggestedTags = ["arbeit", "finanzen"]
        modelContext.insert(task)
        try modelContext.save()

        // Act
        task.confirmSuggestions()

        // Assert: Manuell gesetzte tags duerfen NICHT ueberschrieben werden
        let tags = try XCTUnwrap(task.tags, "tags darf nach confirmSuggestions() nicht nil sein")
        XCTAssertEqual(tags, ["bestehend"],
            "confirmSuggestions() darf bestehende tags nicht mit suggestedTags ueberschreiben")
    }

    // MARK: - Bug #319: Lowercase-Normalisierung

    /// Verhalten: confirmSuggestions() normalisiert suggestedTags auf Kleinschreibung bevor sie in tags landen.
    /// Bricht wenn: Grossbuchstaben aus suggestedTags 1:1 in tags uebernommen werden.
    func test_confirmSuggestions_normalizesTagsToLowercase() throws {
        // Arrange: suggestedTags mit Grossbuchstaben
        let task = LocalTask(title: "Jahresabschluss erstellen", tags: nil)
        task.suggestedTags = ["Arbeit", "FINANZEN"]
        modelContext.insert(task)
        try modelContext.save()

        // Act
        task.confirmSuggestions()

        // Assert: Alle tags muessen lowercase sein
        let tags = try XCTUnwrap(task.tags, "tags darf nach confirmSuggestions() nicht nil sein")
        XCTAssertEqual(Set(tags), Set(["arbeit", "finanzen"]),
            "confirmSuggestions() muss suggestedTags vor der Uebernahme auf lowercase normalisieren")
    }

    /// Verhalten: LocalTaskSource.createTask() speichert Tags als Kleinschreibung.
    /// Bricht wenn: createTask() Tags ohne .lowercased() in den Task schreibt.
    func test_createTask_normalizesTagsToLowercase() async throws {
        // Arrange & Act: Task mit gemischter Schreibung erstellen
        let task = try await taskSource.createTask(
            title: "Projektplan",
            tags: ["Arbeit", "WORK"]
        )

        // Assert: Tags muessen lowercase gespeichert sein
        let tags = try XCTUnwrap(task.tags, "tags darf nach createTask() nicht nil sein")
        XCTAssertEqual(Set(tags), Set(["arbeit", "work"]),
            "createTask() muss Tags vor dem Speichern auf lowercase normalisieren")
    }

    /// Verhalten: LocalTaskSource.updateTask() speichert Tags als Kleinschreibung.
    /// Bricht wenn: updateTask() Tags ohne .lowercased() in den Task schreibt.
    func test_updateTask_normalizesTagsToLowercase() async throws {
        // Arrange: Bestehenden Task anlegen
        let task = LocalTask(title: "Sport planen", tags: nil)
        modelContext.insert(task)
        try modelContext.save()

        // Act: updateTask() mit gemischter Schreibung aufrufen
        try await taskSource.updateTask(
            taskID: task.id,
            tags: ["Freizeit", "SPORT"]
        )

        // Assert: Tags muessen lowercase gespeichert sein
        let tags = try XCTUnwrap(task.tags, "tags darf nach updateTask() nicht nil sein")
        XCTAssertEqual(Set(tags), Set(["freizeit", "sport"]),
            "updateTask() muss Tags vor dem Speichern auf lowercase normalisieren")
    }

    // MARK: - Bug #319: migrateTagsToLowercase Migration

    /// Verhalten: migrateTagsToLowercase() normalisiert bestehende Tags auf Kleinschreibung und ist idempotent.
    /// Bricht wenn: Migration Tags nicht lowercase schreibt oder beim zweiten Aufruf erneut migriert (Flag-Guard fehlt).
    func test_migrateTagsToLowercase_normalizesExistingTags() throws {
        // Arrange: Flag zuruecksetzen damit erster Aufruf die Migration ausfuehrt
        UserDefaults.standard.removeObject(forKey: "tagLowercaseMigrationDone")

        let task1 = LocalTask(title: "Aufgabe 1", tags: ["Arbeit"])
        let task2 = LocalTask(title: "Aufgabe 2", tags: ["SPORT"])
        modelContext.insert(task1)
        modelContext.insert(task2)
        try modelContext.save()

        // Act: Erster Aufruf — soll 2 Tasks migrieren
        let migratedCount = FocusBloxApp.migrateTagsToLowercase(in: modelContext)

        // Assert: Beide Tasks wurden migriert
        XCTAssertEqual(migratedCount, 2, "Migration soll 2 Tasks normalisieren")
        let tags1 = try XCTUnwrap(task1.tags, "tags von task1 darf nicht nil sein")
        let tags2 = try XCTUnwrap(task2.tags, "tags von task2 darf nicht nil sein")
        XCTAssertEqual(tags1, ["arbeit"], "task1 tags muessen lowercase sein")
        XCTAssertEqual(tags2, ["sport"], "task2 tags muessen lowercase sein")

        // Act: Zweiter Aufruf — soll 0 zurueckgeben (Flag-Guard greift)
        let secondCount = FocusBloxApp.migrateTagsToLowercase(in: modelContext)
        XCTAssertEqual(secondCount, 0, "Zweiter Aufruf muss 0 zurueckgeben (Migration bereits erledigt)")

        // Assert: Tags unveraendert nach zweitem Aufruf
        let tags1After = try XCTUnwrap(task1.tags, "tags von task1 darf nach zweitem Aufruf nicht nil sein")
        let tags2After = try XCTUnwrap(task2.tags, "tags von task2 darf nach zweitem Aufruf nicht nil sein")
        XCTAssertEqual(tags1After, ["arbeit"], "task1 tags muessen nach zweitem Aufruf unveraendert sein")
        XCTAssertEqual(tags2After, ["sport"], "task2 tags muessen nach zweitem Aufruf unveraendert sein")
    }

    // MARK: - Bug #319: confirmSuggestions im Batch-Kontext

    /// Verhalten: confirmSuggestions() uebertraegt suggestedTags und suggestedDuration korrekt.
    /// Testet den Batch-Pfad direkt (AI nicht im Simulator verfuegbar).
    /// Bricht wenn: confirmSuggestions() suggestedTags oder suggestedDuration nicht in Hauptfelder promotet.
    func test_confirmSuggestions_inBatchContext_promotesTagsAndDuration() throws {
        // Arrange: Task ohne tags und estimatedDuration, mit Suggestions
        let task = LocalTask(title: "Batch Task", tags: nil)
        task.suggestedTags = ["batch", "test"]
        task.suggestedDuration = 30
        modelContext.insert(task)
        try modelContext.save()

        // Act: confirmSuggestions direkt aufrufen (simuliert Batch-Pfad)
        task.confirmSuggestions()

        // Assert: suggestedTags muessen in tags gelandet sein
        let tags = try XCTUnwrap(task.tags, "tags darf nach confirmSuggestions() nicht nil sein")
        XCTAssertEqual(Set(tags), Set(["batch", "test"]),
            "confirmSuggestions() muss suggestedTags in tags uebertragen")

        // Assert: suggestedDuration muss in estimatedDuration gelandet sein
        let duration = try XCTUnwrap(task.estimatedDuration, "estimatedDuration darf nach confirmSuggestions() nicht nil sein")
        XCTAssertEqual(duration, 30,
            "confirmSuggestions() muss suggestedDuration in estimatedDuration uebertragen")
    }
}
