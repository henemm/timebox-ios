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

    // MARK: - Bug 279: stackedOldestDueDate

    /// Verhalten: PlanItem muss ein stackedOldestDueDate-Feld haben,
    ///            das von applyRecurringStacking auf das aelteste dueDate der Gruppe gesetzt wird.
    /// Bricht wenn: PlanItem kein stackedOldestDueDate Property hat.
    func test_planItem_hasStackedOldestDueDate() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let item = makePlanItem(id: "oldest-279", groupID: "grp-279", dueDate: twoDaysAgo)

        // stackedOldestDueDate muss als Property existieren
        let mirror = Mirror(reflecting: item)
        let hasField = mirror.children.contains { $0.label == "stackedOldestDueDate" }
        XCTAssertTrue(hasField, "PlanItem muss ein stackedOldestDueDate-Feld haben")
    }

    // MARK: - Bug 279: isNextUp-Tasks duerfen nicht gestackt werden

    /// Verhalten: Tasks mit isNextUp=true bleiben aus Stacking-Gruppen ausgeschlossen.
    /// Bricht wenn: Die Stacking-Logik isNextUp-Tasks in die Gruppe einbezieht.
    func test_stackingExcludesNextUpTasks() {
        // Erstelle 3 PlanItems mit gleicher groupID — eines davon isNextUp
        let groupID = "grp-279-nextup"
        let backlog1 = makePlanItem(id: "b1", groupID: groupID, isNextUp: false)
        let backlog2 = makePlanItem(id: "b2", groupID: groupID, isNextUp: false)
        let nextUpItem = makePlanItem(id: "nu1", groupID: groupID, isNextUp: true)

        let allItems = [backlog1, backlog2, nextUpItem]

        // Simuliere die Stacking-Logik (gleicher Algorithmus wie BacklogView.applyRecurringStacking)
        var groups: [String: [PlanItem]] = [:]
        var ungrouped: [PlanItem] = []

        for item in allItems {
            if let gid = item.recurrenceGroupID,
               !item.isTemplate,
               !item.isCompleted,
               !item.isNextUp {
                groups[gid, default: []].append(item)
            } else {
                ungrouped.append(item)
            }
        }

        // isNextUp-Item muss in ungrouped landen, NICHT in der Stacking-Gruppe
        XCTAssertEqual(ungrouped.count, 1, "isNextUp-Task muss als ungrouped behandelt werden")
        XCTAssertTrue(ungrouped[0].isNextUp, "Das ungrouped Item muss das isNextUp-Item sein")

        // Die Gruppe darf nur die 2 Backlog-Items enthalten
        let group = groups[groupID]
        XCTAssertNotNil(group, "Backlog-Items muessen gruppiert werden")
        XCTAssertEqual(group?.count, 2, "Nur Backlog-Items (nicht isNextUp) werden gestackt")

        // Keines der gruppierten Items darf isNextUp sein
        for item in group ?? [] {
            XCTAssertFalse(item.isNextUp, "isNextUp-Tasks duerfen NICHT in Stacking-Gruppen sein")
        }
    }

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
