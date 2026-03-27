import XCTest
@testable import FocusBlox

final class ParkdeckClassificationTests: XCTestCase {

    // MARK: - PlanItem.isInParkdeck Tests

    /// Verhalten: Task mit hohem Score (doNow-Tier) und isParked=false ist NICHT im Parkdeck
    /// Bricht wenn: PlanItem.isInParkdeck computed property fehlt oder falsche Logik
    func test_highScoreTask_notParked_isNotInParkdeck() {
        // Arrange: importance=3, urgency=urgent → Eisenhower=50, Score >= 60 → doNow
        let task = LocalTask(title: "Wichtiger Task", importance: 3)
        task.urgency = "urgent"
        let item = PlanItem(localTask: task)

        // Act & Assert
        XCTAssertFalse(item.isInParkdeck, "doNow-Task ohne isParked sollte NICHT im Parkdeck sein")
    }

    /// Verhalten: Task mit hohem Score ABER isParked=true wird ins Parkdeck gezwungen
    /// Bricht wenn: isInParkdeck ignoriert isParked Flag
    func test_highScoreTask_manuallyParked_isInParkdeck() {
        // Arrange: importance=3, urgency=urgent → Score >= 60, aber manuell geparkt
        let task = LocalTask(title: "Manuell geparkt", importance: 3)
        task.urgency = "urgent"
        task.isParked = true
        let item = PlanItem(localTask: task)

        // Act & Assert
        XCTAssertTrue(item.isInParkdeck, "Manuell geparkter Task muss im Parkdeck sein, auch bei hohem Score")
    }

    /// Verhalten: Task mit niedrigem Score (eventually-Tier) landet automatisch im Parkdeck
    /// Bricht wenn: isInParkdeck prueft nicht den priorityTier
    func test_lowScoreTask_automaticallyInParkdeck() {
        // Arrange: importance=1, urgency=not_urgent → Eisenhower=10, Score ~10-34 → eventually
        let task = LocalTask(title: "Irgendwann Task", importance: 1)
        task.urgency = "not_urgent"
        let item = PlanItem(localTask: task)

        // Act & Assert — Score should be in eventually or someday range
        let tier = item.priorityTier
        XCTAssertTrue(
            tier == .eventually || tier == .someday,
            "Task sollte eventually/someday-Tier sein, ist aber \(tier)"
        )
        XCTAssertTrue(item.isInParkdeck, "Eventually/someday-Task muss automatisch im Parkdeck sein")
    }

    /// Verhalten: Task mit Score 0 (someday, keine Attribute) ist im Parkdeck
    /// Bricht wenn: isInParkdeck behandelt someday-Tier nicht
    func test_noAttributeTask_somedayTier_isInParkdeck() {
        // Arrange: Keine Importance, keine Urgency → Score ~0-9 → someday
        let task = LocalTask(title: "Unklarer Task")
        let item = PlanItem(localTask: task)

        // Act & Assert
        XCTAssertEqual(item.priorityTier, .someday, "Task ohne Attribute sollte someday sein")
        XCTAssertTrue(item.isInParkdeck, "Someday-Task muss im Parkdeck sein")
    }

    /// Verhalten: planSoon-Task (Score 35-59) ist NICHT im Parkdeck
    /// Bricht wenn: isInParkdeck Grenze falsch (z.B. < 60 statt < 35)
    func test_planSoonTask_isNotInParkdeck() {
        // Arrange: importance=3, urgency=not_urgent → Eisenhower=38, Score ~38+ → planSoon
        let task = LocalTask(title: "Bald einplanen", importance: 3)
        task.urgency = "not_urgent"
        let item = PlanItem(localTask: task)

        // Act & Assert
        XCTAssertEqual(item.priorityTier, .planSoon, "Task sollte planSoon-Tier sein")
        XCTAssertFalse(item.isInParkdeck, "planSoon-Task ohne isParked sollte NICHT im Parkdeck sein")
    }

    /// Verhalten: Aktivierter Task (isParked=false) mit niedrigem Score bleibt trotzdem im Parkdeck
    /// Bricht wenn: isInParkdeck nur isParked prueft, nicht den Tier
    func test_lowScoreTask_explicitlyNotParked_stillInParkdeck() {
        // Arrange: Score < 35, isParked explizit false
        let task = LocalTask(title: "Niedrig priorisiert", importance: 1)
        task.urgency = "not_urgent"
        task.isParked = false
        let item = PlanItem(localTask: task)

        // Act & Assert — low score stays in parkdeck even with isParked=false
        XCTAssertTrue(item.isInParkdeck, "Niedrig priorisierter Task bleibt im Parkdeck auch wenn isParked=false")
    }
}
