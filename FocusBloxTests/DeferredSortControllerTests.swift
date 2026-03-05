import XCTest
@testable import FocusBlox

/// TDD RED: Tests fuer den shared DeferredSortController.
///
/// Der Controller kapselt die Deferred-Sort-Logik (freeze/unfreeze/timer/score-lookup)
/// die bisher auf iOS (BacklogView) und macOS (ContentView) dupliziert war.
///
/// Diese Tests muessen FEHLSCHLAGEN weil DeferredSortController noch nicht existiert.
@MainActor
final class DeferredSortControllerTests: XCTestCase {

    // MARK: - Test 1: freeze() speichert Scores und effectiveScore() gibt sie zurueck

    /// GIVEN: Ein frischer Controller ohne Freeze
    /// WHEN: freeze(scores:) mit einem Snapshot aufgerufen wird
    /// THEN: effectiveScore() gibt den gefrorenen Score zurueck statt den Live-Score
    ///
    /// Welche Zeile bricht diesen Test? DeferredSortController.freeze() und effectiveScore()
    /// existieren nicht — Compiler-Fehler.
    func test_freeze_capturesScores_effectiveScore_returnsFrozen() {
        let controller = DeferredSortController()

        // Kein Freeze: Live-Score wird zurueckgegeben
        XCTAssertEqual(controller.effectiveScore(id: "task-1", liveScore: 50), 50)

        // Freeze mit Score 80 fuer task-1
        controller.freeze(scores: ["task-1": 80, "task-2": 60])

        // Frozen Score wird zurueckgegeben, nicht Live-Score
        XCTAssertEqual(controller.effectiveScore(id: "task-1", liveScore: 50), 80)
        XCTAssertEqual(controller.effectiveScore(id: "task-2", liveScore: 30), 60)

        // Unbekannte ID: Live-Score als Fallback
        XCTAssertEqual(controller.effectiveScore(id: "task-3", liveScore: 42), 42)
    }

    // MARK: - Test 2: freeze() Guard — zweiter freeze ueberschreibt nicht

    /// GIVEN: Controller mit aktivem Freeze
    /// WHEN: freeze() erneut aufgerufen wird (z.B. schnelles Doppel-Tappen)
    /// THEN: Der urspruengliche Snapshot bleibt erhalten
    ///
    /// Welche Zeile bricht diesen Test? guard frozenScores == nil else { return }
    func test_freeze_guard_doesNotOverwriteExistingSnapshot() {
        let controller = DeferredSortController()

        // Erster Freeze
        controller.freeze(scores: ["task-1": 80])
        XCTAssertEqual(controller.effectiveScore(id: "task-1", liveScore: 50), 80)

        // Zweiter Freeze mit anderen Werten — sollte ignoriert werden
        controller.freeze(scores: ["task-1": 99])
        XCTAssertEqual(controller.effectiveScore(id: "task-1", liveScore: 50), 80,
                        "Zweiter freeze() darf den Snapshot nicht ueberschreiben")
    }

    // MARK: - Test 3: isPending() nach scheduleDeferredResort()

    /// GIVEN: Ein frischer Controller
    /// WHEN: scheduleDeferredResort() aufgerufen wird
    /// THEN: isPending() gibt true fuer die ID zurueck
    ///
    /// Welche Zeile bricht diesen Test? scheduleDeferredResort() und isPending()
    func test_scheduleDeferredResort_setsPendingID() {
        let controller = DeferredSortController()

        XCTAssertFalse(controller.isPending("task-1"))

        controller.scheduleDeferredResort(id: "task-1")

        XCTAssertTrue(controller.isPending("task-1"),
                       "Task sollte nach scheduleDeferredResort als pending markiert sein")
    }

    // MARK: - Test 4: Timer cleared nach 3+ Sekunden

    /// GIVEN: Controller mit Freeze und Pending
    /// WHEN: 4 Sekunden vergehen (3s Timer + Puffer)
    /// THEN: frozenScores ist nil und pendingIDs ist leer
    ///
    /// Welche Zeile bricht diesen Test? Der Timer in scheduleDeferredResort()
    func test_timerClearsStateAfterTimeout() async throws {
        let controller = DeferredSortController()
        controller.freeze(scores: ["task-1": 80])
        controller.scheduleDeferredResort(id: "task-1")

        // Vor Timeout: Frozen
        XCTAssertEqual(controller.effectiveScore(id: "task-1", liveScore: 50), 80)
        XCTAssertTrue(controller.isPending("task-1"))

        // Warten bis Timer abgelaufen ist (3s + 0.2s Pause + 0.4s Animation + Puffer)
        try await Task.sleep(for: .seconds(4.5))

        // Nach Timeout: Unfrozen
        XCTAssertEqual(controller.effectiveScore(id: "task-1", liveScore: 50), 50,
                        "Nach Timer-Ablauf sollte der Live-Score zurueckgegeben werden")
        XCTAssertFalse(controller.isPending("task-1"),
                        "Nach Timer-Ablauf sollte die ID nicht mehr pending sein")
    }

    // MARK: - Test 5: Timer Reset bei erneutem scheduleDeferredResort

    /// GIVEN: Controller mit laufendem Timer
    /// WHEN: scheduleDeferredResort erneut aufgerufen wird (z.B. zweites Badge-Tap)
    /// THEN: Timer startet neu — alter Timer wird cancelled
    ///
    /// Welche Zeile bricht diesen Test? resortTimer?.cancel() in scheduleDeferredResort
    func test_timerResets_onSubsequentSchedule() async throws {
        let controller = DeferredSortController()
        controller.freeze(scores: ["task-1": 80])
        controller.scheduleDeferredResort(id: "task-1")

        // Nach 2 Sekunden: Neuer Badge-Tap, Timer Reset
        try await Task.sleep(for: .seconds(2))
        controller.scheduleDeferredResort(id: "task-2")

        // Nach weiteren 2 Sekunden (4s total, aber nur 2s seit Reset):
        // Timer laeuft noch weil er auf 3s ab dem letzten Tap zurueckgesetzt wurde
        try await Task.sleep(for: .seconds(2))

        XCTAssertNotNil(controller.frozenScores,
                         "Frozen Scores sollten noch aktiv sein weil der Timer bei 2s zurueckgesetzt wurde")

        // Nach noch 2 Sekunden (6s total, 4s seit Reset): Timer abgelaufen
        try await Task.sleep(for: .seconds(2.5))

        XCTAssertNil(controller.frozenScores,
                      "Frozen Scores sollten nach Timer-Ablauf nil sein")
    }

    // MARK: - Test 6: onUnfreeze Callback wird aufgerufen

    /// GIVEN: Controller mit Freeze und onUnfreeze-Callback
    /// WHEN: Timer ablaeuft
    /// THEN: Der Callback wird aufgerufen (z.B. refreshLocalTasks auf iOS)
    ///
    /// Welche Zeile bricht diesen Test? await onUnfreeze?() in scheduleDeferredResort
    func test_onUnfreezeCallback_calledAfterTimeout() async throws {
        let controller = DeferredSortController()
        controller.freeze(scores: ["task-1": 80])

        let expectation = XCTestExpectation(description: "onUnfreeze callback called")
        controller.scheduleDeferredResort(id: "task-1") {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Test 7: Mehrere Pending IDs gleichzeitig

    /// GIVEN: Controller
    /// WHEN: Mehrere Tasks als pending markiert werden
    /// THEN: Alle sind isPending == true
    func test_multiplePendingIDs() {
        let controller = DeferredSortController()
        controller.freeze(scores: ["task-1": 80, "task-2": 60, "task-3": 40])

        controller.scheduleDeferredResort(id: "task-1")
        controller.scheduleDeferredResort(id: "task-2")

        // Beide pending (auch wenn Timer resettet wurde, IDs bleiben im Set)
        XCTAssertTrue(controller.isPending("task-1"))
        XCTAssertTrue(controller.isPending("task-2"))
        XCTAssertFalse(controller.isPending("task-3"))
    }
}
