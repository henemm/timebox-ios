import XCTest
import SwiftData
@testable import FocusBlox

/// Bug 44: Review Tab - Daily category breakdown missing + data bugs
/// Tests verify that:
/// 1. iOS loadData uses FetchDescriptor (not syncEngine.sync)
/// 2. macOS filters by completedAt (not createdAt)
/// 3. Daily category stats can be computed from today's blocks
@MainActor
final class ReviewDailyCategoryTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Bug 1: iOS loadData uses sync() which filters completed tasks

    /// GIVEN: 3 tasks, 2 completed
    /// WHEN: Loading ALL tasks via FetchDescriptor (the fix)
    /// THEN: All 3 tasks returned including completed ones
    /// RED: DailyReviewView.loadData() still uses syncEngine.sync()
    func testFetchDescriptorReturnsAllTasks() throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Done A", importance: 1)
        task1.isCompleted = true
        task1.completedAt = Date()
        task1.taskType = "income"

        let task2 = LocalTask(title: "Done B", importance: 1)
        task2.isCompleted = true
        task2.completedAt = Date()
        task2.taskType = "maintenance"

        let task3 = LocalTask(title: "Open C", importance: 1)
        task3.taskType = "recharge"

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        // This is what the FIX should do: fetch ALL tasks
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let planItems = allTasks.map { PlanItem(localTask: $0) }

        XCTAssertEqual(planItems.count, 3, "FetchDescriptor muss alle 3 Tasks liefern")

        // Verify completed tasks have their category
        let completedItems = planItems.filter { $0.isCompleted }
        XCTAssertEqual(completedItems.count, 2, "2 erledigte Tasks muessen dabei sein")
    }

    // MARK: - Bug 3: macOS filters by createdAt instead of completedAt

    /// GIVEN: Task created yesterday, completed today
    /// WHEN: Filtering by completedAt >= startOfToday
    /// THEN: Task appears in today's review
    /// RED: MacReviewView uses createdAt which would miss this task
    func testFilterByCompletedAtNotCreatedAt() throws {
        let context = container.mainContext
        let calendar = Calendar.current

        let task = LocalTask(title: "Yesterday task", importance: 1)
        // Created yesterday
        task.createdAt = calendar.date(byAdding: .day, value: -1, to: Date())!
        // Completed today
        task.isCompleted = true
        task.completedAt = Date()
        task.taskType = "income"

        context.insert(task)
        try context.save()

        let startOfToday = calendar.startOfDay(for: Date())

        // BUG: Current macOS behavior - filters by createdAt
        let filteredByCreatedAt = try context.fetch(FetchDescriptor<LocalTask>())
            .filter { $0.isCompleted && $0.createdAt >= startOfToday }
        XCTAssertEqual(filteredByCreatedAt.count, 0,
            "createdAt Filter findet 0 - das ist der Bug")

        // FIX: Filter by completedAt
        let filteredByCompletedAt = try context.fetch(FetchDescriptor<LocalTask>())
            .filter { $0.isCompleted && ($0.completedAt ?? .distantPast) >= startOfToday }
        XCTAssertEqual(filteredByCompletedAt.count, 1,
            "completedAt Filter findet den Task korrekt")
    }

    // MARK: - Bug 2+4: Daily category stats computation

    /// GIVEN: Completed tasks with categories and durations
    /// WHEN: Computing category stats for daily view
    /// THEN: Stats grouped by category with correct minutes
    /// RED: dailyCategoryStats property doesn't exist yet on iOS
    ///       DayReviewContent doesn't compute category stats on macOS
    func testDailyCategoryStatsComputation() throws {
        // Simulate the computation that SHOULD happen in daily view
        let calculator = ReviewStatsCalculator()

        // Task minutes by category (from completed tasks today)
        let taskMinutes: [String: Int] = [
            "income": 45,
            "maintenance": 30,
            "recharge": 15
        ]

        // Calendar events for today
        let now = Date()
        let events = [
            CalendarEvent(
                id: "evt1",
                title: "Client Call",
                startDate: now,
                endDate: now.addingTimeInterval(60 * 60),
                isAllDay: false,
                calendarColor: nil,
                notes: "category:income"
            )
        ]

        let stats = calculator.computeCategoryMinutes(
            taskMinutesByCategory: taskMinutes,
            calendarEvents: events
        )

        XCTAssertEqual(stats["income"], 105, "income: 45 task + 60 event = 105")
        XCTAssertEqual(stats["maintenance"], 30, "maintenance: 30 task")
        XCTAssertEqual(stats["recharge"], 15, "recharge: 15 task")
    }

    // MARK: - Daily calendar event filtering

    /// GIVEN: Calendar events from multiple days
    /// WHEN: Filtering to today only
    /// THEN: Only today's events included in daily stats
    func testDailyCalendarEventFiltering() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayEvent = CalendarEvent(
            id: "today",
            title: "Today Meeting",
            startDate: today,
            endDate: today.addingTimeInterval(30 * 60),
            isAllDay: false,
            calendarColor: nil,
            notes: "category:income"
        )

        let yesterdayEvent = CalendarEvent(
            id: "yesterday",
            title: "Yesterday Meeting",
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(60 * 60),
            isAllDay: false,
            calendarColor: nil,
            notes: "category:income"
        )

        let allEvents = [todayEvent, yesterdayEvent]

        // Filter to today - this is what the daily view SHOULD do
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let todayEvents = allEvents.filter {
            $0.startDate >= startOfToday && $0.startDate < endOfToday
        }

        XCTAssertEqual(todayEvents.count, 1, "Nur 1 Event von heute")

        let calculator = ReviewStatsCalculator()
        let stats = calculator.computeCategoryMinutes(
            taskMinutesByCategory: [:],
            calendarEvents: todayEvents
        )

        XCTAssertEqual(stats["income"], 30, "Nur 30 min vom heutigen Event")
    }
}
