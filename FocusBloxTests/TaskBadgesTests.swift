import XCTest
@testable import FocusBlox

/// Tests fuer Shared Badge Components (TD-02 Paket 1)
/// Diese Tests referenzieren ImportanceBadge, UrgencyBadge etc.
/// die noch NICHT existieren → Compile-Fehler → TDD RED
final class TaskBadgesTests: XCTestCase {

    // MARK: - ImportanceBadge Cycling Logic

    /// Verhalten: nil-Importance cycled zu 1
    /// Bricht wenn: ImportanceBadge.nextImportance() Logik geaendert
    func test_importanceCycling_nilStartsAt1() {
        XCTAssertEqual(ImportanceBadge.nextImportance(current: nil), 1)
    }

    /// Verhalten: Importance 1 cycled zu 2
    /// Bricht wenn: Cycling-Reihenfolge geaendert
    func test_importanceCycling_1To2() {
        XCTAssertEqual(ImportanceBadge.nextImportance(current: 1), 2)
    }

    /// Verhalten: Importance 2 cycled zu 3
    /// Bricht wenn: Cycling-Reihenfolge geaendert
    func test_importanceCycling_2To3() {
        XCTAssertEqual(ImportanceBadge.nextImportance(current: 2), 3)
    }

    /// Verhalten: Importance 3 wrapt zurueck zu 1
    /// Bricht wenn: Wrap-Around-Grenze geaendert
    func test_importanceCycling_3WrapsTo1() {
        XCTAssertEqual(ImportanceBadge.nextImportance(current: 3), 1)
    }

    /// Verhalten: Importance 0 (ungesetzt) cycled zu 1
    /// Bricht wenn: 0-Handling geaendert
    func test_importanceCycling_0To1() {
        XCTAssertEqual(ImportanceBadge.nextImportance(current: 0), 1)
    }

    // MARK: - UrgencyBadge Toggle Logic

    /// Verhalten: nil-Urgency toggled zu "not_urgent"
    /// Bricht wenn: UrgencyBadge.nextUrgency() Logik geaendert
    func test_urgencyToggle_nilToNotUrgent() {
        XCTAssertEqual(UrgencyBadge.nextUrgency(current: nil), "not_urgent")
    }

    /// Verhalten: "not_urgent" toggled zu "urgent"
    /// Bricht wenn: Toggle-Reihenfolge geaendert
    func test_urgencyToggle_notUrgentToUrgent() {
        XCTAssertEqual(UrgencyBadge.nextUrgency(current: "not_urgent"), "urgent")
    }

    /// Verhalten: "urgent" toggled zu nil (entfernt)
    /// Bricht wenn: nil-Reset entfernt
    func test_urgencyToggle_urgentToNil() {
        XCTAssertNil(UrgencyBadge.nextUrgency(current: "urgent"))
    }

    /// Verhalten: Unbekannter Wert toggled zu nil (Fallback)
    /// Bricht wenn: Default-Case geaendert
    func test_urgencyToggle_unknownToNil() {
        XCTAssertNil(UrgencyBadge.nextUrgency(current: "unknown_value"))
    }

    // MARK: - PriorityScoreBadge Tier-Color Mapping

    /// Verhalten: doNow-Tier liefert .red
    /// Bricht wenn: Farb-Zuordnung in PriorityScoreBadge geaendert
    func test_priorityColor_doNowIsRed() {
        let color = PriorityScoreBadge.color(for: .doNow)
        XCTAssertEqual(color, .red)
    }

    /// Verhalten: planSoon-Tier liefert .orange
    /// Bricht wenn: Farb-Zuordnung geaendert
    func test_priorityColor_planSoonIsOrange() {
        let color = PriorityScoreBadge.color(for: .planSoon)
        XCTAssertEqual(color, .orange)
    }

    /// Verhalten: eventually-Tier liefert .yellow
    /// Bricht wenn: Farb-Zuordnung geaendert
    func test_priorityColor_eventuallyIsYellow() {
        let color = PriorityScoreBadge.color(for: .eventually)
        XCTAssertEqual(color, .yellow)
    }

    /// Verhalten: someday-Tier liefert .gray
    /// Bricht wenn: Farb-Zuordnung geaendert
    func test_priorityColor_somedayIsGray() {
        let color = PriorityScoreBadge.color(for: .someday)
        XCTAssertEqual(color, .gray)
    }
}
