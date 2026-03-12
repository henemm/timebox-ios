import XCTest
@testable import FocusBlox

final class DisciplineTests: XCTestCase {

    func test_classify_procrastinated_returnsKonsequenz() {
        let discipline = Discipline.classify(
            rescheduleCount: 3,
            importance: 1,
            effectiveDuration: 15,
            estimatedDuration: 15
        )
        XCTAssertEqual(discipline, .konsequenz)
    }

    func test_classify_highImportance_returnsMut() {
        let discipline = Discipline.classify(
            rescheduleCount: 0,
            importance: 3,
            effectiveDuration: 10,
            estimatedDuration: 15
        )
        XCTAssertEqual(discipline, .mut)
    }

    func test_classify_withinEstimate_returnsFokus() {
        let discipline = Discipline.classify(
            rescheduleCount: 0,
            importance: 1,
            effectiveDuration: 12,
            estimatedDuration: 15
        )
        XCTAssertEqual(discipline, .fokus)
    }

    func test_classify_default_returnsAusdauer() {
        let discipline = Discipline.classify(
            rescheduleCount: 0,
            importance: 1,
            effectiveDuration: 20,
            estimatedDuration: 15
        )
        XCTAssertEqual(discipline, .ausdauer)
    }
}
