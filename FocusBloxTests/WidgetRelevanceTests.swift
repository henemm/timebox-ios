import XCTest
@testable import FocusBlox

/// Tests for Widget Relevance Score calculation (ITB-G3).
/// The score determines Smart Stack placement of the QuickCapture widget.
final class WidgetRelevanceTests: XCTestCase {

    /// Verhalten: Aktiver Focus Block ergibt hoechsten Score (100)
    /// Bricht wenn: Score-Berechnung den activeBlock-Case nicht auf 100 setzt
    func test_calculateRelevance_activeFocusBlock_returns100() {
        let score = WidgetRelevanceCalculator.calculateScore(
            hasActiveFocusBlock: true,
            urgentTaskCount: 0,
            totalTaskCount: 0
        )

        XCTAssertEqual(score, 100.0)
    }

    /// Verhalten: Dringende Tasks ohne aktiven Block ergibt Score 80
    /// Bricht wenn: urgentTaskCount-Case nicht auf 80 gemappt wird
    func test_calculateRelevance_urgentTasks_returns80() {
        let score = WidgetRelevanceCalculator.calculateScore(
            hasActiveFocusBlock: false,
            urgentTaskCount: 3,
            totalTaskCount: 5
        )

        XCTAssertEqual(score, 80.0)
    }

    /// Verhalten: Normale Tasks (nicht dringend) ergibt Score 40
    /// Bricht wenn: totalTaskCount > 0 Case nicht auf 40 gemappt wird
    func test_calculateRelevance_normalTasks_returns40() {
        let score = WidgetRelevanceCalculator.calculateScore(
            hasActiveFocusBlock: false,
            urgentTaskCount: 0,
            totalTaskCount: 5
        )

        XCTAssertEqual(score, 40.0)
    }

    /// Verhalten: Keine Tasks ergibt niedrigsten Score (10)
    /// Bricht wenn: Fallback-Score nicht auf 10 gesetzt wird
    func test_calculateRelevance_noTasks_returns10() {
        let score = WidgetRelevanceCalculator.calculateScore(
            hasActiveFocusBlock: false,
            urgentTaskCount: 0,
            totalTaskCount: 0
        )

        XCTAssertEqual(score, 10.0)
    }

    /// Verhalten: Aktiver Focus Block hat Prioritaet ueber dringende Tasks
    /// Bricht wenn: activeBlock-Check nicht VOR urgentTaskCount-Check steht
    func test_calculateRelevance_activeFocusBlock_overridesUrgent() {
        let score = WidgetRelevanceCalculator.calculateScore(
            hasActiveFocusBlock: true,
            urgentTaskCount: 5,
            totalTaskCount: 10
        )

        XCTAssertEqual(score, 100.0, "Active focus block should override urgent tasks")
    }

    /// Verhalten: Ein einziger dringender Task reicht fuer Score 80
    /// Bricht wenn: urgentTaskCount-Check auf > 1 statt > 0 prueft
    func test_calculateRelevance_singleUrgentTask_returns80() {
        let score = WidgetRelevanceCalculator.calculateScore(
            hasActiveFocusBlock: false,
            urgentTaskCount: 1,
            totalTaskCount: 1
        )

        XCTAssertEqual(score, 80.0)
    }
}
