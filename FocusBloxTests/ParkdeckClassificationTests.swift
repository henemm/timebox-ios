import XCTest
@testable import FocusBlox

/// RW 2.4b: isInParkdeck basiert NUR auf isParked (manuell), NICHT auf Score-Tier.
/// Score-Tiers bestimmen die Sektion (Dringend/Bald/Später), nicht ob ein Task geparkt ist.
final class ParkdeckClassificationTests: XCTestCase {

    // MARK: - isInParkdeck nur noch isParked-basiert

    /// Verhalten: Task mit hohem Score und isParked=false ist NICHT geparkt
    /// Bricht wenn: isInParkdeck noch Score-Tiers prüft
    func test_highScoreTask_notParked_isNotInParkdeck() {
        let task = LocalTask(title: "Wichtiger Task", importance: 3)
        task.urgency = "urgent"
        let item = PlanItem(localTask: task)

        XCTAssertFalse(item.isInParkdeck, "Task ohne isParked=true darf NICHT geparkt sein")
    }

    /// Verhalten: Task mit isParked=true ist geparkt, unabhängig vom Score
    /// Bricht wenn: isInParkdeck ignoriert isParked Flag
    func test_highScoreTask_manuallyParked_isInParkdeck() {
        let task = LocalTask(title: "Manuell geparkt", importance: 3)
        task.urgency = "urgent"
        task.isParked = true
        let item = PlanItem(localTask: task)

        XCTAssertTrue(item.isInParkdeck, "Manuell geparkter Task muss geparkt sein")
    }

    /// RW 2.4b: Low-Score-Task OHNE isParked ist NICHT geparkt — er landet in "Später"
    /// Bricht wenn: isInParkdeck noch priorityTier == .eventually/.someday prüft (alte Logik)
    func test_lowScoreTask_notParked_isNotInParkdeck() {
        let task = LocalTask(title: "Irgendwann Task", importance: 1)
        task.urgency = "not_urgent"
        let item = PlanItem(localTask: task)

        let tier = item.priorityTier
        XCTAssertTrue(
            tier == .eventually || tier == .someday,
            "Task sollte eventually/someday-Tier sein, ist aber \(tier)"
        )
        // NEU: Low-Score allein macht NICHT geparkt
        XCTAssertFalse(item.isInParkdeck, "Eventually/someday-Task ohne isParked darf NICHT geparkt sein")
    }

    /// RW 2.4b: Task ohne Attribute (someday) ist NICHT geparkt — er landet in "Später"
    /// Bricht wenn: isInParkdeck noch Score-basiert filtert
    func test_noAttributeTask_somedayTier_isNotInParkdeck() {
        let task = LocalTask(title: "Unklarer Task")
        let item = PlanItem(localTask: task)

        XCTAssertEqual(item.priorityTier, .someday, "Task ohne Attribute sollte someday sein")
        // NEU: Someday allein macht NICHT geparkt
        XCTAssertFalse(item.isInParkdeck, "Someday-Task ohne isParked darf NICHT geparkt sein")
    }

    /// Verhalten: planSoon-Task ohne isParked ist NICHT geparkt
    /// Bricht wenn: isInParkdeck Logik fehlerhaft
    func test_planSoonTask_isNotInParkdeck() {
        let task = LocalTask(title: "Bald einplanen", importance: 3)
        task.urgency = "not_urgent"
        let item = PlanItem(localTask: task)

        XCTAssertEqual(item.priorityTier, .planSoon, "Task sollte planSoon-Tier sein")
        XCTAssertFalse(item.isInParkdeck, "planSoon-Task ohne isParked darf NICHT geparkt sein")
    }

    /// RW 2.4b: Low-Score-Task mit isParked=false ist NICHT geparkt
    /// Bricht wenn: isInParkdeck noch Score-Tier als Kriterium nutzt
    func test_lowScoreTask_explicitlyNotParked_isNotInParkdeck() {
        let task = LocalTask(title: "Niedrig priorisiert", importance: 1)
        task.urgency = "not_urgent"
        task.isParked = false
        let item = PlanItem(localTask: task)

        // NEU: isParked=false + niedriger Score = NICHT geparkt
        XCTAssertFalse(item.isInParkdeck, "Task mit isParked=false darf NICHT geparkt sein, auch bei niedrigem Score")
    }
}
