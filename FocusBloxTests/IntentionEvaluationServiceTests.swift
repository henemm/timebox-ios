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
}
