import XCTest
import SwiftData
@testable import FocusBlox

final class DisciplineTrendServiceTests: XCTestCase {

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
        rescheduleCount: Int = 0,
        importance: Int? = nil,
        estimatedDuration: Int? = nil,
        manualDiscipline: String? = nil,
        completedAt: Date = Date()
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: importance, isCompleted: true, estimatedDuration: estimatedDuration)
        task.rescheduleCount = rescheduleCount
        task.completedAt = completedAt
        task.manualDiscipline = manualDiscipline
        context.insert(task)
        return task
    }

    /// Hilfsfunktion: Datum N Wochen in der Vergangenheit (Mitte der Woche)
    private func dateWeeksAgo(_ weeksAgo: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date())!
    }

    // MARK: - weeklyHistory Tests

    /// Verhalten: Keine Tasks → 6 Snapshots, alle mit count=0
    /// Bricht wenn: weeklyHistory() nicht fuer jede Woche einen Snapshot erzeugt
    func test_weeklyHistory_emptyTasks_returnsSnapshotsWithZeroCounts() {
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: [], weeksBack: 6)

        XCTAssertEqual(snapshots.count, 6, "Should return exactly 6 weekly snapshots")
        for snapshot in snapshots {
            XCTAssertEqual(snapshot.total, 0, "Empty week should have total=0")
            XCTAssertEqual(snapshot.stats.count, 4, "Each snapshot should have 4 disciplines")
        }
    }

    /// Verhalten: Tasks in verschiedenen Wochen → korrekte Wochen-Zuordnung
    /// Bricht wenn: Die completedAt-Filterung in weeklyHistory() die Wochengrenzen falsch berechnet
    func test_weeklyHistory_tasksInMultipleWeeks_correctDistribution() {
        // Tasks in 3 verschiedenen Wochen: 0 (diese Woche), 2, 4 Wochen zurueck
        let _ = makeCompletedTask(title: "This week", rescheduleCount: 3, completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(title: "2 weeks ago", importance: 3, completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(title: "4 weeks ago", completedAt: dateWeeksAgo(4))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: allTasks, weeksBack: 6)

        // Aktuelle Woche (letzter Snapshot) sollte 1 Task haben
        let currentWeek = snapshots.last!
        XCTAssertEqual(currentWeek.total, 1, "Current week should have 1 completed task")

        // Gesamtzahl ueber alle Snapshots
        let grandTotal = snapshots.reduce(0) { $0 + $1.total }
        XCTAssertEqual(grandTotal, 3, "All 3 tasks should appear across snapshots")
    }

    /// Verhalten: weeksBack Parameter steuert die Anzahl der Snapshots
    /// Bricht wenn: Die for-Schleife den weeksBack Parameter ignoriert
    func test_weeklyHistory_respectsWeeksBackParameter() {
        let snapshots4 = DisciplineStatsService.weeklyHistory(tasks: [], weeksBack: 4)
        let snapshots8 = DisciplineStatsService.weeklyHistory(tasks: [], weeksBack: 8)

        XCTAssertEqual(snapshots4.count, 4, "weeksBack=4 should return 4 snapshots")
        XCTAssertEqual(snapshots8.count, 8, "weeksBack=8 should return 8 snapshots")
    }

    /// Verhalten: Snapshots sind chronologisch sortiert (aelteste zuerst)
    /// Bricht wenn: Die reversed()-Reihenfolge in der for-Schleife fehlt
    func test_weeklyHistory_snapshotsInChronologicalOrder() {
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: [], weeksBack: 6)

        for i in 0..<(snapshots.count - 1) {
            XCTAssertLessThan(
                snapshots[i].weekStart, snapshots[i + 1].weekStart,
                "Snapshots should be in chronological order (oldest first)"
            )
        }
    }

    // MARK: - trends Tests

    /// Verhalten: 3 Wochen mit steigendem Konsequenz-Anteil → .growing erkannt
    /// Bricht wenn: Die Trend-Erkennungslogik den consecutiveWeeks-Zaehler falsch berechnet
    func test_trends_growingDiscipline_detected() {
        // Erstelle Tasks: Konsequenz-Anteil steigt ueber 3 Wochen
        // Woche -2: 1/3 Konsequenz (33%)
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(importance: 3, completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(completedAt: dateWeeksAgo(2))

        // Woche -1: 2/3 Konsequenz (67%)
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(1))
        let _ = makeCompletedTask(rescheduleCount: 4, completedAt: dateWeeksAgo(1))
        let _ = makeCompletedTask(completedAt: dateWeeksAgo(1))

        // Woche 0: 3/4 Konsequenz (75%)
        let _ = makeCompletedTask(rescheduleCount: 2, completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(rescheduleCount: 5, completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(completedAt: dateWeeksAgo(0))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: allTasks, weeksBack: 4)
        let trends = DisciplineStatsService.trends(from: snapshots)

        let konsequenzTrend = trends.first { $0.discipline == .konsequenz }
        XCTAssertEqual(konsequenzTrend?.direction, .growing, "Konsequenz should be detected as growing")
        XCTAssertGreaterThanOrEqual(konsequenzTrend?.consecutiveWeeks ?? 0, 3, "Should detect at least 3 consecutive growing weeks")
    }

    /// Verhalten: 3 Wochen mit sinkendem Anteil → .declining erkannt
    /// Bricht wenn: Der decliningCount-Zaehler in trends() fehlt oder falsch zaehlt
    func test_trends_decliningDiscipline_detected() {
        // Woche -2: 3/4 Konsequenz (75%)
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(rescheduleCount: 4, completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(rescheduleCount: 2, completedAt: dateWeeksAgo(2))
        let _ = makeCompletedTask(completedAt: dateWeeksAgo(2))

        // Woche -1: 2/4 Konsequenz (50%)
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(1))
        let _ = makeCompletedTask(rescheduleCount: 4, completedAt: dateWeeksAgo(1))
        let _ = makeCompletedTask(importance: 3, completedAt: dateWeeksAgo(1))
        let _ = makeCompletedTask(completedAt: dateWeeksAgo(1))

        // Woche 0: 1/4 Konsequenz (25%)
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(importance: 3, completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(importance: 3, completedAt: dateWeeksAgo(0))
        let _ = makeCompletedTask(completedAt: dateWeeksAgo(0))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: allTasks, weeksBack: 4)
        let trends = DisciplineStatsService.trends(from: snapshots)

        let konsequenzTrend = trends.first { $0.discipline == .konsequenz }
        XCTAssertEqual(konsequenzTrend?.direction, .declining, "Konsequenz should be detected as declining")
    }

    /// Verhalten: Gleichbleibender Anteil → .stable
    /// Bricht wenn: trends() faelschlicherweise Trends bei gleichen Werten erkennt
    func test_trends_stableDiscipline_noTrend() {
        // 3 Wochen mit jeweils 1/2 Konsequenz (50%)
        for weeksAgo in 0...2 {
            let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(weeksAgo))
            let _ = makeCompletedTask(completedAt: dateWeeksAgo(weeksAgo))
        }

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: allTasks, weeksBack: 4)
        let trends = DisciplineStatsService.trends(from: snapshots)

        let konsequenzTrend = trends.first { $0.discipline == .konsequenz }
        XCTAssertEqual(konsequenzTrend?.direction, .stable, "Consistent 50% should be stable, not growing/declining")
    }

    /// Verhalten: Wochen ohne Tasks zaehlen nicht als Wachstum/Abnahme
    /// Bricht wenn: trends() leere Wochen (total=0) nicht herausfiltert vor der Trend-Berechnung
    func test_trends_emptyWeeksIgnored() {
        // Nur 2 Wochen mit Daten (nicht genug fuer Trend), dazwischen leere Woche
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(3))
        // Woche -2: leer
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(1))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: allTasks, weeksBack: 5)
        let trends = DisciplineStatsService.trends(from: snapshots)

        // Nur 2 Wochen mit Daten → kein Trend moeglich (braucht mind. 3)
        for trend in trends {
            XCTAssertEqual(trend.direction, .stable, "\(trend.discipline.displayName) should be stable with <3 data weeks")
        }
    }

    /// Verhalten: Weniger als 3 Wochen mit Daten → alle Trends stable
    /// Bricht wenn: Der guard withData.count >= 3 Check in trends() fehlt
    func test_trends_lessThanThreeWeeksData_allStable() {
        // Nur 1 Woche mit Daten
        let _ = makeCompletedTask(rescheduleCount: 3, completedAt: dateWeeksAgo(0))

        let allTasks = try! context.fetch(FetchDescriptor<LocalTask>())
        let snapshots = DisciplineStatsService.weeklyHistory(tasks: allTasks, weeksBack: 6)
        let trends = DisciplineStatsService.trends(from: snapshots)

        XCTAssertEqual(trends.count, 4, "Should return trend for each discipline")
        for trend in trends {
            XCTAssertEqual(trend.direction, .stable, "All trends should be stable with only 1 week of data")
            XCTAssertEqual(trend.consecutiveWeeks, 0, "consecutiveWeeks should be 0")
        }
    }
}
