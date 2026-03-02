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
}
