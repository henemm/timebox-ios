import XCTest
@testable import FocusBlox

final class IntentionEvaluationServiceTests: XCTestCase {

    // MARK: - Test Helpers

    /// Create a LocalTask with minimal fields for testing.
    /// Uses SwiftData @Model init — we only set the fields we care about.
    private func makeTask(
        title: String = "Test",
        importance: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        taskType: String = "",
        assignedFocusBlockID: String? = nil
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: importance)
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.taskType = taskType
        task.assignedFocusBlockID = assignedFocusBlockID
        return task
    }

    private func makeBlock(
        id: String = "block-1",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(3600),
        taskIDs: [String] = [],
        completedTaskIDs: [String] = []
    ) -> FocusBlock {
        FocusBlock(
            id: id, title: "Focus",
            startDate: startDate, endDate: endDate,
            taskIDs: taskIDs, completedTaskIDs: completedTaskIDs
        )
    }

    private var today: Date { Date() }

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    // MARK: - isFulfilled: Survival

    /// Verhalten: Survival ist IMMER erfuellt — keine Pruefung noetig.
    /// Bricht wenn: IntentionEvaluationService.isFulfilled() den .survival Case nicht als true behandelt.
    func test_isFulfilled_survival_alwaysTrue() {
        let result = IntentionEvaluationService.isFulfilled(
            intention: .survival, tasks: [], focusBlocks: []
        )
        XCTAssertTrue(result, "Survival should always be fulfilled")
    }

    // MARK: - isFulfilled: BHAG

    /// Verhalten: BHAG ist erfuellt wenn ein Task mit importance=3 HEUTE erledigt wurde.
    /// Bricht wenn: Die importance==3 Pruefung oder completedAt-Tages-Filter fehlt.
    func test_isFulfilled_bhag_whenImportance3TaskCompletedToday_returnsTrue() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.isFulfilled(
            intention: .bhag, tasks: [task], focusBlocks: []
        )
        XCTAssertTrue(result, "BHAG should be fulfilled when importance-3 task completed today")
    }

    /// Verhalten: Gestern erledigte Tasks zaehlen NICHT fuer heute.
    /// Bricht wenn: completedToday-Filter den Tag nicht korrekt vergleicht.
    func test_isFulfilled_bhag_whenImportance3TaskCompletedYesterday_returnsFalse() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: yesterday)
        let result = IntentionEvaluationService.isFulfilled(
            intention: .bhag, tasks: [task], focusBlocks: []
        )
        XCTAssertFalse(result, "Yesterday's completion should not count for today's BHAG")
    }

    /// Verhalten: Tasks mit importance < 3 erfuellen BHAG NICHT.
    /// Bricht wenn: Die importance==3 Pruefung auf >= 3 oder aehnlich geaendert wird.
    func test_isFulfilled_bhag_whenNoImportance3Task_returnsFalse() {
        let task = makeTask(importance: 2, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.isFulfilled(
            intention: .bhag, tasks: [task], focusBlocks: []
        )
        XCTAssertFalse(result, "Only importance=3 counts for BHAG")
    }

    // MARK: - isFulfilled: Fokus

    /// Verhalten: Fokus ist erfuellt wenn mindestens ein Focus Block HEUTE existiert.
    /// Bricht wenn: focusBlocksToday-Filter oder die Existenz-Pruefung fehlt.
    func test_isFulfilled_fokus_whenFocusBlockExistsToday_returnsTrue() {
        let block = makeBlock(taskIDs: ["task-1"])
        let result = IntentionEvaluationService.isFulfilled(
            intention: .fokus, tasks: [], focusBlocks: [block]
        )
        XCTAssertTrue(result, "Fokus should be fulfilled when a focus block exists today")
    }

    /// Verhalten: Ohne Focus Blocks ist Fokus NICHT erfuellt.
    /// Bricht wenn: Die leere-Blocks-Pruefung fehlt oder als true zurueckgegeben wird.
    func test_isFulfilled_fokus_whenNoFocusBlock_returnsFalse() {
        let result = IntentionEvaluationService.isFulfilled(
            intention: .fokus, tasks: [], focusBlocks: []
        )
        XCTAssertFalse(result, "Fokus should not be fulfilled without focus blocks")
    }

    // MARK: - isFulfilled: Growth

    /// Verhalten: Growth ist erfuellt wenn ein "learning"-Task HEUTE erledigt wurde.
    /// Bricht wenn: taskType=="learning" Pruefung oder completedToday-Filter fehlt.
    func test_isFulfilled_growth_whenLearningTaskCompletedToday_returnsTrue() {
        let task = makeTask(isCompleted: true, completedAt: today, taskType: "learning")
        let result = IntentionEvaluationService.isFulfilled(
            intention: .growth, tasks: [task], focusBlocks: []
        )
        XCTAssertTrue(result, "Growth should be fulfilled when learning task completed today")
    }

    /// Verhalten: Tasks mit anderem taskType erfuellen Growth NICHT.
    /// Bricht wenn: taskType-Pruefung fehlt oder auf falschen Wert prueft.
    func test_isFulfilled_growth_whenNoLearningTask_returnsFalse() {
        let task = makeTask(isCompleted: true, completedAt: today, taskType: "income")
        let result = IntentionEvaluationService.isFulfilled(
            intention: .growth, tasks: [task], focusBlocks: []
        )
        XCTAssertFalse(result, "Non-learning tasks should not fulfill Growth")
    }

    // MARK: - isFulfilled: Connection

    /// Verhalten: Connection ist erfuellt wenn ein "giving_back"-Task HEUTE erledigt wurde.
    /// Bricht wenn: taskType=="giving_back" Pruefung fehlt.
    func test_isFulfilled_connection_whenGivingBackTaskCompletedToday_returnsTrue() {
        let task = makeTask(isCompleted: true, completedAt: today, taskType: "giving_back")
        let result = IntentionEvaluationService.isFulfilled(
            intention: .connection, tasks: [task], focusBlocks: []
        )
        XCTAssertTrue(result, "Connection should be fulfilled when giving_back task completed today")
    }

    /// Verhalten: Ohne "giving_back"-Tasks ist Connection NICHT erfuellt.
    /// Bricht wenn: leere Task-Liste faelschlicherweise als erfuellt gilt.
    func test_isFulfilled_connection_whenNoGivingBackTask_returnsFalse() {
        let result = IntentionEvaluationService.isFulfilled(
            intention: .connection, tasks: [], focusBlocks: []
        )
        XCTAssertFalse(result, "Connection needs a giving_back task")
    }

    // MARK: - isFulfilled: Balance

    /// Verhalten: Balance ist erfuellt bei Tasks in >= 3 verschiedenen Kategorien HEUTE.
    /// Bricht wenn: distinctCategories-Zaehlung oder >= 3 Schwelle fehlt.
    func test_isFulfilled_balance_whenThreeCategoriesCompletedToday_returnsTrue() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
            makeTask(isCompleted: true, completedAt: today, taskType: "giving_back"),
        ]
        let result = IntentionEvaluationService.isFulfilled(
            intention: .balance, tasks: tasks, focusBlocks: []
        )
        XCTAssertTrue(result, "Balance needs tasks in >= 3 distinct categories")
    }

    /// Verhalten: Nur 2 Kategorien reichen NICHT fuer Balance.
    /// Bricht wenn: Schwelle auf < 3 gesenkt wird.
    func test_isFulfilled_balance_whenOnlyTwoCategories_returnsFalse() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
        ]
        let result = IntentionEvaluationService.isFulfilled(
            intention: .balance, tasks: tasks, focusBlocks: []
        )
        XCTAssertFalse(result, "Two tasks in same category should not fulfill Balance")
    }

    // MARK: - detectGap: Survival

    /// Verhalten: Survival liefert NIEMALS einen Gap — keine Nudges.
    /// Bricht wenn: detectGap fuer .survival einen nicht-nil Wert zurueckgibt.
    func test_detectGap_survival_returnsNil() {
        let result = IntentionEvaluationService.detectGap(
            intention: .survival, tasks: [], focusBlocks: []
        )
        XCTAssertNil(result, "Survival should never produce a gap")
    }

    // MARK: - detectGap: BHAG

    /// Verhalten: Ohne Focus Block mit BHAG-Task → Gap .noBhagBlockCreated.
    /// Bricht wenn: BHAG-Block-Pruefung oder Gap-Enum-Case fehlt.
    func test_detectGap_bhag_whenNoFocusBlockWithBhagTask_returnsNoBhagBlock() {
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        let result = IntentionEvaluationService.detectGap(
            intention: .bhag, tasks: [], focusBlocks: [], now: morning
        )
        XCTAssertEqual(result, .noBhagBlockCreated)
    }

    /// Verhalten: Nachmittags ohne erledigten BHAG-Task → Gap .bhagTaskNotStarted.
    /// Bricht wenn: Nachmittags-Pruefung (hour >= 13) oder Gap-Case fehlt.
    func test_detectGap_bhag_whenAfternoonAndBhagNotDone_returnsBhagNotStarted() {
        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        let block = makeBlock(taskIDs: ["t1"])
        let normalTask = makeTask(importance: 2, isCompleted: false)
        let result = IntentionEvaluationService.detectGap(
            intention: .bhag, tasks: [normalTask], focusBlocks: [block], now: afternoon
        )
        XCTAssertEqual(result, .bhagTaskNotStarted)
    }

    /// Verhalten: BHAG-Task erledigt → kein Gap (nil).
    /// Bricht wenn: isFulfilled-Pruefung in detectGap fehlt.
    func test_detectGap_bhag_whenBhagTaskDone_returnsNil() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.detectGap(
            intention: .bhag, tasks: [task], focusBlocks: []
        )
        XCTAssertNil(result, "Fulfilled BHAG should have no gap")
    }

    // MARK: - detectGap: Fokus

    /// Verhalten: Ohne Focus Blocks → Gap .noFocusBlockPlanned.
    /// Bricht wenn: leere-Block-Pruefung oder Gap-Case fehlt.
    func test_detectGap_fokus_whenNoFocusBlock_returnsNoFocusBlockPlanned() {
        let result = IntentionEvaluationService.detectGap(
            intention: .fokus, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .noFocusBlockPlanned)
    }

    /// Verhalten: Tasks ausserhalb von Blocks erledigt → Gap .tasksOutsideBlocks.
    /// Bricht wenn: assignedFocusBlockID-Pruefung auf erledigten Tasks fehlt.
    func test_detectGap_fokus_whenTasksCompletedOutsideBlocks_returnsTasksOutsideBlocks() {
        let block = makeBlock(taskIDs: ["in-block"])
        let taskOutside = makeTask(isCompleted: true, completedAt: today, assignedFocusBlockID: nil)
        let result = IntentionEvaluationService.detectGap(
            intention: .fokus, tasks: [taskOutside], focusBlocks: [block]
        )
        XCTAssertEqual(result, .tasksOutsideBlocks)
    }

    /// Verhalten: Focus Block existiert, alle Tasks in Blocks → kein Gap.
    /// Bricht wenn: die erfuellt-Pruefung die Block-Existenz nicht beruecksichtigt.
    func test_detectGap_fokus_whenFulfilledNoGap_returnsNil() {
        let block = makeBlock(taskIDs: ["t1"])
        let result = IntentionEvaluationService.detectGap(
            intention: .fokus, tasks: [], focusBlocks: [block]
        )
        XCTAssertNil(result, "Fokus with existing block and no outside tasks should have no gap")
    }

    // MARK: - completedToday helper

    /// Verhalten: Filtert Tasks auf heute erledigte (completedAt >= startOfDay).
    /// Bricht wenn: Tages-Grenze falsch berechnet oder completedAt ignoriert wird.
    func test_completedToday_filtersByCompletedAtDate() {
        let todayTask = makeTask(isCompleted: true, completedAt: today)
        let yesterdayTask = makeTask(isCompleted: true, completedAt: yesterday)
        let incompleteTask = makeTask(isCompleted: false)

        let result = IntentionEvaluationService.completedToday(
            [todayTask, yesterdayTask, incompleteTask]
        )
        XCTAssertEqual(result.count, 1, "Only today's completed task should be returned")
    }

    // MARK: - evaluateFulfillment: Survival

    /// Verhalten: Survival + ≥1 Task erledigt → .fulfilled
    /// Bricht wenn: evaluateFulfillment() den survival-Case nicht als fulfilled behandelt wenn Tasks vorhanden.
    func test_evaluateFulfillment_survival_fulfilled() {
        let task = makeTask(isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .survival, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Survival with completed tasks should be fulfilled")
    }

    /// Verhalten: Survival + 0 Tasks erledigt → .notFulfilled
    /// Bricht wenn: survival immer .fulfilled zurueckgibt ohne Task-Pruefung.
    func test_evaluateFulfillment_survival_notFulfilled() {
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .survival, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Survival with no tasks should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: Fokus

    /// Verhalten: Fokus + Block-Completion ≥70% → .fulfilled
    /// Bricht wenn: blockCompletionPercentage-Schwelle nicht bei 0.7 liegt.
    func test_evaluateFulfillment_fokus_fulfilled() {
        // 3 von 4 Tasks completed = 75%
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1", "t2", "t3"]
        )
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .fokus, tasks: [], focusBlocks: [block]
        )
        XCTAssertEqual(result, .fulfilled, "Fokus with 75% block completion should be fulfilled")
    }

    /// Verhalten: Fokus + Block-Completion 40-69% → .partial
    /// Bricht wenn: partial-Schwelle nicht bei [0.4, 0.7) liegt.
    func test_evaluateFulfillment_fokus_partial() {
        // 2 von 4 Tasks completed = 50%
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1", "t2"]
        )
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .fokus, tasks: [], focusBlocks: [block]
        )
        XCTAssertEqual(result, .partial, "Fokus with 50% block completion should be partial")
    }

    /// Verhalten: Fokus + Block-Completion <40% → .notFulfilled
    /// Bricht wenn: notFulfilled-Schwelle nicht unter 0.4 liegt.
    func test_evaluateFulfillment_fokus_notFulfilled_lowCompletion() {
        // 1 von 4 Tasks = 25%
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1"]
        )
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .fokus, tasks: [], focusBlocks: [block]
        )
        XCTAssertEqual(result, .notFulfilled, "Fokus with 25% block completion should be notFulfilled")
    }

    /// Verhalten: Fokus + keine Blocks → .notFulfilled
    /// Bricht wenn: leere Blocks faelschlicherweise als partial/fulfilled behandelt werden.
    func test_evaluateFulfillment_fokus_notFulfilled_noBlocks() {
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .fokus, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Fokus with no blocks should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: BHAG

    /// Verhalten: BHAG + importance-3 Task erledigt → .fulfilled
    /// Bricht wenn: importance==3 Pruefung in evaluateFulfillment fehlt.
    func test_evaluateFulfillment_bhag_fulfilled() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .bhag, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "BHAG with importance-3 task completed should be fulfilled")
    }

    /// Verhalten: BHAG + Tasks erledigt aber keiner mit importance=3 → .partial
    /// Bricht wenn: partial-Logik zwischen "Tasks erledigt" und "kein BHAG-Task" fehlt.
    func test_evaluateFulfillment_bhag_partial() {
        let task = makeTask(importance: 2, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .bhag, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "BHAG with tasks but no importance-3 should be partial")
    }

    /// Verhalten: BHAG + keine Tasks erledigt → .notFulfilled
    /// Bricht wenn: leere Task-Liste nicht als notFulfilled behandelt wird.
    func test_evaluateFulfillment_bhag_notFulfilled() {
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .bhag, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "BHAG with no tasks should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: Balance

    /// Verhalten: Balance + Tasks in ≥3 Kategorien → .fulfilled
    /// Bricht wenn: Kategorie-Zaehlung oder >=3 Schwelle in evaluateFulfillment fehlt.
    func test_evaluateFulfillment_balance_fulfilled() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
            makeTask(isCompleted: true, completedAt: today, taskType: "giving_back"),
        ]
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .balance, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Balance with 3 categories should be fulfilled")
    }

    /// Verhalten: Balance + Tasks in genau 2 Kategorien → .partial
    /// Bricht wenn: Unterscheidung zwischen 2 und ≥3 Kategorien fehlt.
    func test_evaluateFulfillment_balance_partial() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
        ]
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .balance, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "Balance with exactly 2 categories should be partial")
    }

    /// Verhalten: Balance + Tasks in ≤1 Kategorie → .notFulfilled
    /// Bricht wenn: ≤1 Kategorie nicht als notFulfilled erkannt wird.
    func test_evaluateFulfillment_balance_notFulfilled() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
        ]
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .balance, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Balance with 1 category should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: Growth

    /// Verhalten: Growth + "learning" Task erledigt → .fulfilled
    /// Bricht wenn: taskType=="learning" Pruefung in evaluateFulfillment fehlt.
    func test_evaluateFulfillment_growth_fulfilled() {
        let task = makeTask(isCompleted: true, completedAt: today, taskType: "learning")
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .growth, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Growth with learning task should be fulfilled")
    }

    /// Verhalten: Growth + kein "learning" Task → .notFulfilled
    /// Bricht wenn: fehlender learning-Task als partial/fulfilled behandelt wird.
    func test_evaluateFulfillment_growth_notFulfilled() {
        let task = makeTask(isCompleted: true, completedAt: today, taskType: "income")
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .growth, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Growth without learning task should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: Connection

    /// Verhalten: Connection + "giving_back" Task erledigt → .fulfilled
    /// Bricht wenn: taskType=="giving_back" Pruefung fehlt.
    func test_evaluateFulfillment_connection_fulfilled() {
        let task = makeTask(isCompleted: true, completedAt: today, taskType: "giving_back")
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .connection, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Connection with giving_back task should be fulfilled")
    }

    /// Verhalten: Connection + kein "giving_back" Task → .notFulfilled
    /// Bricht wenn: fehlender giving_back-Task als fulfilled behandelt wird.
    func test_evaluateFulfillment_connection_notFulfilled() {
        let result = IntentionEvaluationService.evaluateFulfillment(
            intention: .connection, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Connection without giving_back task should be notFulfilled")
    }

    // MARK: - blockCompletionPercentage

    /// Verhalten: Alle Tasks in Blocks erledigt → 1.0 (100%)
    /// Bricht wenn: completedTaskIDs/taskIDs Ratio-Berechnung fehlt.
    func test_blockCompletionPercentage_allCompleted() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3"],
            completedTaskIDs: ["t1", "t2", "t3"]
        )
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: [block]
        )
        XCTAssertEqual(result, 1.0, accuracy: 0.01, "All tasks completed should be 100%")
    }

    /// Verhalten: Teilweise erledigt → korrekte Ratio
    /// Bricht wenn: Zaehlung von completedTaskIDs oder taskIDs falsch ist.
    func test_blockCompletionPercentage_partial() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1", "t2"]
        )
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: [block]
        )
        XCTAssertEqual(result, 0.5, accuracy: 0.01, "2 of 4 should be 50%")
    }

    /// Verhalten: Keine Blocks → 0.0
    /// Bricht wenn: leere Block-Liste nicht als 0.0 behandelt wird.
    func test_blockCompletionPercentage_noBlocks() {
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: []
        )
        XCTAssertEqual(result, 0.0, accuracy: 0.01, "No blocks should be 0%")
    }

    /// Verhalten: Blocks ohne Tasks → 0.0
    /// Bricht wenn: Division durch 0 bei leeren taskIDs.
    func test_blockCompletionPercentage_emptyBlocks() {
        let block = makeBlock(taskIDs: [], completedTaskIDs: [])
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: [block]
        )
        XCTAssertEqual(result, 0.0, accuracy: 0.01, "Blocks with no tasks should be 0%")
    }

    // MARK: - Fallback Templates

    /// Verhalten: Jede Intention + fulfilled hat einen nicht-leeren Template-Text.
    /// Bricht wenn: fallbackTemplate() fuer eine Intention keinen Text zurueckgibt.
    func test_fallbackTemplate_allIntentions_fulfilled() {
        for intention in IntentionOption.allCases {
            let text = IntentionEvaluationService.fallbackTemplate(
                intention: intention, level: .fulfilled
            )
            XCTAssertFalse(text.isEmpty, "\(intention) fulfilled should have a template")
        }
    }

    /// Verhalten: Jede Intention + notFulfilled hat einen nicht-leeren Template-Text.
    /// Bricht wenn: fallbackTemplate() fuer notFulfilled keinen Text zurueckgibt.
    func test_fallbackTemplate_allIntentions_notFulfilled() {
        for intention in IntentionOption.allCases {
            let text = IntentionEvaluationService.fallbackTemplate(
                intention: intention, level: .notFulfilled
            )
            XCTAssertFalse(text.isEmpty, "\(intention) notFulfilled should have a template")
        }
    }

    /// Verhalten: Intentionen mit partial-Stufe haben nicht-leeren Template-Text.
    /// Bricht wenn: fallbackTemplate() fuer partial-Stufen keinen Text liefert.
    func test_fallbackTemplate_partialIntentions() {
        let partialIntentions: [IntentionOption] = [.fokus, .bhag, .balance]
        for intention in partialIntentions {
            let text = IntentionEvaluationService.fallbackTemplate(
                intention: intention, level: .partial
            )
            XCTAssertFalse(text.isEmpty, "\(intention) partial should have a template")
        }
    }
}
