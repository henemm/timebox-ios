import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for the List-Views cleanup feature:
/// - modifiedAt field on LocalTask
/// - ViewMode enum reduced to 5 options
/// - Priority as default view
@MainActor
final class ListViewsCleanupTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - modifiedAt Field

    /// GIVEN: A new LocalTask
    /// WHEN: Created without explicit modifiedAt
    /// THEN: modifiedAt should be nil (default)
    /// BREAKS AT: task.modifiedAt — property doesn't exist yet
    func test_localTask_modifiedAt_defaultIsNil() throws {
        let task = LocalTask(title: "Test Task")
        XCTAssertNil(task.modifiedAt, "modifiedAt should default to nil for new tasks")
    }

    /// GIVEN: A LocalTask with modifiedAt set
    /// WHEN: Checking the value
    /// THEN: It should be the date we set
    /// BREAKS AT: task.modifiedAt — property doesn't exist yet
    func test_localTask_modifiedAt_canBeSet() throws {
        let task = LocalTask(title: "Test Task")
        let now = Date()
        task.modifiedAt = now
        XCTAssertEqual(task.modifiedAt, now, "modifiedAt should be settable")
    }

    // MARK: - PlanItem modifiedAt

    /// GIVEN: A PlanItem created from a LocalTask with modifiedAt set
    /// WHEN: Accessing modifiedAt on PlanItem
    /// THEN: It should have the modifiedAt value from the LocalTask
    func test_planItem_hasModifiedAt() throws {
        let now = Date()
        let task = LocalTask(title: "Test Task")
        task.modifiedAt = now
        let planItem = PlanItem(localTask: task)
        XCTAssertEqual(planItem.modifiedAt, now, "PlanItem should carry modifiedAt from LocalTask")
    }

    // MARK: - ViewMode Enum

    /// GIVEN: The ViewMode enum
    /// WHEN: Checking allCases
    /// THEN: It should have exactly 5 cases
    /// BREAKS AT: count — currently has 9 cases
    func test_viewMode_hasFiveCases() throws {
        let allCases = BacklogView.ViewMode.allCases
        XCTAssertEqual(allCases.count, 5, "ViewMode should have exactly 5 cases (priority, recent, overdue, recurring, completed)")
    }

    /// GIVEN: The ViewMode enum
    /// WHEN: Checking for "Zuletzt" raw value
    /// THEN: It should exist
    /// BREAKS AT: nil — "Zuletzt" case doesn't exist yet
    func test_viewMode_hasRecentCase() throws {
        let recent = BacklogView.ViewMode(rawValue: "Zuletzt")
        XCTAssertNotNil(recent, "ViewMode should have a 'Zuletzt' case")
    }

    /// GIVEN: The ViewMode enum
    /// WHEN: Checking for "Überfällig" raw value
    /// THEN: It should exist
    /// BREAKS AT: nil — "Überfällig" case doesn't exist yet
    func test_viewMode_hasOverdueCase() throws {
        let overdue = BacklogView.ViewMode(rawValue: "Überfällig")
        XCTAssertNotNil(overdue, "ViewMode should have an 'Überfällig' case")
    }

    /// GIVEN: The ViewMode enum
    /// WHEN: Checking for removed cases
    /// THEN: "Liste", "Matrix", "Kategorie", "Dauer", "Fälligkeit", "TBD" should NOT exist
    /// BREAKS AT: first assertion — "Liste" still exists
    func test_viewMode_removedCasesGone() throws {
        let removedRawValues = ["Liste", "Matrix", "Kategorie", "Dauer", "Fälligkeit", "TBD"]
        for rawValue in removedRawValues {
            let mode = BacklogView.ViewMode(rawValue: rawValue)
            XCTAssertNil(mode, "ViewMode '\(rawValue)' should be removed")
        }
    }
}
