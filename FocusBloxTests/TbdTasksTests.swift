import XCTest
import SwiftData
@testable import FocusBlox

/// TDD RED Tests für TBD Tasks (Unvollständige Tasks)
/// Spec: docs/specs/features/tbd-tasks.md
///
/// Diese Tests prüfen:
/// 1. Optionale Felder (importance, urgency, estimatedDuration)
/// 2. isTbd computed property
/// 3. Keine Fake-Defaults
/// 4. Umbenennung priority → importance
@MainActor
final class TbdTasksTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Optionale Felder

    /// GIVEN: Ein neuer Task wird mit nur Titel erstellt
    /// WHEN: Die Felder importance, urgency, estimatedDuration abgefragt werden
    /// THEN: Alle drei sollten nil sein (keine Fake-Defaults)
    func test_newTask_hasNilValues_noFakeDefaults() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Quick Capture")
        context.insert(task)

        // Diese Tests werden FEHLSCHLAGEN bis die Felder optional sind
        XCTAssertNil(task.importance, "importance sollte nil sein, nicht Default")
        XCTAssertNil(task.urgency, "urgency sollte nil sein, nicht Default")
        XCTAssertNil(task.estimatedDuration, "estimatedDuration sollte nil sein, nicht Default")
    }

    /// GIVEN: Ein Task mit nur Titel
    /// WHEN: importance explizit gesetzt wird
    /// THEN: importance hat den Wert, andere bleiben nil
    func test_task_importanceCanBeSet_othersRemainNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Partial Task")
        task.importance = 3  // Hoch
        context.insert(task)

        XCTAssertEqual(task.importance, 3)
        XCTAssertNil(task.urgency)
        XCTAssertNil(task.estimatedDuration)
    }

    /// GIVEN: Ein Task mit nur Titel
    /// WHEN: urgency explizit gesetzt wird
    /// THEN: urgency hat den Wert, andere bleiben nil
    func test_task_urgencyCanBeSet_othersRemainNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Urgent Task")
        task.urgency = "urgent"
        context.insert(task)

        XCTAssertNil(task.importance)
        XCTAssertEqual(task.urgency, "urgent")
        XCTAssertNil(task.estimatedDuration)
    }

    /// GIVEN: Ein Task mit nur Titel
    /// WHEN: estimatedDuration explizit gesetzt wird
    /// THEN: estimatedDuration hat den Wert, andere bleiben nil
    func test_task_estimatedDurationCanBeSet_othersRemainNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Timed Task")
        task.estimatedDuration = 45
        context.insert(task)

        XCTAssertNil(task.importance)
        XCTAssertNil(task.urgency)
        XCTAssertEqual(task.estimatedDuration, 45)
    }

    // MARK: - isTbd Computed Property

    /// GIVEN: Ein Task ohne jegliche Werte (nur Titel)
    /// WHEN: isTbd abgefragt wird
    /// THEN: true (alle drei Felder fehlen)
    func test_isTbd_trueWhenAllNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Empty Task")
        context.insert(task)

        XCTAssertTrue(task.isTbd, "Task ohne Werte sollte tbd sein")
    }

    /// GIVEN: Ein Task mit nur importance gesetzt
    /// WHEN: isTbd abgefragt wird
    /// THEN: true (urgency und duration fehlen)
    func test_isTbd_trueWhenOnlyImportanceSet() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Partial")
        task.importance = 2
        context.insert(task)

        XCTAssertTrue(task.isTbd, "Task mit nur importance sollte noch tbd sein")
    }

    /// GIVEN: Ein Task mit nur urgency gesetzt
    /// WHEN: isTbd abgefragt wird
    /// THEN: true (importance und duration fehlen)
    func test_isTbd_trueWhenOnlyUrgencySet() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Partial")
        task.urgency = "urgent"
        context.insert(task)

        XCTAssertTrue(task.isTbd, "Task mit nur urgency sollte noch tbd sein")
    }

    /// GIVEN: Ein Task mit nur estimatedDuration gesetzt
    /// WHEN: isTbd abgefragt wird
    /// THEN: true (importance und urgency fehlen)
    func test_isTbd_trueWhenOnlyDurationSet() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Partial")
        task.estimatedDuration = 30
        context.insert(task)

        XCTAssertTrue(task.isTbd, "Task mit nur duration sollte noch tbd sein")
    }

    /// GIVEN: Ein Task mit zwei von drei Feldern gesetzt
    /// WHEN: isTbd abgefragt wird
    /// THEN: true (ein Feld fehlt noch)
    func test_isTbd_trueWhenTwoOfThreeSet() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Almost Complete")
        task.importance = 3
        task.urgency = "urgent"
        // estimatedDuration fehlt
        context.insert(task)

        XCTAssertTrue(task.isTbd, "Task mit 2/3 Feldern sollte noch tbd sein")
    }

    /// GIVEN: Ein Task mit allen drei Feldern gesetzt
    /// WHEN: isTbd abgefragt wird
    /// THEN: false (vollständig)
    func test_isTbd_falseWhenAllSet() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Complete Task")
        task.importance = 2
        task.urgency = "not_urgent"
        task.estimatedDuration = 60
        context.insert(task)

        XCTAssertFalse(task.isTbd, "Task mit allen Feldern sollte NICHT tbd sein")
    }

    // MARK: - Automatisches TBD-Entfernen

    /// GIVEN: Ein tbd Task (alle nil)
    /// WHEN: Alle drei Felder nacheinander gesetzt werden
    /// THEN: isTbd wird automatisch false
    func test_isTbd_autoRemovesWhenComplete() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Evolving Task")
        context.insert(task)

        XCTAssertTrue(task.isTbd, "Anfangs tbd")

        task.importance = 1
        XCTAssertTrue(task.isTbd, "Nach importance noch tbd")

        task.urgency = "not_urgent"
        XCTAssertTrue(task.isTbd, "Nach urgency noch tbd")

        task.estimatedDuration = 15
        XCTAssertFalse(task.isTbd, "Nach duration NICHT mehr tbd")
    }

    // MARK: - Umbenennung priority → importance

    /// GIVEN: Das alte Feld "priority"
    /// WHEN: Code kompiliert
    /// THEN: "importance" sollte existieren (priority deprecated)
    func test_importanceFieldExists() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test")
        context.insert(task)

        // Dieser Test prüft, dass "importance" existiert
        // Er wird fehlschlagen bis das Feld umbenannt ist
        _ = task.importance  // Compiler-Fehler wenn nicht vorhanden
        XCTAssertTrue(true, "importance Feld existiert")
    }

    // MARK: - PlanItem Integration

    /// GIVEN: Ein LocalTask mit isTbd = true
    /// WHEN: PlanItem davon erstellt wird
    /// THEN: PlanItem.isTbd sollte auch true sein
    func test_planItem_inheritsTbdFromLocalTask() throws {
        let context = container.mainContext
        let localTask = LocalTask(title: "TBD Task")
        context.insert(localTask)

        let planItem = PlanItem(localTask: localTask)

        XCTAssertTrue(planItem.isTbd, "PlanItem sollte isTbd von LocalTask erben")
    }

    /// GIVEN: Ein vollständiger LocalTask (isTbd = false)
    /// WHEN: PlanItem davon erstellt wird
    /// THEN: PlanItem.isTbd sollte false sein
    func test_planItem_inheritsNonTbdFromLocalTask() throws {
        let context = container.mainContext
        let localTask = LocalTask(title: "Complete Task")
        localTask.importance = 2
        localTask.urgency = "urgent"
        localTask.estimatedDuration = 30
        context.insert(localTask)

        let planItem = PlanItem(localTask: localTask)

        XCTAssertFalse(planItem.isTbd, "Vollständiger Task sollte nicht tbd sein")
    }
}
