import XCTest
@testable import FocusBlox

final class RecurringStackingTests: XCTestCase {

    // MARK: - Stacking Boost (TaskPriorityScoringService)

    /// Verhalten: Ein einzelner Task (stackedCount=1) bekommt keinen Boost.
    /// Bricht wenn: TaskPriorityScoringService.stackingBoost() bei count=1 nicht 0 zurueckgibt.
    func test_stackingBoost_singleInstance_returnsZero() {
        let boost = TaskPriorityScoringService.stackingBoost(instanceCount: 1)
        XCTAssertEqual(boost, 0, "Single instance should get no boost")
    }

    /// Verhalten: Zwei aufgelaufene Instanzen geben +5 Boost.
    /// Bricht wenn: stackingBoost() bei count=2 nicht 5 zurueckgibt.
    func test_stackingBoost_twoInstances_returnsFive() {
        let boost = TaskPriorityScoringService.stackingBoost(instanceCount: 2)
        XCTAssertEqual(boost, 5, "Two instances should give +5 boost")
    }

    /// Verhalten: Drei aufgelaufene Instanzen geben +10 Boost.
    /// Bricht wenn: stackingBoost() bei count=3 nicht 10 zurueckgibt.
    func test_stackingBoost_threeInstances_returnsTen() {
        let boost = TaskPriorityScoringService.stackingBoost(instanceCount: 3)
        XCTAssertEqual(boost, 10, "Three instances should give +10 boost")
    }

    /// Verhalten: Vier oder mehr aufgelaufene Instanzen werden bei +15 gecapped.
    /// Bricht wenn: stackingBoost() bei count>=4 nicht 15 zurueckgibt.
    func test_stackingBoost_fourOrMore_cappedAtFifteen() {
        XCTAssertEqual(TaskPriorityScoringService.stackingBoost(instanceCount: 4), 15)
        XCTAssertEqual(TaskPriorityScoringService.stackingBoost(instanceCount: 7), 15)
    }

    /// Verhalten: calculateScore() mit stackedInstanceCount>1 ergibt hoeheren Score.
    /// Bricht wenn: calculateScore() den stackedInstanceCount-Parameter nicht beruecksichtigt.
    func test_calculateScore_withStackingCount_includesBoost() {
        let now = Date()
        let baseScore = TaskPriorityScoringService.calculateScore(
            importance: 2,
            urgency: "not_urgent",
            dueDate: nil,
            createdAt: now,
            rescheduleCount: 0,
            estimatedDuration: 30,
            taskType: "task",
            isNextUp: false,
            now: now,
            dependentTaskCount: 0,
            stackedInstanceCount: 1
        )
        let boostedScore = TaskPriorityScoringService.calculateScore(
            importance: 2,
            urgency: "not_urgent",
            dueDate: nil,
            createdAt: now,
            rescheduleCount: 0,
            estimatedDuration: 30,
            taskType: "task",
            isNextUp: false,
            now: now,
            dependentTaskCount: 0,
            stackedInstanceCount: 3
        )
        XCTAssertEqual(boostedScore - baseScore, 10, "3 stacked instances should add +10 to score")
    }

    /// Verhalten: calculateScore() mit Stacking wird bei 100 gecapped.
    /// Bricht wenn: calculateScore() keinen min(100,...) Cap hat.
    func test_calculateScore_withStacking_cappedAt100() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let score = TaskPriorityScoringService.calculateScore(
            importance: 3,
            urgency: "urgent",
            dueDate: yesterday,
            createdAt: Calendar.current.date(byAdding: .day, value: -60, to: now)!,
            rescheduleCount: 5,
            estimatedDuration: 30,
            taskType: "task",
            isNextUp: true,
            now: now,
            dependentTaskCount: 3,
            stackedInstanceCount: 4
        )
        XCTAssertEqual(score, 100, "Score should be capped at 100 even with stacking boost")
    }

    // MARK: - PlanItem stackedInstanceCount

    /// Verhalten: PlanItem hat stackedInstanceCount Property mit Default 1.
    /// Bricht wenn: PlanItem kein stackedInstanceCount Property hat oder Default != 1.
    func test_planItem_hasStackedInstanceCount_defaultOne() {
        let item = makePlanItem(id: "a", groupID: "g1")
        XCTAssertEqual(item.stackedInstanceCount, 1, "Default stackedInstanceCount should be 1")
    }

    /// Verhalten: PlanItem.priorityScore beruecksichtigt stackedInstanceCount.
    /// Bricht wenn: PlanItem.priorityScore den stackedInstanceCount nicht an calculateScore weitergibt.
    func test_planItem_priorityScore_reflectsStackedCount() {
        var item1 = makePlanItem(id: "a", groupID: "g1")
        item1.stackedInstanceCount = 1

        var item3 = makePlanItem(id: "b", groupID: "g1")
        item3.stackedInstanceCount = 3

        XCTAssertGreaterThan(
            item3.priorityScore,
            item1.priorityScore,
            "Item with 3 stacked instances should have higher score than single instance"
        )
    }

    // MARK: - Bug 279: stackedOldestDueDate (Field-Existenz)

    /// **STRUKTUR-TEST (kein Behavior-Test):** Prueft nur dass PlanItem das Feld besitzt.
    /// **WARNUNG:** Dieser Test sagt NICHTS darueber aus ob applyRecurringStacking()
    /// das Feld korrekt setzt. Behavior wird in BacklogStackingUITests.test_seriesWithThreeInstances_showsBadgeX3
    /// und test_stackedTaskShowsSubtitle geprueft.
    /// Bricht wenn: PlanItem kein stackedOldestDueDate Property hat.
    func test_planItem_hasStackedOldestDueDate_FIELD_ONLY() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        var item = makePlanItem(id: "oldest-279", groupID: "grp-279", dueDate: twoDaysAgo)

        // Beweis dass das Feld settable ist (nicht nur Mirror-Reflection auf Optional-Default-nil)
        item.stackedOldestDueDate = twoDaysAgo
        XCTAssertEqual(item.stackedOldestDueDate, twoDaysAgo,
                       "PlanItem.stackedOldestDueDate muss settable sein und den Wert behalten")
    }

    // MARK: - Bug 279: stackedInstanceCount Setter (Field-Behavior)

    /// **STRUKTUR-TEST:** Prueft dass stackedInstanceCount settable ist und priorityScore nutzt.
    /// **WARNUNG:** Sagt NICHTS darueber aus ob applyRecurringStacking() den Counter setzt.
    /// Behavior in BacklogStackingUITests.test_seriesWithTwoInstances_showsBadgeX2.
    func test_planItem_stackedInstanceCount_isSettableAndScored() {
        var item = makePlanItem(id: "set-test", groupID: "grp-set")
        XCTAssertEqual(item.stackedInstanceCount, 1, "Default = 1")

        let scoreBefore = item.priorityScore
        item.stackedInstanceCount = 3
        let scoreAfter = item.priorityScore

        XCTAssertEqual(item.stackedInstanceCount, 3, "Setter muss greifen")
        XCTAssertGreaterThan(scoreAfter, scoreBefore,
                             "priorityScore muss stackedInstanceCount beruecksichtigen")
    }

    // MARK: - REMOVED: test_stackingExcludesNextUpTasks
    //
    // Der frueher hier stehende Test hat die Stacking-Logik IM TEST SELBST nachgebaut
    // (`for item in allItems { if let gid = ... }`) statt den echten Code aufzurufen.
    // Das ist ein Silent-Pass-Pattern: Der Test war GREEN obwohl der Bug 279 da war,
    // weil er nie applyRecurringStacking() in BacklogView.swift aufrief.
    //
    // applyRecurringStacking() ist `private` — kann aus Unit-Tests nicht aufgerufen werden.
    // Der echte Behavior-Test fuer isNextUp-Ausschluss muss als UI-Test laufen.
    // Siehe: BacklogStackingUITests.test_stackedSeries_rendersAsSingleRow

    // MARK: - Bug `bug-recurring-stack-count-badge`: RecurringStackingHelper Behavior

    /// Spec AK-2: Repraesentant der Stapel-Row ist das juengste Child (groesstes dueDate).
    func test_stacking_representativeIsYoungestChild() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!

        let groupID = "group-youngest-test"
        let oldChild = makePlanItem(id: "old", groupID: groupID, dueDate: weekAgo)
        let middleChild = makePlanItem(id: "mid", groupID: groupID, dueDate: yesterday)
        let youngChild = makePlanItem(id: "young", groupID: groupID, dueDate: today)

        let result = RecurringStackingHelper.apply(to: [oldChild, middleChild, youngChild])

        let unwrapped = try XCTUnwrap(result.first, "Stacking muss genau einen Repraesentant uebrig lassen")
        XCTAssertEqual(result.count, 1, "Drei Children einer Gruppe muessen zu 1 Repraesentant zusammengefasst werden")
        XCTAssertEqual(unwrapped.dueDate, today,
            "Repraesentant muss juengstes Child sein (dueDate=heute), nicht aeltestes")
        XCTAssertEqual(unwrapped.stackedInstanceCount, 3, "Counter muss 3 sein")
    }

    /// Spec: stackedOldestDueDate zeigt das aelteste Child-Datum (fuer Counter-Bar "seit ...").
    func test_stacking_stackedOldestDueDateIsOldest() throws {
        let today = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today)!

        let groupID = "group-oldest-test"
        let young = makePlanItem(id: "y", groupID: groupID, dueDate: today)
        let mid = makePlanItem(id: "m", groupID: groupID, dueDate: weekAgo)
        let old = makePlanItem(id: "o", groupID: groupID, dueDate: twoWeeksAgo)

        let result = RecurringStackingHelper.apply(to: [young, mid, old])

        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedOldestDueDate, twoWeeksAgo,
            "stackedOldestDueDate muss das aelteste Child-Datum sein, unabhaengig vom Repraesentant")
    }

    /// Spec AK-4: Bei nur 1 offenen Child der Serie wird KEIN Stacking angewendet.
    func test_stacking_singleChild_noStacking() throws {
        let groupID = "group-single-test"
        let single = makePlanItem(id: "only", groupID: groupID, dueDate: Date())

        let result = RecurringStackingHelper.apply(to: [single])

        let unwrapped = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1, "Single Child bleibt unveraendert")
        XCTAssertEqual(unwrapped.stackedInstanceCount, 1,
            "Bei 1 Child darf stackedInstanceCount nicht erhoeht werden.")
        XCTAssertNil(unwrapped.stackedOldestDueDate,
            "Bei 1 Child darf stackedOldestDueDate nicht gesetzt werden.")
    }

    // MARK: - Helpers

    private func makePlanItem(
        id: String? = nil,
        groupID: String?,
        dueDate: Date? = nil,
        isNextUp: Bool = false
    ) -> PlanItem {
        let task = LocalTask(
            title: "Test Task",
            importance: 2,
            dueDate: dueDate,
            estimatedDuration: 15,
            urgency: "not_urgent",
            taskType: "task",
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        task.isNextUp = isNextUp
        return PlanItem(localTask: task)
    }

    // MARK: - Pfad B Helper (Erweiterter Factory fuer Pfad-B-Tests)

    /// Erstellt einen PlanItem ohne recurrenceGroupID fuer Pfad-B-Szenarien (echte Bestandsdaten).
    private func makeSingleRecurringItem(
        recurrencePattern: String,
        recurrenceInterval: Int? = nil,
        dueDate: Date?,
        isTemplate: Bool = false,
        isCompleted: Bool = false,
        isNextUp: Bool = false
    ) -> PlanItem {
        let task = LocalTask(
            title: "Recurring Task (Pfad B)",
            importance: 2,
            isCompleted: isCompleted,
            dueDate: dueDate,
            estimatedDuration: 15,
            urgency: "not_urgent",
            taskType: "task",
            recurrencePattern: recurrencePattern,
            recurrenceInterval: recurrenceInterval,
            recurrenceGroupID: nil    // Kein GroupID — wie echte Bestandsdaten
        )
        task.isTemplate = isTemplate
        task.isNextUp = isNextUp
        return PlanItem(localTask: task)
    }

    // MARK: - Pfad B: Cycle-basierte Auflauf-Bar (Bug bug-stacking-real-data)

    /// Verhalten: Eine daily-Task ohne GroupID, ueberfaellig seit 5 Tagen, erzeugt eine Bar mit 6×.
    /// Bricht wenn: RecurringStackingHelper.apply(to:) Pfad B nicht implementiert ist.
    func testSingleDailyOverdue_5Days_showsAuflaufBarWith6x() throws {
        // Arrange
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "daily",
            dueDate: fiveDaysAgo
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1, "Pfad B darf keine Items entfernen — Item bleibt in Liste")
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 6,
            "daily, 5 Tage ueberfaellig: elapsed=5, cycle=1, missed=5+1=6")
        let oldestDue = try XCTUnwrap(representative.stackedOldestDueDate,
            "stackedOldestDueDate muss gesetzt sein damit die Bar das 'seit'-Datum anzeigen kann")
        XCTAssertEqual(
            Calendar.current.startOfDay(for: oldestDue),
            Calendar.current.startOfDay(for: fiveDaysAgo),
            "stackedOldestDueDate muss das urspruengliche dueDate der Task sein"
        )
    }

    /// Verhalten: Eine weekly-Task ohne GroupID, ueberfaellig seit 21 Tagen, erzeugt eine Bar mit 4×.
    /// Bricht wenn: Pfad B weekly-Cycle (7 Tage) falsch berechnet.
    func testSingleWeeklyOverdue_21Days_showsAuflaufBarWith4x() throws {
        // Arrange
        let twentyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -21, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "weekly",
            dueDate: twentyOneDaysAgo
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 4,
            "weekly, 21 Tage ueberfaellig: elapsed=21, cycle=7, missed=3+1=4")
    }

    /// Verhalten: Eine daily-Task mit dueDate=heute erzeugt KEINE Bar (noch nicht ueberfaellig).
    /// Bricht wenn: Pfad B auch Tasks mit dueDate=heute auswertet.
    func testSingleDailyDueToday_noBar() throws {
        // Arrange: dueDate auf Beginn des heutigen Tages setzen (startOfDay)
        let today = Calendar.current.startOfDay(for: Date())
        let item = makeSingleRecurringItem(
            recurrencePattern: "daily",
            dueDate: today
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 1,
            "dueDate=heute bedeutet 0 verpasste Cycles — keine Bar (Default 1)")
        XCTAssertNil(representative.stackedOldestDueDate,
            "Bei 0 verpassten Cycles darf kein Datum gesetzt werden")
    }

    /// Verhalten: Eine daily-Task die genau 1 Tag ueberfaellig ist, zeigt Bar mit 2×.
    /// Bricht wenn: Pfad B die +1-Formel nicht korrekt anwendet (dueDate selbst = erster verpasster Cycle).
    func testSingleDailyOneDayOverdue_showsBarWith2x() throws {
        // Arrange
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "daily",
            dueDate: yesterday
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 2,
            "daily, 1 Tag ueberfaellig: elapsed=1, cycle=1, missed=1+1=2 — Schwelle erreicht, Bar erscheint")
    }

    /// Verhalten: Eine monthly-Task ohne GroupID, ueberfaellig seit 65 Tagen, erzeugt eine Bar mit 3×.
    /// Bricht wenn: Pfad B monthly-Cycle (30 Tage Pauschale) falsch berechnet.
    func testSingleMonthlyOverdue_65Days_showsBarWith3x() throws {
        // Arrange
        let sixtyFiveDaysAgo = Calendar.current.date(byAdding: .day, value: -65, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "monthly",
            dueDate: sixtyFiveDaysAgo
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 3,
            "monthly, 65 Tage ueberfaellig: elapsed=65, cycle=30 (Pauschale), missed=2+1=3")
    }

    /// Verhalten: Eine nicht-wiederkehrende Task (none) bekommt KEINE Bar, auch wenn weit ueberfaellig.
    /// Bricht wenn: Pfad B auch Tasks mit recurrencePattern='none' auswertet.
    func testNonRecurringOverdue_noBar() throws {
        // Arrange
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "none",
            dueDate: thirtyDaysAgo
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 1,
            "recurrencePattern='none' — Pfad B darf nicht greifen, auch wenn Task weit ueberfaellig ist")
        XCTAssertNil(representative.stackedOldestDueDate)
    }

    /// Verhalten: Ein Template (isTemplate=true) bekommt KEINE Bar, auch wenn recurring und ueberfaellig.
    /// Bricht wenn: Pfad B isTemplate-Guard fehlt.
    func testTemplateOverdue_noBar() throws {
        // Arrange
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "daily",
            dueDate: tenDaysAgo,
            isTemplate: true
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 1,
            "isTemplate=true — Pfad B darf nicht greifen, Templates sind unsichtbar")
        XCTAssertNil(representative.stackedOldestDueDate)
    }

    /// Verhalten: Eine abgeschlossene Task (isCompleted=true) bekommt KEINE Bar.
    /// Bricht wenn: Pfad B isCompleted-Guard fehlt.
    func testCompletedOverdue_noBar() throws {
        // Arrange
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "daily",
            dueDate: tenDaysAgo,
            isCompleted: true
        )

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 1,
            "isCompleted=true — Pfad B darf nicht greifen")
        XCTAssertNil(representative.stackedOldestDueDate)
    }

    /// Verhalten: Wenn Pfad A (GroupID-Gruppierung) 2 Children ergibt und Pfad B 11 ergeben wuerde,
    /// wird das Maximum genommen: 11.
    /// Bricht wenn: Pfad B bei Pfad-A-Repraesentant nicht mit max() kombiniert wird.
    func testMixedPathAandB_takesMaxCount() throws {
        // Arrange: 2 Items mit gleicher GroupID, daily, dueDate vor 10 Tagen
        // Pfad A: indices.count = 2
        // Pfad B: elapsed=10, cycle=1, missed=11 → max(2, 11) = 11
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let groupID = "group-mixed-ab"

        let task1 = LocalTask(
            title: "Item A",
            importance: 2,
            dueDate: tenDaysAgo,
            estimatedDuration: 15,
            urgency: "not_urgent",
            taskType: "task",
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        let task2 = LocalTask(
            title: "Item B",
            importance: 2,
            dueDate: tenDaysAgo,
            estimatedDuration: 15,
            urgency: "not_urgent",
            taskType: "task",
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        let item1 = PlanItem(localTask: task1)
        let item2 = PlanItem(localTask: task2)

        // Act
        let result = RecurringStackingHelper.apply(to: [item1, item2])

        // Assert
        XCTAssertEqual(result.count, 1,
            "Pfad A muss 2 Children zu 1 Repraesentant zusammenfassen")
        let representative = try XCTUnwrap(result.first)
        XCTAssertEqual(representative.stackedInstanceCount, 11,
            "max(Pfad-A=2, Pfad-B=11) = 11 — Pfad B gewinnt, weil er die Realitaet besser abbildet")
    }

    /// Hennings Real-Daten-Szenario: Task wie er auf Hennings iPhone existiert —
    /// keine GroupID, aber recurring und ueberfaellig seit 3 Tagen.
    /// Bricht wenn: Pfad B nicht greift bei fehlendem recurrenceGroupID (Hauptszenario des Bugs).
    ///
    /// "Henning's Real-Data Scenario" — dieser Test ist symbolisch wichtig:
    /// Alle bisherigen 5 Bug-279-Anlaeufe haben DIESES Szenario nicht abgedeckt.
    func testRealDataScenario_noGroupIDButRecurringAndOverdue_showsBar() throws {
        // Arrange: Task exakt wie er bei echten Bestandsdaten / Reminders-Import vorkommt
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let item = makeSingleRecurringItem(
            recurrencePattern: "daily",
            recurrenceInterval: nil,    // kein custom-Interval
            dueDate: threeDaysAgo,
            isTemplate: false,
            isCompleted: false,
            isNextUp: false
        )
        // Explizit beweisen dass kein GroupID vorhanden ist (Pfad A wuerde nicht greifen)
        XCTAssertNil(item.recurrenceGroupID,
            "Vorbedingung: Echte Bestandsdaten haben keine recurrenceGroupID")

        // Act
        let result = RecurringStackingHelper.apply(to: [item])

        // Assert: Bar erscheint
        XCTAssertEqual(result.count, 1)
        let representative = try XCTUnwrap(result.first)
        XCTAssertGreaterThanOrEqual(representative.stackedInstanceCount, 2,
            "Pfad B muss greifen: daily, 3 Tage ueberfaellig → stackedInstanceCount >= 2 (Bar wird gerendert)")
        XCTAssertNotNil(representative.stackedOldestDueDate,
            "stackedOldestDueDate muss gesetzt sein — Bar zeigt 'seit [Datum]'")
        // Exakter Wert: elapsed=3, cycle=1, missed=3+1=4
        XCTAssertEqual(representative.stackedInstanceCount, 4,
            "daily, 3 Tage ueberfaellig: missed=3+1=4")
    }
}
