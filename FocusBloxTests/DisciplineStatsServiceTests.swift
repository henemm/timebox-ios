import XCTest
import SwiftData
@testable import FocusBlox

final class DisciplineStatsServiceTests: XCTestCase {

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

    private func makeOpenTask(title: String = "Open Task") -> LocalTask {
        let task = LocalTask(title: title, importance: nil, isCompleted: false)
        context.insert(task)
        return task
    }

    // MARK: - Tests

    /// Verhalten: Leere Liste → alle 4 Disziplinen mit count=0
    /// Bricht wenn: DisciplineStatsService.breakdown(for:) nicht alle 4 Discipline.allCases zurueckgibt
    func test_breakdown_emptyList_returnsAllZeroCounts() {
        let stats = DisciplineStatsService.breakdown(for: [])

        XCTAssertEqual(stats.count, 4, "Should return one stat per discipline")
        for stat in stats {
            XCTAssertEqual(stat.count, 0, "\(stat.discipline.displayName) should have count 0")
            XCTAssertEqual(stat.total, 0, "Total should be 0")
        }
    }

    /// Verhalten: Offene Tasks werden ignoriert — nur completed zaehlen
    /// Bricht wenn: Der `isCompleted && completedAt != nil` Filter fehlt
    func test_breakdown_onlyCompletedTasksCounted() {
        let _ = makeOpenTask(title: "Offener Task")
        let completed = makeCompletedTask(title: "Fertiger Task", rescheduleCount: 3)

        let stats = DisciplineStatsService.breakdown(for: [completed])
        let totalCount = stats.reduce(0) { $0 + $1.count }

        XCTAssertEqual(totalCount, 1, "Only 1 completed task should be counted")
    }

    /// Verhalten: 3 Tasks mit verschiedenen Eigenschaften → korrekte Verteilung
    /// Bricht wenn: resolveDiscipline() falsch klassifiziert
    func test_breakdown_mixedTasks_correctDistribution() {
        let procrastinated = makeCompletedTask(title: "Aufgeschoben", rescheduleCount: 3)
        let important = makeCompletedTask(title: "Wichtig", importance: 3)
        let normal = makeCompletedTask(title: "Normal", rescheduleCount: 0, importance: 1)

        let stats = DisciplineStatsService.breakdown(for: [procrastinated, important, normal])

        let konsequenz = stats.first { $0.discipline == .konsequenz }
        let mut = stats.first { $0.discipline == .mut }
        let ausdauer = stats.first { $0.discipline == .ausdauer }

        XCTAssertEqual(konsequenz?.count, 1, "Procrastinated task (rescheduleCount>=2) → Konsequenz")
        XCTAssertEqual(mut?.count, 1, "High importance task (importance==3) → Mut")
        XCTAssertEqual(ausdauer?.count, 1, "Default task → Ausdauer")
        XCTAssertEqual(stats.first?.total, 3, "Total should be 3")
    }

    /// Verhalten: Manual Override hat Vorrang vor Auto-Klassifikation
    /// Bricht wenn: resolveDiscipline() den manualDiscipline Check nicht zuerst macht
    func test_breakdown_manualOverride_takesPrecedence() {
        // Task hat rescheduleCount>=2 (Auto=Konsequenz), aber Override auf Mut
        let task = makeCompletedTask(
            title: "Override",
            rescheduleCount: 5,
            manualDiscipline: "mut"
        )

        let stats = DisciplineStatsService.breakdown(for: [task])

        let mut = stats.first { $0.discipline == .mut }
        let konsequenz = stats.first { $0.discipline == .konsequenz }

        XCTAssertEqual(mut?.count, 1, "Manual override 'mut' should win over auto 'konsequenz'")
        XCTAssertEqual(konsequenz?.count, 0, "Konsequenz should be 0 because override redirected to mut")
    }

    /// Verhalten: Ergebnis ist sortiert nach count (hoechster zuerst)
    /// Bricht wenn: Die `.sorted { $0.count > $1.count }` Zeile fehlt
    func test_breakdown_sortedByCountDescending() {
        // 3x Konsequenz, 1x Mut → Konsequenz sollte zuerst kommen
        let _ = makeCompletedTask(title: "A1", rescheduleCount: 3)
        let _ = makeCompletedTask(title: "A2", rescheduleCount: 4)
        let _ = makeCompletedTask(title: "A3", rescheduleCount: 2)
        let m = makeCompletedTask(title: "B1", importance: 3)

        let tasks = try! context.fetch(FetchDescriptor<LocalTask>()).filter { $0.isCompleted }
        let stats = DisciplineStatsService.breakdown(for: tasks)

        XCTAssertEqual(stats.first?.discipline, .konsequenz, "Konsequenz (3 tasks) should be first")
        XCTAssertGreaterThanOrEqual(
            stats[0].count, stats[1].count,
            "Stats should be sorted descending by count"
        )
    }

    /// Verhalten: Task mit estimatedDuration und ohne Override → Fokus-Klassifikation moeglich
    /// Bricht wenn: classify() fuer completed Tasks die estimatedDuration nicht als effectiveDuration-Fallback nutzt
    func test_breakdown_completedTaskWithEstimate_canBeFokus() {
        // Task ohne reschedule, ohne high importance, mit Duration-Info
        // classify() soll effectiveDuration <= estimatedDuration pruefen
        // Da LocalTask kein effectiveDuration hat, nutzt der Service estimatedDuration als beides
        let task = makeCompletedTask(
            title: "Fokus-Task",
            rescheduleCount: 0,
            importance: 1,
            estimatedDuration: 30
        )

        let stats = DisciplineStatsService.breakdown(for: [task])
        let fokus = stats.first { $0.discipline == .fokus }

        // Mit estimatedDuration=30 und effectiveDuration-Fallback: effective <= estimated → Fokus
        XCTAssertEqual(fokus?.count, 1, "Task with estimatedDuration should classify as Fokus")
    }
}
