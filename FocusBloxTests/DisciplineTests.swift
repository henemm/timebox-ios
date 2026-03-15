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

    // MARK: - resolveOpen() Override Tests

    /// Verhalten: Override "mut" gewinnt ueber Auto-Berechnung (die .konsequenz waere)
    /// Bricht wenn: Discipline.resolveOpen() existiert nicht oder ignoriert manualDiscipline
    func test_resolveOpen_overrideMut_ignoresAutoKonsequenz() {
        let result = Discipline.resolveOpen(
            manualDiscipline: "mut",
            rescheduleCount: 5,  // Auto waere .konsequenz (>=2)
            importance: 1
        )
        XCTAssertEqual(result, .mut, "Manual override 'mut' should win over auto-calculated 'konsequenz'")
    }

    /// Verhalten: Override "fokus" wird respektiert (fokus ist bei offenen Tasks per Auto nicht erreichbar)
    /// Bricht wenn: resolveOpen() den Override nicht als Discipline(rawValue:) parst
    func test_resolveOpen_overrideFokus_notReachableByAuto() {
        let result = Discipline.resolveOpen(
            manualDiscipline: "fokus",
            rescheduleCount: 0,
            importance: nil  // Auto waere .ausdauer
        )
        XCTAssertEqual(result, .fokus, "Manual override should enable 'fokus' which auto-calc cannot reach for open tasks")
    }

    /// Verhalten: Override nil → Fallback auf classifyOpen()
    /// Bricht wenn: resolveOpen() bei nil nicht auf classifyOpen() delegiert
    func test_resolveOpen_nilOverride_fallsBackToAuto() {
        let result = Discipline.resolveOpen(
            manualDiscipline: nil,
            rescheduleCount: 3,
            importance: 1
        )
        XCTAssertEqual(result, .konsequenz, "nil override should fall back to auto-calculation (.konsequenz for rescheduleCount>=2)")
    }

    /// Verhalten: Ungueltiger String → Fallback auf classifyOpen()
    /// Bricht wenn: resolveOpen() bei ungueltigem rawValue nicht auf classifyOpen() faellt
    func test_resolveOpen_invalidString_fallsBackToAuto() {
        let result = Discipline.resolveOpen(
            manualDiscipline: "ungueltig",
            rescheduleCount: 0,
            importance: 3  // Auto waere .mut
        )
        XCTAssertEqual(result, .mut, "Invalid override string should fall back to auto-calculation (.mut for importance==3)")
    }

    /// Verhalten: Override "konsequenz" explizit gesetzt
    /// Bricht wenn: resolveOpen() den rawValue "konsequenz" nicht korrekt parst
    func test_resolveOpen_overrideKonsequenz_returnsKonsequenz() {
        let result = Discipline.resolveOpen(
            manualDiscipline: "konsequenz",
            rescheduleCount: 0,
            importance: nil  // Auto waere .ausdauer
        )
        XCTAssertEqual(result, .konsequenz, "Manual override 'konsequenz' should be returned")
    }

    /// Verhalten: Override "ausdauer" explizit gesetzt wenn Auto .mut waere
    /// Bricht wenn: resolveOpen() bei validem Override trotzdem Auto-Berechnung nutzt
    func test_resolveOpen_overrideAusdauer_overridesAutoMut() {
        let result = Discipline.resolveOpen(
            manualDiscipline: "ausdauer",
            rescheduleCount: 0,
            importance: 3  // Auto waere .mut
        )
        XCTAssertEqual(result, .ausdauer, "Manual override 'ausdauer' should win over auto-calculated 'mut'")
    }
}
