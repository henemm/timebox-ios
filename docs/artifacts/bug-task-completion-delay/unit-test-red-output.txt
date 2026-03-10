import XCTest
@testable import FocusBlox

/// TDD RED: Tests fuer DeferredCompletionController.
///
/// Der Controller verzögert das tatsächliche Speichern einer Task-Completion um ~3 Sekunden.
/// Während der Wartezeit zeigt die UI den gefüllten Checkpoint, der Task bleibt aber
/// sichtbar in der Liste. Nach Ablauf des Timers wird onCommit aufgerufen und der Task
/// verschwindet.
///
/// Pattern folgt DeferredSortController (freeze/unfreeze), aber mit per-Task-Timern
/// statt einem einzelnen globalen Timer.
///
/// Diese Tests muessen FEHLSCHLAGEN weil DeferredCompletionController noch nicht existiert.
@MainActor
final class DeferredCompletionControllerTests: XCTestCase {

    // MARK: - Test 1: scheduleCompletion setzt pending ID

    /// GIVEN: Ein frischer Controller
    /// WHEN: scheduleCompletion() aufgerufen wird
    /// THEN: isPending() gibt true zurück für die ID
    ///
    /// Welche Zeile bricht diesen Test? DeferredCompletionController existiert nicht.
    func test_scheduleCompletion_setsPendingID() {
        let controller = DeferredCompletionController()

        XCTAssertFalse(controller.isPending("task-1"))

        controller.scheduleCompletion(id: "task-1") { }

        XCTAssertTrue(controller.isPending("task-1"),
                       "Task sollte nach scheduleCompletion als pending markiert sein")
    }

    // MARK: - Test 2: Mehrere Tasks unabhängig pending

    /// GIVEN: Controller
    /// WHEN: Mehrere Tasks als pending markiert werden
    /// THEN: Jeder hat seinen eigenen Timer, alle sind isPending == true
    ///
    /// Welche Zeile bricht diesen Test? Per-Task-Timer-Dictionary existiert nicht.
    func test_multipleTasksIndependentlyPending() {
        let controller = DeferredCompletionController()

        controller.scheduleCompletion(id: "task-1") { }
        controller.scheduleCompletion(id: "task-2") { }
        controller.scheduleCompletion(id: "task-3") { }

        XCTAssertTrue(controller.isPending("task-1"))
        XCTAssertTrue(controller.isPending("task-2"))
        XCTAssertTrue(controller.isPending("task-3"))
        XCTAssertFalse(controller.isPending("task-4"))
    }

    // MARK: - Test 3: onCommit wird nach Timer aufgerufen

    /// GIVEN: Controller mit scheduled completion
    /// WHEN: 3+ Sekunden vergehen
    /// THEN: onCommit-Callback wird aufgerufen und ID ist nicht mehr pending
    ///
    /// Welche Zeile bricht diesen Test? Timer + onCommit-Aufruf in scheduleCompletion.
    func test_onCommit_calledAfterTimer() async throws {
        let controller = DeferredCompletionController()

        let expectation = XCTestExpectation(description: "onCommit called")
        controller.scheduleCompletion(id: "task-1") {
            expectation.fulfill()
        }

        XCTAssertTrue(controller.isPending("task-1"))

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertFalse(controller.isPending("task-1"),
                        "Nach Timer-Ablauf sollte die ID nicht mehr pending sein")
    }

    // MARK: - Test 4: cancelCompletion entfernt pending + stoppt Timer

    /// GIVEN: Controller mit pending task
    /// WHEN: cancelCompletion() aufgerufen wird
    /// THEN: ID ist nicht mehr pending, onCommit wird NIE aufgerufen
    ///
    /// Welche Zeile bricht diesen Test? cancelCompletion() existiert nicht.
    func test_cancelCompletion_removesPendingAndStopsTimer() async throws {
        let controller = DeferredCompletionController()

        var commitCalled = false
        controller.scheduleCompletion(id: "task-1") {
            commitCalled = true
        }

        XCTAssertTrue(controller.isPending("task-1"))

        // Cancel vor Timer-Ablauf
        controller.cancelCompletion(id: "task-1")

        XCTAssertFalse(controller.isPending("task-1"),
                        "Nach cancel sollte die ID nicht mehr pending sein")

        // Warten über Timer-Zeitfenster hinaus
        try await Task.sleep(for: .seconds(4))

        XCTAssertFalse(commitCalled,
                        "onCommit darf nach cancel nicht aufgerufen werden")
    }

    // MARK: - Test 5: flushAll committet alle pending sofort

    /// GIVEN: Controller mit mehreren pending tasks
    /// WHEN: flushAll() aufgerufen wird (z.B. App geht in Background)
    /// THEN: Alle onCommit-Callbacks werden sofort aufgerufen, pendingIDs leer
    ///
    /// Welche Zeile bricht diesen Test? flushAll() existiert nicht.
    func test_flushAll_commitsAllPendingImmediately() async throws {
        let controller = DeferredCompletionController()

        var committed: Set<String> = []
        controller.scheduleCompletion(id: "task-1") {
            committed.insert("task-1")
        }
        controller.scheduleCompletion(id: "task-2") {
            committed.insert("task-2")
        }

        XCTAssertTrue(controller.isPending("task-1"))
        XCTAssertTrue(controller.isPending("task-2"))

        // Flush sofort (App Background)
        await controller.flushAll()

        XCTAssertEqual(committed, ["task-1", "task-2"],
                        "Alle pending tasks sollten committed worden sein")
        XCTAssertFalse(controller.isPending("task-1"))
        XCTAssertFalse(controller.isPending("task-2"))
    }

    // MARK: - Test 6: Per-Task Timer — ein Task läuft ab, anderer bleibt pending

    /// GIVEN: Task-1 scheduled bei T=0, Task-2 scheduled bei T=2
    /// WHEN: T=4 erreicht wird (Task-1 Timer abgelaufen, Task-2 noch 1s übrig)
    /// THEN: Task-1 committed, Task-2 noch pending
    ///
    /// Welche Zeile bricht diesen Test? Per-Task-Timer statt globaler Timer.
    func test_perTaskTimers_independentExpiry() async throws {
        let controller = DeferredCompletionController()

        var task1Committed = false
        controller.scheduleCompletion(id: "task-1") {
            task1Committed = true
        }

        // 2 Sekunden warten, dann Task-2 schedulen
        try await Task.sleep(for: .seconds(2))

        var task2Committed = false
        controller.scheduleCompletion(id: "task-2") {
            task2Committed = true
        }

        // Nach weiteren 1.5 Sekunden: Task-1 sollte committed sein (3.5s total)
        // Task-2 erst 1.5s alt — noch pending
        try await Task.sleep(for: .seconds(1.5))

        XCTAssertTrue(task1Committed,
                       "Task-1 sollte nach 3.5s committed sein")
        XCTAssertFalse(controller.isPending("task-1"))

        XCTAssertFalse(task2Committed,
                        "Task-2 sollte nach 1.5s noch NICHT committed sein")
        XCTAssertTrue(controller.isPending("task-2"))

        // Warten bis Task-2 auch abläuft
        try await Task.sleep(for: .seconds(2))

        XCTAssertTrue(task2Committed,
                       "Task-2 sollte jetzt auch committed sein")
        XCTAssertFalse(controller.isPending("task-2"))
    }

    // MARK: - Test 7: Doppeltes scheduleCompletion für gleiche ID resettet Timer

    /// GIVEN: Task-1 already pending
    /// WHEN: scheduleCompletion() erneut für task-1 aufgerufen wird
    /// THEN: Timer startet neu, nur der neue onCommit wird aufgerufen
    ///
    /// Welche Zeile bricht diesen Test? Timer-Cancel + Neustart bei gleicher ID.
    func test_doubleSchedule_resetsTimer() async throws {
        let controller = DeferredCompletionController()

        var firstCommitCalled = false
        controller.scheduleCompletion(id: "task-1") {
            firstCommitCalled = true
        }

        // Nach 2 Sekunden erneut schedulen
        try await Task.sleep(for: .seconds(2))

        var secondCommitCalled = false
        controller.scheduleCompletion(id: "task-1") {
            secondCommitCalled = true
        }

        // Nach weiteren 2 Sekunden (4s total, 2s seit Reset):
        // Timer läuft noch, da er auf 3s resettet wurde
        try await Task.sleep(for: .seconds(2))

        XCTAssertTrue(controller.isPending("task-1"),
                       "Task-1 sollte noch pending sein (Timer wurde bei 2s resettet)")
        XCTAssertFalse(firstCommitCalled,
                        "Erster onCommit darf nicht aufgerufen werden (Timer wurde cancelled)")

        // Nach noch 1.5 Sekunden (5.5s total, 3.5s seit Reset): Timer abgelaufen
        try await Task.sleep(for: .seconds(1.5))

        XCTAssertTrue(secondCommitCalled,
                       "Zweiter onCommit sollte nach Reset-Timer aufgerufen werden")
        XCTAssertFalse(controller.isPending("task-1"))
    }
}
