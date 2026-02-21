import XCTest
@testable import FocusBlox

/// Tests for TaskEntity NSUserActivity integration (ITB-F-lite).
/// Ensures tasks are discoverable by Siri/Spotlight via NSUserActivity.
final class TaskEntityUserActivityTests: XCTestCase {

    /// Verhalten: TaskEntity hat einen stabilen activityType-String
    /// Bricht wenn: TaskEntity.activityType nicht existiert oder Wert sich aendert
    func test_activityType_isStableIdentifier() {
        XCTAssertEqual(
            TaskEntity.activityType,
            "com.henning.focusblox.viewTask"
        )
    }

    /// Verhalten: userActivity() erzeugt korrekt konfigurierte NSUserActivity
    /// Bricht wenn: userActivity()-Methode nicht existiert oder Properties falsch setzt
    func test_userActivity_setsRequiredProperties() {
        let entity = TaskEntity(
            id: "uuid-123",
            title: "Write unit tests",
            importance: .high,
            duration: 30,
            isCompleted: false
        )

        let activity = entity.userActivity

        XCTAssertEqual(activity.activityType, "com.henning.focusblox.viewTask")
        XCTAssertEqual(activity.title, "Write unit tests")
        XCTAssertTrue(activity.isEligibleForSearch)
        XCTAssertTrue(activity.isEligibleForPrediction)
        XCTAssertEqual(activity.userInfo?["entityID"] as? String, "uuid-123")
    }

    /// Verhalten: userActivity setzt targetContentIdentifier fuer Handoff
    /// Bricht wenn: targetContentIdentifier nicht gesetzt wird
    func test_userActivity_setsContentIdentifier() {
        let entity = TaskEntity(
            id: "uuid-456",
            title: "Review code",
            isCompleted: false
        )

        let activity = entity.userActivity

        XCTAssertEqual(activity.targetContentIdentifier, "task://uuid-456")
    }
}
