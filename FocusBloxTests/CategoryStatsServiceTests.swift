import XCTest
import SwiftData
@testable import FocusBlox

final class CategoryStatsServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helper

    private func makeCompletedTask(
        title: String = "Task",
        taskType: String = "",
        completedAt: Date = Date()
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: nil, isCompleted: true)
        task.taskType = taskType
        task.completedAt = completedAt
        context.insert(task)
        return task
    }

    private func dateWeeksAgo(_ weeksAgo: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date())!
    }

    // MARK: - categoryBreakdown Tests

    /// Verhalten: Leere Liste → 6 Eintraege (5 Kategorien + 1 Sonstiges), alle count=0
    /// Bricht wenn: CategoryStatsService.categoryBreakdown(for:) nicht existiert oder falsche Anzahl
    func test_categoryBreakdown_emptyList_returnsAllCategories() {
        let stats = CategoryStatsService.categoryBreakdown(for: [])

        XCTAssertEqual(stats.count, 6, "Should return 5 categories + 1 uncategorized")
        for stat in stats {
            XCTAssertEqual(stat.count, 0, "All counts should be 0")
            XCTAssertEqual(stat.total, 0, "Total should be 0")
        }
    }

    /// Verhalten: Tasks mit verschiedenen taskTypes → korrekte Verteilung
    /// Bricht wenn: categoryBreakdown die taskType-Zuordnung falsch macht
    func test_categoryBreakdown_mixedCategories_correctDistribution() {
        let _ = makeCompletedTask(title: "Earn money", taskType: "income")
        let _ = makeCompletedTask(title: "Clean house", taskType: "maintenance")
        let _ = makeCompletedTask(title: "Read book", taskType: "learning")

        let tasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let stats = CategoryStatsService.categoryBreakdown(for: tasks)

        let income = stats.first { $0.category == .income }
        let essentials = stats.first { $0.category == .essentials }
        let learn = stats.first { $0.category == .learn }

        XCTAssertEqual(income?.count, 1, "Income should have 1 task")
        XCTAssertEqual(essentials?.count, 1, "Essentials (maintenance) should have 1 task")
        XCTAssertEqual(learn?.count, 1, "Learn (learning) should have 1 task")
        XCTAssertEqual(stats.first?.total, 3, "Total should be 3")
    }

    /// Verhalten: Tasks ohne taskType (leerer String) → "Sonstiges" Kategorie
    /// Bricht wenn: Tasks mit taskType="" verloren gehen statt in uncategorized gezaehlt zu werden
    func test_categoryBreakdown_emptyTaskType_countsAsUncategorized() {
        let _ = makeCompletedTask(title: "No category", taskType: "")
        let _ = makeCompletedTask(title: "Also no category", taskType: "")
        let _ = makeCompletedTask(title: "With category", taskType: "income")

        let tasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let stats = CategoryStatsService.categoryBreakdown(for: tasks)

        let uncategorized = stats.first { $0.category == nil }
        XCTAssertEqual(uncategorized?.count, 2, "2 tasks without category should be in uncategorized")

        let income = stats.first { $0.category == .income }
        XCTAssertEqual(income?.count, 1, "Income should have 1 task")
    }

    /// Verhalten: Nur completed Tasks zaehlen
    /// Bricht wenn: Der isCompleted-Filter fehlt
    func test_categoryBreakdown_onlyCompletedTasksCounted() {
        let openTask = LocalTask(title: "Open", importance: nil, isCompleted: false)
        openTask.taskType = "income"
        context.insert(openTask)

        let completed = makeCompletedTask(title: "Done", taskType: "income")

        let stats = CategoryStatsService.categoryBreakdown(for: [openTask, completed])
        let totalCount = stats.reduce(0) { $0 + $1.count }

        XCTAssertEqual(totalCount, 1, "Only 1 completed task should be counted")
    }

    /// Verhalten: Ergebnis ist sortiert nach count (hoechster zuerst)
    /// Bricht wenn: Die Sortierung fehlt
    func test_categoryBreakdown_sortedByCountDescending() {
        let _ = makeCompletedTask(title: "A1", taskType: "income")
        let _ = makeCompletedTask(title: "A2", taskType: "income")
        let _ = makeCompletedTask(title: "A3", taskType: "income")
        let _ = makeCompletedTask(title: "B1", taskType: "learning")

        let tasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let stats = CategoryStatsService.categoryBreakdown(for: tasks)

        // Filter out zero-count entries for comparison
        let nonZero = stats.filter { $0.count > 0 }
        if nonZero.count >= 2 {
            XCTAssertGreaterThanOrEqual(
                nonZero[0].count, nonZero[1].count,
                "Stats should be sorted descending by count"
            )
        }
    }

    // MARK: - weeklyCategoryHistory Tests

    /// Verhalten: Keine Tasks → 6 Snapshots, alle mit count=0
    /// Bricht wenn: weeklyCategoryHistory() nicht existiert oder falsche Snapshot-Anzahl
    func test_weeklyCategoryHistory_emptyTasks_returnsSnapshots() {
        let snapshots = CategoryStatsService.weeklyCategoryHistory(tasks: [], weeksBack: 6)

        XCTAssertEqual(snapshots.count, 6, "Should return exactly 6 weekly snapshots")
        for snapshot in snapshots {
            XCTAssertEqual(snapshot.total, 0, "Empty week should have total=0")
            XCTAssertEqual(snapshot.stats.count, 6, "Each snapshot should have 6 entries (5 categories + uncategorized)")
        }
    }

    /// Verhalten: Tasks in verschiedenen Wochen → korrekte Zuordnung
    /// Bricht wenn: completedAt-Filter die Wochengrenzen falsch berechnet
    func test_weeklyCategoryHistory_tasksInMultipleWeeks() {
        let _ = makeCompletedTask(title: "This week", taskType: "income", completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(title: "2 weeks ago", taskType: "maintenance", completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(title: "4 weeks ago", taskType: "learning", completedAt: dateWeeksAgo(4))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = CategoryStatsService.weeklyCategoryHistory(tasks: allTasks, weeksBack: 6)

        let currentWeek = snapshots.last!
        XCTAssertEqual(currentWeek.total, 1, "Current week should have 1 task")

        let grandTotal = snapshots.reduce(0) { $0 + $1.total }
        XCTAssertEqual(grandTotal, 3, "All 3 tasks should appear across snapshots")
    }

    /// Verhalten: Snapshots chronologisch sortiert (aelteste zuerst)
    /// Bricht wenn: Die Reihenfolge nicht stimmt
    func test_weeklyCategoryHistory_chronologicalOrder() {
        let snapshots = CategoryStatsService.weeklyCategoryHistory(tasks: [], weeksBack: 6)

        for i in 0..<(snapshots.count - 1) {
            XCTAssertLessThan(
                snapshots[i].weekStart, snapshots[i + 1].weekStart,
                "Snapshots should be in chronological order"
            )
        }
    }

    // MARK: - categoryTrends Tests

    /// Verhalten: 3 Wochen steigender Income-Anteil → .growing
    /// Bricht wenn: Trend-Erkennung fuer CategoryTrend nicht funktioniert
    func test_categoryTrends_growingCategory_detected() {
        // Woche -2: 1/3 income
        let _ = makeCompletedTask(taskType: "income", completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(taskType: "maintenance", completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(taskType: "learning", completedAt: dateWeeksAgo(2))

        // Woche -1: 2/3 income
        let _ = makeCompletedTask(taskType: "income", completedAt: dateWeeksAgo(1))
        let _ = makeCompletedTask(taskType: "income", completedAt: dateWeeksAgo(1))
        let _ = makeCompletedTask(taskType: "maintenance", completedAt: dateWeeksAgo(1))

        // Woche 0: 3/4 income
        let _ = makeCompletedTask(taskType: "income", completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(taskType: "income", completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(taskType: "income", completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(taskType: "learning", completedAt: dateWeeksAgo(0))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = CategoryStatsService.weeklyCategoryHistory(tasks: allTasks, weeksBack: 4)
        let trends = CategoryStatsService.categoryTrends(from: snapshots)

        let incomeTrend = trends.first { $0.category == .income }
        XCTAssertEqual(incomeTrend?.direction, .growing, "Income should be detected as growing")
        XCTAssertGreaterThanOrEqual(incomeTrend?.consecutiveWeeks ?? 0, 3)
    }

    /// Verhalten: Weniger als 3 Wochen Daten → alle stable
    /// Bricht wenn: Guard-Check fehlt
    func test_categoryTrends_insufficientData_allStable() {
        let _ = makeCompletedTask(taskType: "income", completedAt: dateWeeksAgo(0))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = CategoryStatsService.weeklyCategoryHistory(tasks: allTasks, weeksBack: 6)
        let trends = CategoryStatsService.categoryTrends(from: snapshots)

        for trend in trends {
            XCTAssertEqual(trend.direction, .stable, "All trends should be stable with <3 weeks of data")
        }
    }
}
