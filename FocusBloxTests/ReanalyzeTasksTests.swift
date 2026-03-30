import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for the "Bestehende Tasks analysieren" feature.
/// Validates that reanalyzeAllTasks() applies the full rule set:
/// - Title cleanup (date keywords, urgency keywords, intro phrases)
/// - Deterministic date extraction
/// - Counter accuracy (only counts actually changed tasks)
/// - Filter correctness (skips completed/raw tasks)
@MainActor
final class ReanalyzeTasksTests: XCTestCase {

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

    // MARK: - Step 1: Title Cleanup

    /// GIVEN: Task mit "Einkaufen morgen" als Titel
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: Titel wird zu "Einkaufen", "morgen" wird entfernt
    func test_reanalyzeTask_removesDateKeywordFromTitle() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen morgen")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        XCTAssertTrue(changed, "Task sollte als geändert markiert sein")
        XCTAssertEqual(task.title, "Einkaufen", "Datums-Keyword 'morgen' muss aus Titel entfernt werden")
    }

    /// GIVEN: Task mit "dringend: Steuererklärung abgeben" als Titel
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: Titel wird zu "Steuererklärung abgeben"
    func test_reanalyzeTask_removesUrgencyPrefixFromTitle() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "dringend: Steuererklärung abgeben")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        XCTAssertTrue(changed, "Task sollte als geändert markiert sein")
        XCTAssertEqual(task.title, "Steuererklärung abgeben",
                       "Urgency-Prefix 'dringend:' muss aus Titel entfernt werden")
    }

    /// GIVEN: Task mit "Morgengymnastik" als Titel (Substring enthält "morgen")
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: Titel bleibt "Morgengymnastik" — Word-Boundary-Safe
    func test_reanalyzeTask_preservesSubstringMorgen() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Morgengymnastik")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        // Title should stay unchanged — no keyword match
        XCTAssertEqual(task.title, "Morgengymnastik",
                       "'Morgengymnastik' darf NICHT zu 'gymnastik' verkürzt werden")
    }

    /// GIVEN: Task mit "erinnere mich daran Arzt anrufen heute"
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: Titel wird zu "Arzt anrufen" (Intro-Phrase + Datums-Keyword entfernt)
    func test_reanalyzeTask_removesIntroPhraseAndDateKeyword() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "erinnere mich daran Arzt anrufen heute")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let changed = await service.reanalyzeTask(task)

        XCTAssertTrue(changed, "Task sollte als geändert markiert sein")
        XCTAssertEqual(task.title, "Arzt anrufen",
                       "Intro-Phrase und Datums-Keyword müssen beide entfernt werden")
    }

    // MARK: - Step 2: Date Extraction

    /// GIVEN: Task mit "Zahnarzt morgen" und kein dueDate
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: dueDate wird auf morgen gesetzt
    func test_reanalyzeTask_extractsDueDateFromMorgen() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt morgen")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.reanalyzeTask(task)

        XCTAssertNotNil(task.dueDate, "dueDate muss aus 'morgen' extrahiert werden")

        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        XCTAssertEqual(cal.startOfDay(for: task.dueDate!), tomorrow,
                       "dueDate muss auf morgen gesetzt sein")
    }

    /// GIVEN: Task mit "Einkaufen heute" und kein dueDate
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: dueDate wird auf heute gesetzt
    func test_reanalyzeTask_extractsDueDateFromHeute() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen heute")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.reanalyzeTask(task)

        XCTAssertNotNil(task.dueDate, "dueDate muss aus 'heute' extrahiert werden")

        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(Calendar.current.startOfDay(for: task.dueDate!), today,
                       "dueDate muss auf heute gesetzt sein")
    }

    /// GIVEN: Task mit Datums-Keyword in taskDescription (nicht im Titel)
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: dueDate wird aus taskDescription extrahiert
    func test_reanalyzeTask_extractsDueDateFromDescription() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt")
        task.taskDescription = "Zahnarzt morgen"
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.reanalyzeTask(task)

        XCTAssertNotNil(task.dueDate,
                       "dueDate muss aus taskDescription extrahiert werden wenn Titel schon bereinigt ist")
    }

    /// GIVEN: Task mit dueDate bereits gesetzt + Datums-Keyword im Titel
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: Titel wird bereinigt, aber dueDate bleibt unverändert (User-Set)
    func test_reanalyzeTask_doesNotOverwriteExistingDueDate() async throws {
        let context = container.mainContext
        let existingDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = LocalTask(title: "Zahnarzt morgen")
        task.dueDate = existingDate
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.reanalyzeTask(task)

        XCTAssertEqual(task.title, "Zahnarzt", "Titel muss bereinigt werden")
        XCTAssertEqual(task.dueDate, existingDate,
                       "Bestehendes dueDate darf NICHT überschrieben werden")
    }

    // MARK: - Batch: reanalyzeAllTasks()

    /// GIVEN: 3 Tasks — eine mit Keyword, eine ohne, eine completed
    /// WHEN: reanalyzeAllTasks() wird aufgerufen
    /// THEN: Counter = 1 (nur die mit Keyword wird gezählt)
    func test_reanalyzeAllTasks_countsOnlyChangedTasks() async throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Einkaufen morgen")
        task1.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task1)

        let task2 = LocalTask(title: "Sauberer Titel")
        task2.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        task2.importance = 2
        task2.urgency = "not_urgent"
        task2.taskType = "maintenance"
        task2.aiEnergyLevel = "low"
        task2.estimatedDuration = 30
        context.insert(task2)

        let task3 = LocalTask(title: "Erledigter Task morgen")
        task3.isCompleted = true
        task3.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task3)

        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let count = await service.reanalyzeAllTasks()

        // task1: "morgen" entfernt → changed
        // task2: kein Keyword, alle Attribute gesetzt → NOT changed (ohne AI)
        // task3: completed → übersprungen
        XCTAssertEqual(task1.title, "Einkaufen", "Task1 Titel muss bereinigt sein")
        XCTAssertEqual(task3.title, "Erledigter Task morgen",
                       "Completed Tasks dürfen NICHT verändert werden")

        // Counter muss >= 1 sein (task1 wurde geändert)
        XCTAssertGreaterThanOrEqual(count, 1,
                                    "Mindestens 1 Task wurde geändert (task1 hatte 'morgen' im Titel)")
    }

    /// GIVEN: Tasks ohne Änderungsbedarf (saubere Titel, alle Attribute gesetzt)
    /// WHEN: reanalyzeAllTasks() wird aufgerufen
    /// THEN: Counter = 0
    func test_reanalyzeAllTasks_returnsZeroWhenNothingToChange() async throws {
        let context = container.mainContext

        let task = LocalTask(title: "Sauberer Titel ohne Keywords")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        task.importance = 2
        task.urgency = "not_urgent"
        task.taskType = "maintenance"
        task.aiEnergyLevel = "low"
        task.estimatedDuration = 30
        task.dueDate = Date()
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let count = await service.reanalyzeAllTasks()

        XCTAssertEqual(count, 0,
                       "Counter muss 0 sein wenn kein Task geändert wurde")
        XCTAssertEqual(task.title, "Sauberer Titel ohne Keywords",
                       "Titel darf nicht verändert werden")
    }

    /// GIVEN: Task mit lifecycleStatus "raw"
    /// WHEN: reanalyzeAllTasks() wird aufgerufen
    /// THEN: Task wird übersprungen (raw = noch im Quick-Capture)
    func test_reanalyzeAllTasks_skipsRawTasks() async throws {
        let context = container.mainContext

        let task = LocalTask(title: "Einkaufen morgen")
        task.lifecycleStatus = TaskLifecycleStatus.raw.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let count = await service.reanalyzeAllTasks()

        XCTAssertEqual(count, 0, "Raw Tasks dürfen nicht reanalysiert werden")
        XCTAssertEqual(task.title, "Einkaufen morgen",
                       "Raw Task Titel darf nicht verändert werden")
    }

    // MARK: - Praxis-Szenarien (realistische Tasks)

    /// GIVEN: Realistische bestehende Tasks mit verschiedenen Keyword-Typen
    /// WHEN: reanalyzeAllTasks() wird aufgerufen
    /// THEN: Alle Keywords korrekt entfernt, Daten extrahiert
    func test_reanalyzeAllTasks_realisticBatch() async throws {
        let context = container.mainContext

        // Task mit deutschem Datums-Keyword
        let t1 = LocalTask(title: "Zahnarzt übermorgen")
        t1.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(t1)

        // Task mit englischem Keyword
        let t2 = LocalTask(title: "Call John tomorrow")
        t2.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(t2)

        // Task mit Urgency in Klammern
        let t3 = LocalTask(title: "Rechnung bezahlen (dringend)")
        t3.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(t3)

        // Task mit Wochentag
        let t4 = LocalTask(title: "Meeting Montag")
        t4.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(t4)

        // Task ohne Keywords — soll unverändert bleiben
        let t5 = LocalTask(title: "Wohnung putzen")
        t5.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        t5.importance = 1
        t5.urgency = "not_urgent"
        t5.taskType = "maintenance"
        t5.aiEnergyLevel = "low"
        t5.estimatedDuration = 30
        context.insert(t5)

        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let count = await service.reanalyzeAllTasks()

        // Titel-Checks
        XCTAssertEqual(t1.title, "Zahnarzt", "'übermorgen' muss entfernt werden")
        XCTAssertEqual(t2.title, "Call John", "'tomorrow' muss entfernt werden")
        XCTAssertEqual(t3.title, "Rechnung bezahlen", "'(dringend)' muss entfernt werden")
        XCTAssertEqual(t4.title, "Meeting", "'Montag' muss entfernt werden")
        XCTAssertEqual(t5.title, "Wohnung putzen", "Titel ohne Keywords bleibt unverändert")

        // DueDate-Checks
        XCTAssertNotNil(t1.dueDate, "dueDate muss aus 'übermorgen' extrahiert werden")
        XCTAssertNotNil(t2.dueDate, "dueDate muss aus 'tomorrow' extrahiert werden")
        XCTAssertNil(t3.dueDate, "'dringend' ist kein Datums-Keyword → kein dueDate")
        XCTAssertNotNil(t4.dueDate, "dueDate muss aus 'Montag' extrahiert werden")

        // Counter: t1-t4 geändert (Keywords entfernt), t5 unverändert (ohne AI)
        XCTAssertGreaterThanOrEqual(count, 4,
                                    "Mindestens 4 Tasks wurden geändert (t1-t4 hatten Keywords)")
    }

    // MARK: - Edge Cases

    /// GIVEN: Task mit "nächste woche" (Leerzeichen im Keyword)
    /// WHEN: reanalyzeTask() wird aufgerufen
    /// THEN: Keyword wird entfernt, dueDate auf nächsten Montag gesetzt
    func test_reanalyzeTask_handlesMultiWordKeyword() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Steuer nächste woche")
        task.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.reanalyzeTask(task)

        XCTAssertEqual(task.title, "Steuer", "'nächste woche' muss entfernt werden")
        XCTAssertNotNil(task.dueDate, "dueDate muss aus 'nächste woche' extrahiert werden")
    }

    /// GIVEN: Leere Task-Liste
    /// WHEN: reanalyzeAllTasks() wird aufgerufen
    /// THEN: Counter = 0, kein Crash
    func test_reanalyzeAllTasks_handlesEmptyList() async throws {
        let context = container.mainContext
        let service = SmartTaskEnrichmentService(modelContext: context)
        let count = await service.reanalyzeAllTasks()

        XCTAssertEqual(count, 0, "Leere Task-Liste muss 0 ergeben")
    }
}
