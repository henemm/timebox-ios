import XCTest
import SwiftData
@testable import FocusBlox

/// Tests fuer Badge-Count-Logik: Badge soll nur doNow-Tasks im Backlog zaehlen,
/// NICHT Tasks die in NextUp oder einem FocusBlock zugewiesen sind.
///
/// Bug #227: Badge-Zahlen inkonsistent (Icon != Tab != Liste).
/// Fix: Einheitliche doNow-Logik (Score >= 60) mit konsistenten Filtern.
@MainActor
final class BadgeCountFilterTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    // MARK: - Core Bug: NextUp tasks must NOT be counted

    /// Verhalten: DoNow-Tasks die in NextUp sind, sollen NICHT im Badge erscheinen.
    /// Bricht wenn: countDoNowBadgeTasks() den isNextUp-Filter NICHT prueft.
    func test_doNowNextUpTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "DoNow but NextUp")
        task.dueDate = yesterday
        task.importance = 3
        task.urgency = "urgent"
        task.isNextUp = true
        task.isCompleted = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "DoNow task in NextUp should NOT be counted in badge")
    }

    // MARK: - Core Bug: FocusBlock-assigned tasks must NOT be counted

    /// Verhalten: DoNow-Tasks die einem FocusBlock zugewiesen sind, sollen NICHT im Badge erscheinen.
    /// Bricht wenn: countDoNowBadgeTasks() den assignedFocusBlockID-Filter NICHT prueft.
    func test_doNowAssignedTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "DoNow but in FocusBlock")
        task.dueDate = yesterday
        task.importance = 3
        task.urgency = "urgent"
        task.assignedFocusBlockID = "block-123"
        task.isCompleted = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "DoNow task assigned to FocusBlock should NOT be counted in badge")
    }

    // MARK: - Positive: Backlog overdue tasks MUST be counted

    /// Verhalten: DoNow-Tasks im Backlog (nicht NextUp, nicht zugewiesen) MUESSEN gezaehlt werden.
    /// Bricht wenn: countDoNowBadgeTasks() faelschlicherweise Backlog-Tasks ausfiltert.
    func test_doNowBacklogTask_isCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "DoNow in Backlog")
        task.dueDate = yesterday
        task.importance = 3
        task.urgency = "urgent"
        task.isNextUp = false
        task.assignedFocusBlockID = nil
        task.isCompleted = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 1, "DoNow backlog task MUST be counted in badge")
    }

    // MARK: - Existing filters still work

    /// Verhalten: Erledigte Tasks werden nicht gezaehlt (bestehender Filter).
    func test_completedDoNowTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "Completed doNow")
        task.dueDate = yesterday
        task.importance = 3
        task.urgency = "urgent"
        task.isCompleted = true
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Completed task should NOT be counted")
    }

    /// Verhalten: Template-Tasks werden nicht gezaehlt (bestehender Filter).
    func test_templateDoNowTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "Template doNow")
        task.dueDate = yesterday
        task.importance = 3
        task.urgency = "urgent"
        task.isTemplate = true
        task.isCompleted = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Template task should NOT be counted")
    }

    // MARK: - Mixed scenario (reproduces the bug)

    /// Verhalten: Bei 4 Backlog-doNow + 4 NextUp/Block-doNow soll Badge = 4 zeigen.
    /// Bricht wenn: Badge alle 8 doNow-Tasks zaehlt (der urspruengliche Bug).
    func test_mixedScenario_onlyBacklogDoNowCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        // 4 doNow backlog tasks (SHOULD be counted)
        for i in 1...4 {
            let task = LocalTask(title: "Backlog DoNow \(i)")
            task.dueDate = yesterday
            task.importance = 3
            task.urgency = "urgent"
            task.isNextUp = false
            task.assignedFocusBlockID = nil
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        // 2 doNow NextUp tasks (should NOT be counted)
        for i in 1...2 {
            let task = LocalTask(title: "NextUp DoNow \(i)")
            task.dueDate = yesterday
            task.importance = 3
            task.urgency = "urgent"
            task.isNextUp = true
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        // 2 doNow FocusBlock-assigned tasks (should NOT be counted)
        for i in 1...2 {
            let task = LocalTask(title: "Block DoNow \(i)")
            task.dueDate = yesterday
            task.importance = 3
            task.urgency = "urgent"
            task.assignedFocusBlockID = "block-\(i)"
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        // 5 low-priority tasks (should NOT be counted - not doNow)
        for i in 1...5 {
            let task = LocalTask(title: "Low Priority \(i)")
            task.importance = 1
            task.urgency = "not_urgent"
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 4, "Badge should show 4 (only backlog doNow), not 8 (all doNow)")
    }
}
