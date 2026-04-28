import XCTest
@testable import FocusBlox

final class RecurringStackingTests: XCTestCase {

    // MARK: - Stacking Boost (TaskPriorityScoringService)

    /// Verhalten: Ein einzelner Task (stackedCount=1) bekommt keinen Boost.
    /// Bricht wenn: TaskPriorityScoringService.stackingBoost() bei count=1 nicht 0 zurueckgibt.
    func test_stackingBoost_singleInstance_returnsZero() {
        let boost = TaskPriorityScoringService.stackingBoost(instanceCount: 1)
        XCTAssertEqual(boost, 0, "Single instance should get no boost")
    }

    /// Verhalten: Zwei aufgelaufene Instanzen geben +5 Boost.
    /// Bricht wenn: stackingBoost() bei count=2 nicht 5 zurueckgibt.
    func test_stackingBoost_twoInstances_returnsFive() {
        let boost = TaskPriorityScoringService.stackingBoost(instanceCount: 2)
        XCTAssertEqual(boost, 5, "Two instances should give +5 boost")
    }

    /// Verhalten: Drei aufgelaufene Instanzen geben +10 Boost.
    /// Bricht wenn: stackingBoost() bei count=3 nicht 10 zurueckgibt.
    func test_stackingBoost_threeInstances_returnsTen() {
        let boost = TaskPriorityScoringService.stackingBoost(instanceCount: 3)
        XCTAssertEqual(boost, 10, "Three instances should give +10 boost")
    }

    /// Verhalten: Vier oder mehr aufgelaufene Instanzen werden bei +15 gecapped.
    /// Bricht wenn: stackingBoost() bei count>=4 nicht 15 zurueckgibt.
    func test_stackingBoost_fourOrMore_cappedAtFifteen() {
        XCTAssertEqual(TaskPriorityScoringService.stackingBoost(instanceCount: 4), 15)
        XCTAssertEqual(TaskPriorityScoringService.stackingBoost(instanceCount: 7), 15)
    }

    /// Verhalten: calculateScore() mit stackedInstanceCount>1 ergibt hoeheren Score.
    /// Bricht wenn: calculateScore() den stackedInstanceCount-Parameter nicht beruecksichtigt.
    func test_calculateScore_withStackingCount_includesBoost() {
        let now = Date()
        let baseScore = TaskPriorityScoringService.calculateScore(
            importance: 2,
            urgency: "not_urgent",
            dueDate: nil,
            createdAt: now,
            rescheduleCount: 0,
            estimatedDuration: 30,
            taskType: "task",
            isNextUp: false,
            now: now,
            dependentTaskCount: 0,
            stackedInstanceCount: 1
        )
        let boostedScore = TaskPriorityScoringService.calculateScore(
            importance: 2,
            urgency: "not_urgent",
            dueDate: nil,
            createdAt: now,
            rescheduleCount: 0,
            estimatedDuration: 30,
            taskType: "task",
            isNextUp: false,
            now: now,
            dependentTaskCount: 0,
            stackedInstanceCount: 3
        )
        XCTAssertEqual(boostedScore - baseScore, 10, "3 stacked instances should add +10 to score")
    }

    /// Verhalten: calculateScore() mit Stacking wird bei 100 gecapped.
    /// Bricht wenn: calculateScore() keinen min(100,...) Cap hat.
    func test_calculateScore_withStacking_cappedAt100() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let score = TaskPriorityScoringService.calculateScore(
            importance: 3,
            urgency: "urgent",
            dueDate: yesterday,
            createdAt: Calendar.current.date(byAdding: .day, value: -60, to: now)!,
            rescheduleCount: 5,
            estimatedDuration: 30,
            taskType: "task",
            isNextUp: true,
            now: now,
            dependentTaskCount: 3,
            stackedInstanceCount: 4
        )
        XCTAssertEqual(score, 100, "Score should be capped at 100 even with stacking boost")
    }

    // MARK: - PlanItem stackedInstanceCount

    /// Verhalten: PlanItem hat stackedInstanceCount Property mit Default 1.
    /// Bricht wenn: PlanItem kein stackedInstanceCount Property hat oder Default != 1.
    func test_planItem_hasStackedInstanceCount_defaultOne() {
        let item = makePlanItem(id: "a", groupID: "g1")
        XCTAssertEqual(item.stackedInstanceCount, 1, "Default stackedInstanceCount should be 1")
    }

    /// Verhalten: PlanItem.priorityScore beruecksichtigt stackedInstanceCount.
    /// Bricht wenn: PlanItem.priorityScore den stackedInstanceCount nicht an calculateScore weitergibt.
    func test_planItem_priorityScore_reflectsStackedCount() {
        var item1 = makePlanItem(id: "a", groupID: "g1")
        item1.stackedInstanceCount = 1

        var item3 = makePlanItem(id: "b", groupID: "g1")
        item3.stackedInstanceCount = 3

        XCTAssertGreaterThan(
            item3.priorityScore,
            item1.priorityScore,
            "Item with 3 stacked instances should have higher score than single instance"
        )
    }

    // MARK: - Bug 279: stackedOldestDueDate (Field-Existenz)

    /// **STRUKTUR-TEST (kein Behavior-Test):** Prueft nur dass PlanItem das Feld besitzt.
    /// **WARNUNG:** Dieser Test sagt NICHTS darueber aus ob applyRecurringStacking()
    /// das Feld korrekt setzt. Behavior wird in BacklogStackingUITests.test_seriesWithThreeInstances_showsBadgeX3
    /// und test_stackedTaskShowsSubtitle geprueft.
    /// Bricht wenn: PlanItem kein stackedOldestDueDate Property hat.
    func test_planItem_hasStackedOldestDueDate_FIELD_ONLY() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        var item = makePlanItem(id: "oldest-279", groupID: "grp-279", dueDate: twoDaysAgo)

        // Beweis dass das Feld settable ist (nicht nur Mirror-Reflection auf Optional-Default-nil)
        item.stackedOldestDueDate = twoDaysAgo
        XCTAssertEqual(item.stackedOldestDueDate, twoDaysAgo,
                       "PlanItem.stackedOldestDueDate muss settable sein und den Wert behalten")
    }

    // MARK: - Bug 279: stackedInstanceCount Setter (Field-Behavior)

    /// **STRUKTUR-TEST:** Prueft dass stackedInstanceCount settable ist und priorityScore nutzt.
    /// **WARNUNG:** Sagt NICHTS darueber aus ob applyRecurringStacking() den Counter setzt.
    /// Behavior in BacklogStackingUITests.test_seriesWithTwoInstances_showsBadgeX2.
    func test_planItem_stackedInstanceCount_isSettableAndScored() {
        var item = makePlanItem(id: "set-test", groupID: "grp-set")
        XCTAssertEqual(item.stackedInstanceCount, 1, "Default = 1")

        let scoreBefore = item.priorityScore
        item.stackedInstanceCount = 3
        let scoreAfter = item.priorityScore

        XCTAssertEqual(item.stackedInstanceCount, 3, "Setter muss greifen")
        XCTAssertGreaterThan(scoreAfter, scoreBefore,
                             "priorityScore muss stackedInstanceCount beruecksichtigen")
    }

    // MARK: - REMOVED: test_stackingExcludesNextUpTasks
    //
    // Der frueher hier stehende Test hat die Stacking-Logik IM TEST SELBST nachgebaut
    // (`for item in allItems { if let gid = ... }`) statt den echten Code aufzurufen.
    // Das ist ein Silent-Pass-Pattern: Der Test war GREEN obwohl der Bug 279 da war,
    // weil er nie applyRecurringStacking() in BacklogView.swift aufrief.
    //
    // applyRecurringStacking() ist `private` — kann aus Unit-Tests nicht aufgerufen werden.
    // Der echte Behavior-Test fuer isNextUp-Ausschluss muss als UI-Test laufen.
    // Siehe: BacklogStackingUITests.test_stackedSeries_rendersAsSingleRow

    // MARK: - Helpers

    private func makePlanItem(
        id: String? = nil,
        groupID: String?,
        dueDate: Date? = nil,
        isNextUp: Bool = false
    ) -> PlanItem {
        let task = LocalTask(
            title: "Test Task",
            importance: 2,
            dueDate: dueDate,
            estimatedDuration: 15,
            urgency: "not_urgent",
            taskType: "task",
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        task.isNextUp = isNextUp
        return PlanItem(localTask: task)
    }
}
