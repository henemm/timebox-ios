import Testing
@testable import FocusBloxWatch_Watch_App

struct WatchLocalTaskSchemaTests {

    // MARK: - Schema Parity with iOS LocalTask

    /// Test: WatchLocalTask has all fields that iOS LocalTask has.
    /// EXPECTED TO FAIL: Missing assignedFocusBlockID, rescheduleCount, completedAt, aiScore, aiEnergyLevel
    @Test func watchLocalTask_hasAssignedFocusBlockID() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.assignedFocusBlockID == nil)
    }

    @Test func watchLocalTask_hasRescheduleCount() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.rescheduleCount == 0)
    }

    @Test func watchLocalTask_hasCompletedAt() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.completedAt == nil)
    }

    @Test func watchLocalTask_hasAiScore() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.aiScore == nil)
    }

    @Test func watchLocalTask_hasAiEnergyLevel() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.aiEnergyLevel == nil)
    }

    // MARK: - Type Corrections

    /// Test: recurrenceWeekdays should be optional (matching iOS)
    /// EXPECTED TO FAIL: Currently non-optional [Int] on Watch
    @Test func watchLocalTask_recurrenceWeekdays_isOptional() {
        let task = LocalTask(title: "Type Test")
        // On iOS, recurrenceWeekdays is [Int]? — should be nil by default
        #expect(task.recurrenceWeekdays == nil)
    }

    /// Test: recurrencePattern should be required String with default "none" (matching iOS)
    /// EXPECTED TO FAIL: Currently optional String? on Watch
    @Test func watchLocalTask_recurrencePattern_defaultsToNone() {
        let task = LocalTask(title: "Type Test")
        #expect(task.recurrencePattern == "none")
    }

    /// Test: taskType should default to empty string (matching iOS)
    /// EXPECTED TO FAIL: Currently defaults to "maintenance" on Watch
    @Test func watchLocalTask_taskType_defaultsToEmpty() {
        let task = LocalTask(title: "Default Test")
        #expect(task.taskType == "")
    }

    // MARK: - CTC-5: Title Improvement Flag (Schema Parity)

    /// Verhalten: Watch-Model hat needsTitleImprovement Feld (Default false)
    /// Bricht wenn: WatchLocalTask.swift fehlt das Feld needsTitleImprovement
    @Test func watchLocalTask_hasNeedsTitleImprovement() {
        let task = LocalTask(title: "Diktat Test")
        #expect(task.needsTitleImprovement == false)
    }

    /// Verhalten: Watch-Model hat sourceURL Feld (Schema-Paritaet mit iOS)
    /// Bricht wenn: WatchLocalTask.swift fehlt das Feld sourceURL
    @Test func watchLocalTask_hasSourceURL() {
        let task = LocalTask(title: "URL Test")
        #expect(task.sourceURL == nil)
    }

    /// Verhalten: needsTitleImprovement kann auf true gesetzt werden
    /// Bricht wenn: Feld ist read-only oder fehlt
    @Test func watchLocalTask_needsTitleImprovement_canBeSetToTrue() {
        let task = LocalTask(title: "Diktat Task")
        task.needsTitleImprovement = true
        #expect(task.needsTitleImprovement == true)
    }

    // MARK: - TBD Task Creation (Watch use case)

    @Test func createTask_withTitleOnly_isTBD() {
        let task = LocalTask(title: "Mein Watch Task")
        #expect(task.title == "Mein Watch Task")
        #expect(task.importance == nil)
        #expect(task.urgency == nil)
        #expect(task.estimatedDuration == nil)
        #expect(task.isCompleted == false)
        #expect(task.isNextUp == false)
        #expect(task.sourceSystem == "local")
    }
}
