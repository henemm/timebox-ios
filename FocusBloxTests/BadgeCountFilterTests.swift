import XCTest
import SwiftData
@testable import FocusBlox

/// Tests fuer Badge-Count-Logik: Badge soll nur Backlog-ueberfaellige Tasks zaehlen,
/// NICHT Tasks die in NextUp oder einem FocusBlock zugewiesen sind.
///
/// Bug: Badge zeigte (8) obwohl nur 4 ueberfaellige Tasks in der UI sichtbar waren.
/// Root Cause: Badge filterte !isNextUp und assignedFocusBlockID == nil nicht.
@MainActor
final class BadgeCountFilterTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    // MARK: - Core Bug: NextUp tasks must NOT be counted

    /// Verhalten: Ueberfaellige Tasks die in NextUp sind, sollen NICHT im Badge erscheinen.
    /// Bricht wenn: countOverdueBadgeTasks() den isNextUp-Filter NICHT prueft.
    func test_overdueNextUpTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "Overdue but NextUp")
        task.dueDate = yesterday
        task.isNextUp = true
        task.isCompleted = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countOverdueBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Overdue task in NextUp should NOT be counted in badge")
    }

    // MARK: - Core Bug: FocusBlock-assigned tasks must NOT be counted

    /// Verhalten: Ueberfaellige Tasks die einem FocusBlock zugewiesen sind, sollen NICHT im Badge erscheinen.
    /// Bricht wenn: countOverdueBadgeTasks() den assignedFocusBlockID-Filter NICHT prueft.
    func test_overdueAssignedTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "Overdue but in FocusBlock")
        task.dueDate = yesterday
        task.assignedFocusBlockID = "block-123"
        task.isCompleted = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countOverdueBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Overdue task assigned to FocusBlock should NOT be counted in badge")
    }

    // MARK: - Positive: Backlog overdue tasks MUST be counted

    /// Verhalten: Ueberfaellige Tasks im Backlog (nicht NextUp, nicht zugewiesen) MUESSEN gezaehlt werden.
    /// Bricht wenn: countOverdueBadgeTasks() faelschlicherweise Backlog-Tasks ausfiltert.
    func test_overdueBacklogTask_isCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "Overdue in Backlog")
        task.dueDate = yesterday
        task.isNextUp = false
        task.assignedFocusBlockID = nil
        task.isCompleted = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countOverdueBadgeTasks(context: context)
        XCTAssertEqual(count, 1, "Overdue backlog task MUST be counted in badge")
    }

    // MARK: - Existing filters still work

    /// Verhalten: Erledigte Tasks werden nicht gezaehlt (bestehender Filter).
    func test_completedOverdueTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "Completed overdue")
        task.dueDate = yesterday
        task.isCompleted = true
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countOverdueBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Completed task should NOT be counted")
    }

    /// Verhalten: Template-Tasks werden nicht gezaehlt (bestehender Filter).
    func test_templateOverdueTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let task = LocalTask(title: "Template overdue")
        task.dueDate = yesterday
        task.isTemplate = true
        task.isCompleted = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countOverdueBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Template task should NOT be counted")
    }

    // MARK: - Mixed scenario (reproduces the bug)

    /// Verhalten: Bei 4 Backlog-ueberfaelligen + 4 NextUp/Block-ueberfaelligen soll Badge = 4 zeigen.
    /// Bricht wenn: Badge alle 8 ueberfaelligen zaehlt (der urspruengliche Bug).
    func test_mixedScenario_onlyBacklogOverdueCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let today = Calendar.current.startOfDay(for: Date())

        // 4 overdue backlog tasks (SHOULD be counted)
        for i in 1...4 {
            let task = LocalTask(title: "Backlog Overdue \(i)")
            task.dueDate = yesterday
            task.isNextUp = false
            task.assignedFocusBlockID = nil
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        // 2 overdue NextUp tasks (should NOT be counted)
        for i in 1...2 {
            let task = LocalTask(title: "NextUp Overdue \(i)")
            task.dueDate = yesterday
            task.isNextUp = true
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        // 2 overdue FocusBlock-assigned tasks (should NOT be counted)
        for i in 1...2 {
            let task = LocalTask(title: "Block Overdue \(i)")
            task.dueDate = yesterday
            task.assignedFocusBlockID = "block-\(i)"
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        // 5 today tasks (should NOT be counted - not overdue)
        for i in 1...5 {
            let task = LocalTask(title: "Today \(i)")
            task.dueDate = today
            task.isCompleted = false
            task.isTemplate = false
            context.insert(task)
        }

        try context.save()

        let count = NotificationService.countOverdueBadgeTasks(context: context)
        XCTAssertEqual(count, 4, "Badge should show 4 (only backlog overdue), not 8 (all overdue)")
    }
}
