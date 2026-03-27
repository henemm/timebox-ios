import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for WidgetDataPublisher — verifies that task aggregation
/// writes correct values to App Group UserDefaults.
@MainActor
final class WidgetDataPublisherTests: XCTestCase {

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

    // MARK: - NextUp Count

    /// Verhalten: publish() zaehlt nur Tasks die isNextUp=true UND !isCompleted sind.
    /// Bricht wenn: WidgetDataPublisher Filter-Logik fuer nextUp falsch ist
    ///   (z.B. isCompleted nicht geprueft oder isNextUp ignoriert).
    func test_publish_countsOnlyIncompleteNextUpTasks() throws {
        // Arrange: 3 nextUp (1 completed), 1 not nextUp
        let t1 = LocalTask(title: "NextUp 1", importance: 1)
        t1.isNextUp = true
        let t2 = LocalTask(title: "NextUp 2", importance: 1)
        t2.isNextUp = true
        let t3 = LocalTask(title: "NextUp completed", importance: 1, isCompleted: true)
        t3.isNextUp = true
        t3.completedAt = Date()
        let t4 = LocalTask(title: "Not NextUp", importance: 1)

        context.insert(t1)
        context.insert(t2)
        context.insert(t3)
        context.insert(t4)
        try context.save()

        // Act
        WidgetDataPublisher.publish(context: context)

        // Assert
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        XCTAssertEqual(defaults?.integer(forKey: "widget_nextUpCount"), 2,
                       "Should count only incomplete NextUp tasks")
    }

    // MARK: - Completed Today Count

    /// Verhalten: publish() zaehlt nur Tasks mit completedAt >= startOfDay (heute).
    /// Bricht wenn: Datums-Filter in publish() falsch ist (z.B. alle completed zaehlt
    ///   statt nur heute, oder startOfDay falsch berechnet).
    func test_publish_countsOnlyTasksCompletedToday() throws {
        // Arrange: 1 completed today, 1 completed yesterday
        let today = LocalTask(title: "Done today", importance: 1, isCompleted: true)
        today.completedAt = Date()

        let yesterday = LocalTask(title: "Done yesterday", importance: 1, isCompleted: true)
        yesterday.completedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        context.insert(today)
        context.insert(yesterday)
        try context.save()

        // Act
        WidgetDataPublisher.publish(context: context)

        // Assert
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        XCTAssertEqual(defaults?.integer(forKey: "widget_completedTodayCount"), 1,
                       "Should count only tasks completed today")
    }

    // MARK: - Total Today Count

    /// Verhalten: totalTodayCount = nextUpCount + completedTodayCount.
    /// Bricht wenn: Berechnung in publish() die Summe falsch bildet.
    func test_publish_totalTodayIsSumOfNextUpAndCompletedToday() throws {
        // Arrange: 2 nextUp incomplete + 1 completed today
        let t1 = LocalTask(title: "NextUp A", importance: 1)
        t1.isNextUp = true
        let t2 = LocalTask(title: "NextUp B", importance: 1)
        t2.isNextUp = true
        let t3 = LocalTask(title: "Done", importance: 1, isCompleted: true)
        t3.completedAt = Date()

        context.insert(t1)
        context.insert(t2)
        context.insert(t3)
        try context.save()

        // Act
        WidgetDataPublisher.publish(context: context)

        // Assert
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        XCTAssertEqual(defaults?.integer(forKey: "widget_totalTodayCount"), 3,
                       "Total should be nextUp(2) + completedToday(1) = 3")
    }

    // MARK: - Oldest Waiting Days

    /// Verhalten: publish() berechnet die maximale Wartezeit in Tagen
    ///   unter allen incomplete NextUp Tasks (basierend auf createdAt).
    /// Bricht wenn: oldestWaitingDays-Berechnung fehlt oder .max() falsch ist.
    func test_publish_calculatesOldestWaitingDaysFromCreatedAt() throws {
        // Arrange: NextUp task created 5 days ago, another 2 days ago
        let old = LocalTask(title: "Old Task", importance: 1,
                           createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
        old.isNextUp = true

        let recent = LocalTask(title: "Recent Task", importance: 1,
                              createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
        recent.isNextUp = true

        context.insert(old)
        context.insert(recent)
        try context.save()

        // Act
        WidgetDataPublisher.publish(context: context)

        // Assert
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        XCTAssertEqual(defaults?.integer(forKey: "widget_oldestWaitingDays"), 5,
                       "Should report the oldest task's age in days")
    }

    // MARK: - Empty State

    /// Verhalten: Bei 0 Tasks sind alle Counts 0.
    /// Bricht wenn: publish() bei leerer DB crasht oder falsche Defaults schreibt.
    func test_publish_writesZerosWhenNoTasks() throws {
        // Act — no tasks inserted
        WidgetDataPublisher.publish(context: context)

        // Assert
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        XCTAssertEqual(defaults?.integer(forKey: "widget_nextUpCount"), 0)
        XCTAssertEqual(defaults?.integer(forKey: "widget_completedTodayCount"), 0)
        XCTAssertEqual(defaults?.integer(forKey: "widget_totalTodayCount"), 0)
        XCTAssertEqual(defaults?.integer(forKey: "widget_oldestWaitingDays"), 0)
    }

    // MARK: - Last Updated Timestamp

    /// Verhalten: publish() schreibt einen aktuellen Timestamp in widget_lastUpdated.
    /// Bricht wenn: widget_lastUpdated Key nicht geschrieben wird.
    func test_publish_setsLastUpdatedTimestamp() throws {
        let before = Date().timeIntervalSince1970

        // Act
        WidgetDataPublisher.publish(context: context)

        // Assert
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        let lastUpdated = defaults?.double(forKey: "widget_lastUpdated") ?? 0
        XCTAssertGreaterThanOrEqual(lastUpdated, before,
                                    "widget_lastUpdated should be >= time before publish()")
    }
}
