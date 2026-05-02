import XCTest
import SwiftData
@testable import FocusBlox

/// Tests für Badge-Count-Logik mit SwiftData-Integration — umgeschrieben für Overdue-Rework.
///
/// VORHER: Tests prüften dass NotificationService.countDoNowBadgeTasks() Score-basiert zählt.
/// JETZT: Tests prüfen dass NotificationService.countDoNowBadgeTasks() zeitbasiert zählt
///        (delegiert an BacklogBadgeService.countOverdueTasks).
///
/// Kern-Invariante: Beide Counter-Quellen liefern identischen Wert.
///
/// TDD RED: Tests SCHLAGEN FEHL weil:
/// - NotificationService.countDoNowBadgeTasks() noch eigene Score-Logik hat
/// - Ein überfälliger Task OHNE Score (importance=nil, urgency=nil) wird von der
///   alten Logik NICHT gezählt — nach dem Fix muss er gezählt werden.
@MainActor
final class BadgeCountFilterTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Kern-Test: Zeitbasiert statt Score-basiert

    /// Verhalten: Überfälliger Task OHNE Score-Attribute wird gezählt.
    /// Bricht wenn: countDoNowBadgeTasks Score-Filter beibehält (alter Bug).
    ///
    /// Das ist die wichtigste Regression: ein Task mit dueDate gestern aber
    /// ohne Eisenhower-Bewertung (importance=nil, urgency=nil) hat Score 0
    /// → wird von ALTEM Code nicht gezählt → MUSS von neuem Code gezählt werden.
    func test_overdueTaskWithoutScore_isCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // Task ohne Score (importance=nil, urgency=nil) — Score wäre << 60
        let task = LocalTask(title: "Überfällig ohne Score", importance: nil, isCompleted: false,
                             dueDate: yesterday, estimatedDuration: nil, urgency: nil)
        task.isNextUp = false
        task.isParked = false
        task.isTemplate = false
        task.assignedFocusBlockID = nil
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(
            count, 1,
            "Überfälliger Task ohne Score MUSS gezählt werden (zeitbasiert, nicht Score-basiert). "
            + "Alter Code gibt 0 zurück — das ist der Bug."
        )
    }

    // MARK: - Positive: Überfälliger Backlog-Task wird gezählt

    /// Verhalten: Überfälliger Task im Backlog MUSS gezählt werden.
    /// Bricht wenn: countDoNowBadgeTasks überfällige Tasks ausfiltert.
    func test_overdueBacklogTask_isCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let task = LocalTask(title: "Überfällig im Backlog", importance: 2, isCompleted: false,
                             dueDate: yesterday, estimatedDuration: 30, urgency: "not_urgent")
        task.isNextUp = false
        task.isParked = false
        task.isTemplate = false
        task.assignedFocusBlockID = nil
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 1, "Überfälliger Backlog-Task MUSS gezählt werden")
    }

    // MARK: - Negative: Zukünftiger Task wird nicht gezählt

    /// Verhalten: Task mit dueDate morgen wird NICHT gezählt.
    /// Bricht wenn: countDoNowBadgeTasks zukünftige Tasks mitzählt.
    func test_futureDueDateTask_isNotCounted() throws {
        let context = ModelContext(container)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let task = LocalTask(title: "Zukünftig", importance: 3, isCompleted: false,
                             dueDate: tomorrow, estimatedDuration: 30, urgency: "urgent")
        task.isNextUp = false
        task.isParked = false
        task.isTemplate = false
        task.assignedFocusBlockID = nil
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Task mit dueDate morgen darf nicht gezählt werden")
    }

    /// Verhalten: Task ohne dueDate wird NICHT gezählt.
    func test_taskWithNoDueDate_isNotCounted() throws {
        let context = ModelContext(container)

        let task = LocalTask(title: "Kein Datum", importance: 3, isCompleted: false,
                             dueDate: nil, estimatedDuration: 30, urgency: "urgent")
        task.isNextUp = false
        task.isParked = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Task ohne dueDate darf nicht gezählt werden")
    }

    // MARK: - Bestehende Filter bleiben gültig

    /// Verhalten: NextUp-Tasks werden nicht gezählt.
    /// Bricht wenn: countDoNowBadgeTasks NextUp-Filter verliert.
    func test_overdueNextUpTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let task = LocalTask(title: "Überfällig aber NextUp", importance: 3, isCompleted: false,
                             dueDate: yesterday, estimatedDuration: 30, urgency: "urgent")
        task.isNextUp = true
        task.isParked = false
        task.isTemplate = false
        task.assignedFocusBlockID = nil
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "NextUp-Task darf nicht im Badge gezählt werden")
    }

    /// Verhalten: FocusBlock-Tasks werden nicht gezählt.
    func test_overdueAssignedTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let task = LocalTask(title: "Überfällig im FocusBlock", importance: 3, isCompleted: false,
                             dueDate: yesterday, estimatedDuration: 30, urgency: "urgent")
        task.isNextUp = false
        task.isParked = false
        task.isTemplate = false
        task.assignedFocusBlockID = "block-123"
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "FocusBlock-Task darf nicht im Badge gezählt werden")
    }

    /// Verhalten: Erledigte Tasks werden nicht gezählt.
    func test_completedOverdueTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let task = LocalTask(title: "Erledigt", importance: 3, isCompleted: true,
                             dueDate: yesterday, estimatedDuration: 30, urgency: "urgent")
        task.isNextUp = false
        task.isParked = false
        task.isTemplate = false
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Erledigter Task darf nicht gezählt werden")
    }

    /// Verhalten: Template-Tasks werden nicht gezählt.
    func test_templateOverdueTask_isNotCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let task = LocalTask(title: "Template", importance: 3, isCompleted: false,
                             dueDate: yesterday, estimatedDuration: 30, urgency: "urgent")
        task.isNextUp = false
        task.isParked = false
        task.isTemplate = true
        context.insert(task)
        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(count, 0, "Template-Task darf nicht gezählt werden")
    }

    // MARK: - Kern-Invariante: Gemischtes Szenario

    /// Verhalten: Gemischte Datenlage — Badge zeigt exakt die Anzahl überfälliger Backlog-Tasks.
    /// Bricht wenn: Badge alle Tasks mischt oder Filter fehlen.
    ///
    /// Diese Test reproduziert den ursprünglichen Bug aus #227 (Score-Inkonsistenz),
    /// jetzt mit zeitbasiertem Kriterium.
    func test_mixedScenario_onlyOverdueBacklogTasksCounted() throws {
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        // 4 überfällige Backlog-Tasks ohne Score (MÜSSEN gezählt werden)
        for i in 1...4 {
            let task = LocalTask(title: "Überfällig \(i)", importance: nil, isCompleted: false,
                                 dueDate: yesterday, estimatedDuration: nil, urgency: nil)
            task.isNextUp = false
            task.isParked = false
            task.isTemplate = false
            task.assignedFocusBlockID = nil
            context.insert(task)
        }

        // 2 überfällige NextUp-Tasks (dürfen NICHT gezählt werden)
        for i in 1...2 {
            let task = LocalTask(title: "NextUp Überfällig \(i)", importance: 3, isCompleted: false,
                                 dueDate: yesterday, estimatedDuration: 30, urgency: "urgent")
            task.isNextUp = true
            task.isParked = false
            task.isTemplate = false
            context.insert(task)
        }

        // 3 Tasks mit zukünftigem Datum (dürfen NICHT gezählt werden)
        for i in 1...3 {
            let task = LocalTask(title: "Zukünftig \(i)", importance: 3, isCompleted: false,
                                 dueDate: tomorrow, estimatedDuration: 30, urgency: "urgent")
            task.isNextUp = false
            task.isParked = false
            task.isTemplate = false
            context.insert(task)
        }

        // 2 Tasks ohne Datum (dürfen NICHT gezählt werden)
        for i in 1...2 {
            let task = LocalTask(title: "Kein Datum \(i)", importance: nil, isCompleted: false,
                                 dueDate: nil, estimatedDuration: nil, urgency: nil)
            task.isNextUp = false
            task.isParked = false
            task.isTemplate = false
            context.insert(task)
        }

        try context.save()

        let count = NotificationService.countDoNowBadgeTasks(context: context)
        XCTAssertEqual(
            count, 4,
            "Badge muss 4 zeigen (nur überfällige Backlog-Tasks ohne Score) — "
            + "zeitbasiert, nicht Score-basiert"
        )
    }
}
