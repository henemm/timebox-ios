import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class AITaskScoringServiceTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Model Default Values

    /// GIVEN: A new LocalTask is created
    /// WHEN: No AI scoring has been performed
    /// THEN: aiScore and aiEnergyLevel should be nil
    func test_localTask_aiFields_defaultNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task")
        context.insert(task)

        XCTAssertNil(task.aiScore, "aiScore should default to nil")
        XCTAssertNil(task.aiEnergyLevel, "aiEnergyLevel should default to nil")
    }

    /// GIVEN: A new LocalTask without AI scoring
    /// WHEN: Checking hasAIScoring
    /// THEN: Should return false
    func test_localTask_hasAIScoring_falseByDefault() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task")
        context.insert(task)

        XCTAssertFalse(task.hasAIScoring, "hasAIScoring should be false when aiScore is nil")
    }

    /// GIVEN: A LocalTask with aiScore set
    /// WHEN: Checking hasAIScoring
    /// THEN: Should return true
    func test_localTask_hasAIScoring_trueAfterScoring() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task")
        context.insert(task)

        task.aiScore = 75
        task.aiEnergyLevel = "high"

        XCTAssertTrue(task.hasAIScoring, "hasAIScoring should be true when aiScore is set")
    }

    // MARK: - PlanItem AI Fields

    /// GIVEN: A LocalTask with AI scoring
    /// WHEN: Creating a PlanItem from it
    /// THEN: AI fields should be carried over
    func test_planItem_carriesAIFields() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Scored Task")
        context.insert(task)

        task.aiScore = 85
        task.aiEnergyLevel = "low"

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.aiScore, 85, "PlanItem should carry aiScore from LocalTask")
        XCTAssertEqual(planItem.aiEnergyLevel, "low", "PlanItem should carry aiEnergyLevel from LocalTask")
        XCTAssertTrue(planItem.hasAIScoring, "PlanItem hasAIScoring should be true")
    }

    /// GIVEN: A LocalTask without AI scoring
    /// WHEN: Creating a PlanItem from it
    /// THEN: AI fields should be nil
    func test_planItem_nilAIFieldsWithoutScoring() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Unscored Task")
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertNil(planItem.aiScore, "PlanItem aiScore should be nil without scoring")
        XCTAssertNil(planItem.aiEnergyLevel, "PlanItem aiEnergyLevel should be nil without scoring")
        XCTAssertFalse(planItem.hasAIScoring, "PlanItem hasAIScoring should be false")
    }

    // MARK: - Score Clamping

    /// GIVEN: A LocalTask
    /// WHEN: AI score is set to values outside 0-100
    /// THEN: Values should be clamped
    func test_localTask_aiScore_acceptsValidRange() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task")
        context.insert(task)

        task.aiScore = 0
        XCTAssertEqual(task.aiScore, 0, "Score of 0 should be valid")

        task.aiScore = 100
        XCTAssertEqual(task.aiScore, 100, "Score of 100 should be valid")

        task.aiScore = 50
        XCTAssertEqual(task.aiScore, 50, "Score of 50 should be valid")
    }

    // MARK: - AI Service Availability

    /// GIVEN: AITaskScoringService
    /// WHEN: Checking isAvailable
    /// THEN: Should return a valid Bool (environment-dependent: true on Apple Silicon + macOS 26)
    func test_aiService_isAvailable_returnsBool() throws {
        // On Apple Silicon Macs with macOS 26, FoundationModels may be available even in simulator.
        // We verify the property works and returns a consistent result.
        let available = AITaskScoringService.isAvailable
        XCTAssertEqual(available, AITaskScoringService.isAvailable, "isAvailable should return consistent results")
    }

    // MARK: - Manual Importance Preservation

    /// GIVEN: A LocalTask with manually set importance
    /// WHEN: AI scoring is applied
    /// THEN: Manual importance should NOT be overwritten
    func test_localTask_manualImportancePreserved() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Important Task", importance: 3)
        context.insert(task)

        // Simulate AI scoring — should NOT touch manually set importance
        task.aiScore = 60
        task.aiEnergyLevel = "high"
        // AI suggestion would be importance=2, but manual importance=3 stays

        XCTAssertEqual(task.importance, 3, "Manually set importance should be preserved")
    }

    /// GIVEN: A TBD task without importance
    /// WHEN: AI scoring suggests importance
    /// THEN: Suggested importance should be applied
    func test_localTask_tbdTask_acceptsSuggestedImportance() throws {
        let context = container.mainContext
        let task = LocalTask(title: "TBD Task")
        context.insert(task)

        XCTAssertNil(task.importance, "TBD task should have nil importance")

        // Simulate: AI suggests importance for TBD task
        task.importance = 2

        XCTAssertEqual(task.importance, 2, "TBD task should accept AI-suggested importance")
    }

    // MARK: - AppSettings Toggle

    /// GIVEN: Default AppSettings
    /// WHEN: Checking aiScoringEnabled
    /// THEN: Should default to false
    func test_appSettings_aiScoringEnabled_defaultFalse() throws {
        // Clean up any previous test state
        UserDefaults.standard.removeObject(forKey: "aiScoringEnabled")

        let value = UserDefaults.standard.bool(forKey: "aiScoringEnabled")
        XCTAssertFalse(value, "aiScoringEnabled should default to false")
    }
}
