import XCTest
import SwiftData
@testable import FocusBlox

/// TDD RED: Beweist dass die "Deferred Sort" Mechanik in BacklogView fundamental kaputt ist.
///
/// BUG: Wenn Wichtigkeit oder Dringlichkeit geändert wird, springt der Task sofort
/// an eine andere Position — trotz 3-Sekunden-Verzögerung.
///
/// ROOT CAUSE: `updateImportance()` (BacklogView.swift:522) ersetzt den PlanItem sofort
/// mit neuem `priorityScore`. Die Priority-View sortiert bei jedem Render nach Score
/// (Zeile 872). `pendingResortIDs` hat KEINEN Einfluss auf die Sortierung.
///
/// Diese Tests beweisen:
/// 1. Änderung der Importance ändert sofort den priorityScore
/// 2. Neusortierung nach Score ändert sofort die Reihenfolge
/// 3. Ein Task kann sogar die SECTION wechseln (Tier-Sprung)
/// 4. Die Deferred-Sort-Mechanik hat keinen Effekt auf die berechnete Sortierung
@MainActor
final class DeferredSortBugTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helper

    /// Simuliert die Priority-View-Sortierung (BacklogView.swift:869-872):
    /// Tasks werden nach Tier gruppiert und innerhalb jedes Tiers nach priorityScore sortiert.
    private func priorityViewOrder(_ items: [PlanItem]) -> [String] {
        var result: [String] = []
        for tier in TaskPriorityScoringService.PriorityTier.allCases {
            let tierTasks = items
                .filter { $0.priorityTier == tier }
                .sorted { $0.priorityScore > $1.priorityScore }
            result.append(contentsOf: tierTasks.map(\.id))
        }
        return result
    }

    /// Simuliert was `updateImportance()` in BacklogView.swift:522 tut:
    /// Task-Importance ändern, neuen PlanItem erstellen, im Array ersetzen.
    private func simulateImportanceUpdate(
        task: LocalTask,
        newImportance: Int?,
        planItems: inout [PlanItem]
    ) {
        task.importance = newImportance
        task.modifiedAt = Date()
        // Zeile 522: planItems[index] = PlanItem(localTask: task)
        if let index = planItems.firstIndex(where: { $0.id == task.id }) {
            planItems[index] = PlanItem(localTask: task)
        }
    }

    /// Simuliert was `updateUrgency()` in BacklogView.swift:540 tut.
    private func simulateUrgencyUpdate(
        task: LocalTask,
        newUrgency: String?,
        planItems: inout [PlanItem]
    ) {
        task.urgency = newUrgency
        task.modifiedAt = Date()
        if let index = planItems.firstIndex(where: { $0.id == task.id }) {
            planItems[index] = PlanItem(localTask: task)
        }
    }

    // MARK: - Bug-Beweis 1: Importance-Änderung ändert sofort die Reihenfolge

    /// GIVEN: Drei Tasks in der gleichen Priority-Tier (planSoon), sortiert nach Score
    /// WHEN: Der letzte Task bekommt höhere Importance (simuliert Badge-Tap)
    /// THEN: Der Task sollte an der gleichen Position bleiben (Deferred Sort!)
    /// BUG: Der Task springt sofort nach vorne — Deferred Sort ist wirkungslos
    func test_importanceChange_taskShouldStayInPlace_butJumpsImmediately() throws {
        // 3 Tasks die alle im Tier "planSoon" (Score 35-59) landen
        // importance=3 + not_urgent → eisenhower=38
        let taskHigh = LocalTask(title: "High Task", importance: 3, urgency: "not_urgent")
        // importance=2 + urgent → eisenhower=35
        let taskMedUrg = LocalTask(title: "Medium Urgent Task", importance: 2, urgency: "urgent")
        // importance=2 + not_urgent → eisenhower=20 → Tier "eventually" (score ~20-25)
        let taskLow = LocalTask(title: "Low Task", importance: 2, urgency: "not_urgent")

        context.insert(taskHigh)
        context.insert(taskMedUrg)
        context.insert(taskLow)

        var planItems = [taskHigh, taskMedUrg, taskLow].map { PlanItem(localTask: $0) }

        // Record original position of taskLow in priority view
        let orderBefore = priorityViewOrder(planItems)
        let positionBefore = orderBefore.firstIndex(of: taskLow.id)!

        // ACT: User taps importance badge on taskLow → importance wird 3 (hoch)
        // Dies ist exakt was BacklogView.swift:512-524 tut
        simulateImportanceUpdate(task: taskLow, newImportance: 3, planItems: &planItems)

        // Die Priority-View berechnet bei jedem Render die Sortierung neu (Zeile 872)
        let orderAfter = priorityViewOrder(planItems)
        let positionAfter = orderAfter.firstIndex(of: taskLow.id)!

        // ASSERT: Task sollte an gleicher Position bleiben (das ist das gewünschte Verhalten)
        // ERWARTET: FAIL — weil der Task sofort springt (Bug bewiesen!)
        XCTAssertEqual(
            positionBefore, positionAfter,
            "BUG BEWIESEN: Task springt von Position \(positionBefore) nach \(positionAfter) " +
            "sofort bei Importance-Änderung. Deferred Sort verhindert dies NICHT."
        )
    }

    // MARK: - Bug-Beweis 2: Urgency-Änderung verursacht Tier-Sprung

    /// GIVEN: Ein Task im Tier "eventually" (niedrige Priorität)
    /// WHEN: Urgency wird auf "urgent" gesetzt
    /// THEN: Der Task sollte im gleichen Tier bleiben (Deferred Sort!)
    /// BUG: Der Task springt in ein höheres Tier — sofort sichtbar als Section-Wechsel
    func test_urgencyChange_taskShouldStayInSameTier_butJumpsToHigherTier() throws {
        // Task mit importance=2, urgency=nil → eisenhower=15, total ~15-20 → Tier "eventually"
        let task = LocalTask(title: "Test Task", importance: 2)
        context.insert(task)

        var planItems = [PlanItem(localTask: task)]

        let tierBefore = planItems[0].priorityTier
        XCTAssertEqual(tierBefore, .eventually, "Precondition: Task sollte in 'eventually' starten")

        // ACT: User setzt Urgency auf "urgent"
        // importance=2 + urgent → eisenhower=35, total ~35-40 → Tier "planSoon"
        simulateUrgencyUpdate(task: task, newUrgency: "urgent", planItems: &planItems)

        let tierAfter = planItems[0].priorityTier

        // ASSERT: Tier sollte gleich bleiben (Deferred Sort soll Sprung verhindern)
        // ERWARTET: FAIL — Tier wechselt sofort von "eventually" zu "planSoon"
        XCTAssertEqual(
            tierBefore, tierAfter,
            "BUG BEWIESEN: Task springt von Tier '\(tierBefore)' nach '\(tierAfter)' " +
            "— das ist ein sofortiger Section-Wechsel in der UI."
        )
    }

    // MARK: - Bug-Beweis 3: Kategorie-Änderung springt NICHT (Kontrolltest)

    /// GIVEN: Ein Task in der BacklogView
    /// WHEN: Nur die Kategorie geändert wird (ohne PlanItem-Replace, wie Zeile 548-553)
    /// THEN: Der priorityScore ändert sich minimal (0-1 Punkt), kein Sprung
    /// Dieser Test zeigt den UNTERSCHIED: updateCategory() hat keinen sofortigen PlanItem-Replace
    func test_categoryChange_doesNotCauseImmediateScoreJump() throws {
        let task = LocalTask(title: "Test Task", importance: 2, urgency: "not_urgent")
        context.insert(task)

        let planItem = PlanItem(localTask: task)
        let scoreBefore = planItem.priorityScore

        // Kategorie-Änderung: taskType "" → "work"
        // updateCategory() nutzt SyncEngine.updateTask() und macht KEINEN PlanItem-Replace
        // Hier simulieren wir nur den Score-Effekt:
        task.taskType = "work"
        let planItemAfter = PlanItem(localTask: task)
        let scoreAfter = planItemAfter.priorityScore

        // Completeness-Score ändert sich um max 1-2 Punkte
        let scoreDiff = abs(scoreAfter - scoreBefore)
        XCTAssertLessThanOrEqual(
            scoreDiff, 2,
            "Kategorie-Änderung ändert Score nur minimal (\(scoreDiff) Punkte) — kein Tier-Sprung"
        )
    }

    // MARK: - Bug-Beweis 4: pendingResortIDs hat KEINEN Einfluss auf Sortierung

    /// GIVEN: Zwei Tasks, einer ist "pending resort" (in pendingResortIDs)
    /// WHEN: Priority-View-Sortierung berechnet wird
    /// THEN: Die Sortierung ignoriert pendingResortIDs komplett
    /// Das beweist: Die Deferred-Sort-Mechanik schützt NUR den visuellen Rand, nicht die Position
    func test_pendingResortIDs_hasNoEffectOnSortOrder() throws {
        // Task A: importance=1 → niedrig
        let taskA = LocalTask(title: "Task A", importance: 1, urgency: "not_urgent")
        // Task B: importance=3 → hoch
        let taskB = LocalTask(title: "Task B", importance: 3, urgency: "not_urgent")
        context.insert(taskA)
        context.insert(taskB)

        var planItems = [taskA, taskB].map { PlanItem(localTask: $0) }

        // Sortierung VOR Update
        let orderBefore = priorityViewOrder(planItems)

        // Simuliere: taskA bekommt importance=3 (Badge-Tap)
        // In echtem Code: pendingResortIDs.insert(taskA.id) würde hier passieren
        let pendingResortIDs: Set<String> = [taskA.id]  // Task A ist "pending"
        _ = pendingResortIDs  // Variable existiert — hat aber keinen Einfluss

        simulateImportanceUpdate(task: taskA, newImportance: 3, planItems: &planItems)

        // Sortierung NACH Update — pendingResortIDs wird nicht geprüft
        let orderAfter = priorityViewOrder(planItems)

        // ASSERT: Reihenfolge sollte gleich bleiben wenn Deferred Sort funktionieren würde
        // ERWARTET: FAIL — pendingResortIDs hat keinen Einfluss auf die Sortierung
        XCTAssertEqual(
            orderBefore, orderAfter,
            "BUG BEWIESEN: pendingResortIDs hat keinen Einfluss auf priorityViewOrder(). " +
            "Task A springt trotzdem von Position \(orderBefore.firstIndex(of: taskA.id)!) " +
            "nach \(orderAfter.firstIndex(of: taskA.id)!)."
        )
    }
}
