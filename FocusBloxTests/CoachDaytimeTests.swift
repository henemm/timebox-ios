import XCTest
@testable import FocusBlox

/// TDD: Coach Daytime — dynamischer Motivationstext (#202).
@MainActor
final class CoachDaytimeTests: XCTestCase {

    /// 0 Tasks → ermutigender Text
    func test_daytimeMotivation_zeroTasks() {
        let text = SuccessStoryService.daytimeMotivation(completedCount: 0, totalPlanned: 5)
        XCTAssertFalse(text.isEmpty, "Motivation darf nicht leer sein")
        XCTAssertTrue(text.count <= 200, "Text sollte nicht übermäßig lang sein (\(text.count) Zeichen)")
    }

    /// 1-3 Tasks → anerkennender Text
    func test_daytimeMotivation_fewTasks() {
        let text = SuccessStoryService.daytimeMotivation(completedCount: 2, totalPlanned: 5)
        XCTAssertFalse(text.isEmpty)
    }

    /// 4+ Tasks → feiernder Text
    func test_daytimeMotivation_manyTasks() {
        let text = SuccessStoryService.daytimeMotivation(completedCount: 6, totalPlanned: 6)
        XCTAssertFalse(text.isEmpty)
    }

    /// Verschiedene Counts → verschiedene Texte
    func test_daytimeMotivation_varies() {
        let t0 = SuccessStoryService.daytimeMotivation(completedCount: 0, totalPlanned: 3)
        let t3 = SuccessStoryService.daytimeMotivation(completedCount: 3, totalPlanned: 3)
        XCTAssertNotEqual(t0, t3, "0 und 3 Tasks sollten verschiedene Texte liefern")
    }
}
