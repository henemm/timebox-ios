import Foundation
import Testing
import SwiftData
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

    // MARK: - Schema Parity: Fields added after initial Watch release

    /// Verhalten: Watch-Model hat recurrenceInterval (Schema-Paritaet mit iOS)
    /// Bricht wenn: WatchLocalTask.swift fehlt das Feld recurrenceInterval
    @Test func watchLocalTask_hasRecurrenceInterval() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.recurrenceInterval == nil)
    }

    /// Verhalten: Watch-Model hat isTemplate (Schema-Paritaet mit iOS)
    /// Bricht wenn: WatchLocalTask.swift fehlt das Feld isTemplate
    @Test func watchLocalTask_hasIsTemplate() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.isTemplate == false)
    }

    /// Verhalten: Watch-Model hat modifiedAt (Schema-Paritaet mit iOS)
    /// Bricht wenn: WatchLocalTask.swift fehlt das Feld modifiedAt
    @Test func watchLocalTask_hasModifiedAt() {
        let task = LocalTask(title: "Schema Test")
        #expect(task.modifiedAt == nil)
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

    // MARK: - CloudKit Entitlements (bug-watch-to-iphone-sync)

    /// Verhalten: Watch-Entitlements enthalten iCloud-Container-Identifier fuer CloudKit-Sync
    /// Bricht wenn: Entitlements-Datei fehlt com.apple.developer.icloud-container-identifiers
    @Test func watchEntitlements_hasCloudKitContainerIdentifier() throws {
        let entitlements = try loadWatchEntitlements()
        let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String]
        #expect(containers?.contains("iCloud.com.henning.focusblox") == true,
                "Watch entitlements must include iCloud container for CloudKit sync")
    }

    /// Verhalten: Watch-Entitlements enthalten CloudKit-Service-Deklaration
    /// Bricht wenn: Entitlements-Datei fehlt com.apple.developer.icloud-services
    @Test func watchEntitlements_hasCloudKitService() throws {
        let entitlements = try loadWatchEntitlements()
        let services = entitlements["com.apple.developer.icloud-services"] as? [String]
        #expect(services?.contains("CloudKit") == true,
                "Watch entitlements must include CloudKit service for sync")
    }

    // MARK: - Watch ModelContainer Logging (bug-watch-to-iphone-sync)

    /// Verhalten: Watch-App loggt CloudKit-Container-Status beim Start
    /// Bricht wenn: FocusBloxWatchApp.swift hat kein Logging im ModelContainer-Setup
    @Test func watchApp_logsCloudKitStatus() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let appFile = projectRoot
            .appendingPathComponent("FocusBloxWatch Watch App")
            .appendingPathComponent("FocusBloxWatchApp.swift")
        let source = try String(contentsOf: appFile, encoding: .utf8)
        #expect(source.contains("[CloudKit]"),
                "FocusBloxWatchApp must log CloudKit container status for diagnostics")
    }

    // MARK: - Helper

    private func loadWatchEntitlements() throws -> [String: Any] {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let entitlementsURL = projectRoot
            .appendingPathComponent("FocusBloxWatch Watch App")
            .appendingPathComponent("FocusBloxWatch Watch App.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
    }

    // MARK: - Watch Complication: Source-Based Tests

    /// Verhalten: ContentView hat .onOpenURL Handler fuer Deep-Link voice-capture
    /// Bricht wenn: ContentView.swift NICHT .onOpenURL mit "voice-capture" enthaelt
    @Test func watchContentView_hasOnOpenURLHandler() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let contentViewFile = projectRoot
            .appendingPathComponent("FocusBloxWatch Watch App")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewFile, encoding: .utf8)
        #expect(source.contains("onOpenURL"),
                "ContentView must have .onOpenURL handler for complication deep-link")
        #expect(source.contains("voice-capture"),
                "ContentView must handle voice-capture URL host")
    }

    /// Verhalten: QuickCaptureComplication.swift existiert mit StaticConfiguration
    /// Bricht wenn: Datei fehlt oder kein Widget definiert
    @Test func watchComplication_fileExists() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let complicationFile = projectRoot
            .appendingPathComponent("FocusBloxWatchWidgets")
            .appendingPathComponent("QuickCaptureComplication.swift")
        let source = try String(contentsOf: complicationFile, encoding: .utf8)
        #expect(source.contains("StaticConfiguration"),
                "Complication must use StaticConfiguration")
        #expect(source.contains("accessoryCircular"),
                "Complication must support accessoryCircular family")
        #expect(source.contains("focusblox://voice-capture"),
                "Complication must set widgetURL for deep-link")
    }

    /// Verhalten: Widget Bundle existiert mit @main Entry Point
    /// Bricht wenn: Bundle-Datei fehlt oder kein @main
    @Test func watchWidgetBundle_fileExists() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let bundleFile = projectRoot
            .appendingPathComponent("FocusBloxWatchWidgets")
            .appendingPathComponent("FocusBloxWatchWidgetsBundle.swift")
        let source = try String(contentsOf: bundleFile, encoding: .utf8)
        #expect(source.contains("@main"),
                "Widget bundle must have @main entry point")
        #expect(source.contains("QuickCaptureComplication"),
                "Widget bundle must include QuickCaptureComplication")
    }

    // MARK: - ModelContainer Integration: Full iOS-Schema Data Round-Trip

    /// Verhalten: Watch ModelContainer kann Tasks mit ALLEN iOS-Feldern speichern und laden
    /// Bricht wenn: Schema-Mismatch — fehlende Felder verhindern Container-Init oder Daten-Round-Trip
    /// Simuliert: iPhone synct Task via CloudKit → Watch muss sie lesen koennen
    @Test func modelContainer_roundTrip_withFullIOSSchema() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LocalTask.self, TaskMetadata.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Seed: Task mit ALLEN Feldern die iOS setzt (simuliert CloudKit-Sync)
        let task = LocalTask(title: "iOS-synced Task")
        task.importance = 3
        task.urgency = "urgent"
        task.estimatedDuration = 25
        task.taskType = "income"
        task.recurrencePattern = "weekly"
        task.recurrenceWeekdays = [1, 3, 5]
        task.recurrenceMonthDay = nil
        task.recurrenceInterval = 2          // iOS-only field
        task.recurrenceGroupID = "group-123"
        task.isTemplate = false              // iOS-only field
        task.modifiedAt = Date()             // iOS-only field
        task.isNextUp = true
        task.nextUpSortOrder = 1
        task.assignedFocusBlockID = "block-abc"
        task.rescheduleCount = 2
        task.completedAt = nil
        task.aiScore = 85
        task.aiEnergyLevel = "high"
        task.needsTitleImprovement = true
        task.sourceURL = "https://example.com"
        task.externalID = "ext-456"
        task.sourceSystem = "reminders"

        context.insert(task)
        try context.save()

        // Fetch: Watch muss die Task vollstaendig lesen koennen
        let descriptor = FetchDescriptor<LocalTask>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let t = fetched[0]
        #expect(t.title == "iOS-synced Task")
        #expect(t.recurrenceInterval == 2)
        #expect(t.isTemplate == false)
        #expect(t.modifiedAt != nil)
        #expect(t.importance == 3)
        #expect(t.aiScore == 85)
        #expect(t.needsTitleImprovement == true)
    }
}
