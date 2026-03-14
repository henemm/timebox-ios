import XCTest
@testable import FocusBlox

final class CoachBacklogTests: XCTestCase {

    // MARK: - Discipline.classifyOpen() Tests

    /// Verhalten: Oft verschobene Tasks → Konsequenz
    /// Bricht wenn: Discipline.classifyOpen() nicht existiert oder rescheduleCount-Check fehlt
    func test_classifyOpen_procrastinated_returnsKonsequenz() {
        let discipline = Discipline.classifyOpen(rescheduleCount: 3, importance: 1)
        XCTAssertEqual(discipline, .konsequenz)
    }

    /// Verhalten: Wichtigkeit 3 → Mut
    /// Bricht wenn: Discipline.classifyOpen() importance==3 Check fehlt
    func test_classifyOpen_highImportance_returnsMut() {
        let discipline = Discipline.classifyOpen(rescheduleCount: 0, importance: 3)
        XCTAssertEqual(discipline, .mut)
    }

    /// Verhalten: Normaler Task → Ausdauer (Default)
    /// Bricht wenn: Discipline.classifyOpen() Default-Case fehlt
    func test_classifyOpen_default_returnsAusdauer() {
        let discipline = Discipline.classifyOpen(rescheduleCount: 0, importance: 1)
        XCTAssertEqual(discipline, .ausdauer)
    }

    /// Verhalten: Konsequenz hat Vorrang vor Mut (beides trifft zu)
    /// Bricht wenn: Discipline.classifyOpen() Prioritaetsreihenfolge falsch
    func test_classifyOpen_procrastinatedAndImportant_konsequenzWins() {
        let discipline = Discipline.classifyOpen(rescheduleCount: 2, importance: 3)
        XCTAssertEqual(discipline, .konsequenz)
    }

    /// Verhalten: Grenzwert rescheduleCount == 2 → Konsequenz
    /// Bricht wenn: Discipline.classifyOpen() >= 2 Vergleich falsch
    func test_classifyOpen_exactlyTwoReschedules_returnsKonsequenz() {
        let discipline = Discipline.classifyOpen(rescheduleCount: 2, importance: nil)
        XCTAssertEqual(discipline, .konsequenz)
    }

    /// Verhalten: importance nil → Ausdauer (nicht Mut)
    /// Bricht wenn: Discipline.classifyOpen() nil-Handling fuer importance fehlt
    func test_classifyOpen_nilImportance_returnsAusdauer() {
        let discipline = Discipline.classifyOpen(rescheduleCount: 0, importance: nil)
        XCTAssertEqual(discipline, .ausdauer)
    }
}
