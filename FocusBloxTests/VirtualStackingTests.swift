import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests fuer "Virtuelles Stacking fuer wiederkehrende Tasks".
/// EXPECTED TO FAIL (TDD RED): Implementation hat sich noch nicht geaendert.
///
/// Test 1: repair erzeugt max 1 Instanz (aktuell: bis zu 30)
/// Test 2: Pfad B weekly 3 Wochen ueberfaellig (Regression)
/// Test 3: Pfad B daily 5 Tage ueberfaellig (Regression)
/// Test 4: dueDate = heute -> kein Stacking
/// Test 5: Pfad A deaktiviert -- 3 Items bleiben 3 Items (aktuell: Pfad A kollabiert zu 1)
/// Test 6: consolidateMultipleInstances -- Migration (Funktion existiert noch nicht)
/// Test 7: consolidateMultipleInstances -- keine Aenderung bei 1 Instanz
final class VirtualStackingTests: XCTestCase {

    // MARK: - Test 1: Repair erzeugt maximal 1 Instanz

    /// Weekly Task, letzte Completion vor 10 Wochen, Template existiert.
    /// repairOrphanedRecurringSeries() soll nur 1 neue offene Instanz erzeugen.
    /// BRICHT WEIL: Aktuell erzeugt repair bis zu 30 Instanzen (while created < 30).
    @MainActor
    func test_repair_createsMaxOneInstance() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let groupID = "virtual-stacking-repair-test"

        // Template (Serie aktiv)
        let template = LocalTask(
            title: "Weekly Review",
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        template.isTemplate = true
        context.insert(template)

        // Completed Task -- dueDate vor 10 Wochen
        let tenWeeksAgo = Calendar.current.date(byAdding: .day, value: -70, to: Date())!
        let completed = LocalTask(
            title: "Weekly Review",
            dueDate: tenWeeksAgo,
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        completed.isCompleted = true
        completed.completedAt = tenWeeksAgo
        context.insert(completed)
        try context.save()

        // Act
        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        // Assert: Genau 1 neue offene Instanz (nicht 10!)
        let openInstances = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted && !$0.isTemplate }
        ))
        XCTAssertEqual(repaired, 1,
            "Repair soll genau 1 Instanz erzeugen, nicht \(repaired). Virtuelles Stacking berechnet den Rest.")
        XCTAssertEqual(openInstances.count, 1,
            "Es darf nur 1 offene Instanz existieren, gefunden: \(openInstances.count)")
    }

    // MARK: - Test 2: Virtuelle Badge -- weekly 3 Wochen ueberfaellig

    /// 1 PlanItem mit recurrencePattern "weekly", dueDate vor 3 Wochen.
    /// Pfad B berechnet stackedInstanceCount == 4 (3 verpasste Cycles + 1).
    /// Regression-Test -- Pfad B existiert bereits und soll unveraendert bleiben.
    func test_virtualBadge_weekly3WeeksOverdue() throws {
        let threeWeeksAgo = Calendar.current.date(byAdding: .day, value: -21, to: Date())!
        let item = makePlanItem(
            recurrencePattern: "weekly",
            dueDate: threeWeeksAgo
        )

        let result = RecurringStackingHelper.apply(to: [item])

        let representative = try XCTUnwrap(result.first)
        // elapsed=21, cycle=7, missed=21/7+1=4
        XCTAssertEqual(representative.stackedInstanceCount, 4,
            "weekly, 3 Wochen ueberfaellig: elapsed=21, cycle=7, missed=3+1=4")
    }

    // MARK: - Test 3: Virtuelle Badge -- daily 5 Tage ueberfaellig

    /// 1 PlanItem mit recurrencePattern "daily", dueDate vor 5 Tagen.
    /// Pfad B berechnet stackedInstanceCount == 6 (5 verpasste Cycles + 1).
    func test_virtualBadge_daily5DaysOverdue() throws {
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let item = makePlanItem(
            recurrencePattern: "daily",
            dueDate: fiveDaysAgo
        )

        let result = RecurringStackingHelper.apply(to: [item])

        let representative = try XCTUnwrap(result.first)
        // elapsed=5, cycle=1, missed=5/1+1=6
        XCTAssertEqual(representative.stackedInstanceCount, 6,
            "daily, 5 Tage ueberfaellig: elapsed=5, cycle=1, missed=5+1=6")
    }

    // MARK: - Test 4: Kein Stacking fuer Tasks die heute faellig sind

    /// dueDate = startOfDay(today) -> stackedInstanceCount bleibt 1.
    func test_noStacking_forTaskDueToday() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let item = makePlanItem(
            recurrencePattern: "daily",
            dueDate: today
        )

        let result = RecurringStackingHelper.apply(to: [item])

        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 1,
            "dueDate = heute -> kein Stacking, stackedInstanceCount bleibt 1")
    }

    // MARK: - Test 5: Pfad A deaktiviert -- keine echte Gruppierung mehr

    /// 3 PlanItems mit gleicher recurrenceGroupID, verschiedene dueDates (alle Vergangenheit).
    /// Nach Pfad-A-Deaktivierung: Output hat immer noch 3 Items.
    /// BRICHT WEIL: Aktuell entfernt Pfad A 2 der 3 Items und setzt stackedInstanceCount=3.
    func test_pathADisabled_noGroupCollapsing() throws {
        let groupID = "path-a-disabled-test"
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let threeWeeksAgo = Calendar.current.date(byAdding: .day, value: -21, to: Date())!

        let item1 = makePlanItem(recurrencePattern: "weekly", dueDate: threeWeeksAgo, groupID: groupID)
        let item2 = makePlanItem(recurrencePattern: "weekly", dueDate: twoWeeksAgo, groupID: groupID)
        let item3 = makePlanItem(recurrencePattern: "weekly", dueDate: oneWeekAgo, groupID: groupID)

        let result = RecurringStackingHelper.apply(to: [item1, item2, item3])

        XCTAssertEqual(result.count, 3,
            "Pfad A deaktiviert: Alle 3 Items muessen im Output bleiben, gefunden: \(result.count). " +
            "Gruppierung nach recurrenceGroupID soll nicht mehr stattfinden.")
    }

    // MARK: - Test 6: Migration -- consolidateMultipleInstances

    /// 3 offene Instanzen mit gleicher recurrenceGroupID + 1 Template.
    /// consolidateMultipleInstances loescht 2 der 3 Instanzen (behaelt aelteste).
    /// BRICHT WEIL: Funktion existiert noch nicht — XCTFail als Platzhalter bis Stub existiert.
    @MainActor
    func test_consolidateMultipleInstances_keepsOldestOnly() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let groupID = "consolidation-test"

        // Template
        let template = LocalTask(
            title: "Consolidation Task",
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        template.isTemplate = true
        context.insert(template)

        // 3 offene Instanzen mit verschiedenen dueDates
        let threeWeeksAgo = Calendar.current.date(byAdding: .day, value: -21, to: Date())!
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        let instance1 = LocalTask(
            title: "Consolidation Task",
            dueDate: threeWeeksAgo,
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        let instance2 = LocalTask(
            title: "Consolidation Task",
            dueDate: twoWeeksAgo,
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        let instance3 = LocalTask(
            title: "Consolidation Task",
            dueDate: oneWeekAgo,
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )

        context.insert(instance1)
        context.insert(instance2)
        context.insert(instance3)
        try context.save()

        // Act
        let deleted = RecurrenceService.consolidateMultipleInstances(in: context)
        XCTAssertEqual(deleted, 2, "2 ueberschuessige Instanzen muessen geloescht werden")

        // Assert: Nur 1 offene Instanz uebrig (die mit fruehestem dueDate)
        let openInstances = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted && !$0.isTemplate }
        ))
        XCTAssertEqual(openInstances.count, 1,
            "Nach Konsolidierung darf nur 1 offene Instanz existieren, gefunden: \(openInstances.count)")

        let survivor = try XCTUnwrap(openInstances.first)
        XCTAssertEqual(survivor.dueDate, threeWeeksAgo,
            "Die ueberlebende Instanz muss die mit dem fruehesten dueDate sein")

        // Template darf NICHT geloescht werden
        let templates = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isTemplate }
        ))
        XCTAssertEqual(templates.count, 1,
            "Template darf durch Konsolidierung nicht geloescht werden")
    }

    // MARK: - Test 7: Migration -- keine Aenderung bei nur 1 Instanz

    /// 1 offene Instanz mit recurrenceGroupID -> consolidateMultipleInstances aendert nichts.
    /// BRICHT WEIL: Funktion existiert noch nicht.
    @MainActor
    func test_consolidateMultipleInstances_noChangeForSingleInstance() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let groupID = "single-instance-test"

        let instance = LocalTask(
            title: "Single Instance",
            dueDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        context.insert(instance)
        try context.save()

        let instanceID = instance.id

        // Act
        let deleted = RecurrenceService.consolidateMultipleInstances(in: context)
        XCTAssertEqual(deleted, 0, "Einzelne Instanz darf nicht geloescht werden")

        // Assert: Instanz bleibt unveraendert
        let openInstances = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted && !$0.isTemplate }
        ))
        XCTAssertEqual(openInstances.count, 1,
            "Einzelne Instanz darf nicht geloescht werden")
        XCTAssertEqual(openInstances.first?.id, instanceID,
            "Instanz-ID muss identisch bleiben")
    }

    // MARK: - Helpers

    private func makePlanItem(
        recurrencePattern: String,
        dueDate: Date?,
        groupID: String? = nil
    ) -> PlanItem {
        let task = LocalTask(
            title: "Test Task",
            importance: 2,
            dueDate: dueDate,
            estimatedDuration: 15,
            urgency: "not_urgent",
            taskType: "task",
            recurrencePattern: recurrencePattern,
            recurrenceGroupID: groupID
        )
        return PlanItem(localTask: task)
    }
}
