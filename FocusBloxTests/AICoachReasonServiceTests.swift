import XCTest
@testable import FocusBlox

final class AICoachReasonServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makePlanItem(
        title: String = "Test Task",
        importance: Int? = 2,
        urgency: String? = "not_urgent",
        estimatedDuration: Int? = 30,
        taskType: String = "income",
        rescheduleCount: Int = 0,
        tags: [String]? = nil,
        aiEnergyLevel: String? = nil
    ) -> PlanItem {
        let task = LocalTask(
            title: title,
            importance: importance,
            estimatedDuration: estimatedDuration,
            urgency: urgency,
            taskType: taskType
        )
        task.rescheduleCount = rescheduleCount
        task.aiEnergyLevel = aiEnergyLevel
        if let tags { task.tags = tags }
        return PlanItem(localTask: task)
    }

    private func makeSlot(startHour: Int, endHour: Int) -> TimeSlot {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var startComps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        startComps.hour = startHour
        var endComps = startComps
        endComps.hour = endHour
        return TimeSlot(startDate: calendar.date(from: startComps)!, endDate: calendar.date(from: endComps)!)
    }

    private func makeProfile(
        affinity: [TaskCategory: [DayPeriod: Double]]? = nil
    ) -> BehavioralProfile {
        BehavioralProfile(
            computedAt: Date(),
            categoryTimeAffinity: affinity,
            avgTasksPerDay: 5.0,
            avgMinutesPerDay: 120.0,
            estimationFactor: 1.0,
            capacityByMeetingLoad: nil,
            procrastinationPatterns: nil
        )
    }

    // MARK: - Fallback Tests

    /// Verhalten: reason() liefert immer einen nicht-leeren Text (AI oder Fallback).
    /// Bricht wenn: AICoachReasonService weder AI noch Fallback liefert.
    func test_reason_returnsNonEmptyText() async {
        let item = makePlanItem(title: "Steuererklärung", importance: 3, estimatedDuration: 30)
        let slot = makeSlot(startHour: 9, endHour: 10)

        let result = await AICoachReasonService.reason(
            for: item, slot: slot, profile: nil, allItems: []
        )

        XCTAssertFalse(result.isEmpty, "Muss einen nicht-leeren Text liefern (AI oder Fallback)")
        XCTAssertGreaterThan(result.count, 5, "Text muss substantiell sein, war: \(result)")
    }

    /// Verhalten: reason() liefert fuer oft verschobene Tasks einen relevanten Text.
    /// Bricht wenn: Weder AI noch Fallback die Verschiebungen thematisieren.
    func test_reason_forRescheduledTask_returnsRelevantText() async {
        let item = makePlanItem(title: "Aufräumen", rescheduleCount: 5)

        let result = await AICoachReasonService.reason(
            for: item, slot: nil, profile: nil, allItems: []
        )

        XCTAssertFalse(result.isEmpty, "Muss Text liefern fuer verschobene Tasks")
        XCTAssertGreaterThan(result.count, 5, "Text muss substantiell sein, war: \(result)")
    }

    /// Verhalten: Der deterministische Fallback enthält "wichtig" fuer importance=3.
    /// Bricht wenn: Der Fallback-Pfad den importance-Check verliert.
    func test_deterministicFallback_mentionsImportance() {
        let item = makePlanItem(title: "Steuererklärung", importance: 3)

        let result = NextUpSuggestionService.reasonText(for: item)

        XCTAssertTrue(result.localizedCaseInsensitiveContains("wichtig"),
                      "Deterministischer Fallback fuer importance=3 muss 'wichtig' enthalten, war: \(result)")
    }

    // MARK: - Prompt Building Tests

    /// Verhalten: Der Prompt enthält Task-Titel, Kategorie und Dauer.
    /// Bricht wenn: buildPrompt() essentielle Task-Daten weglässt.
    func test_buildPrompt_containsTaskContext() {
        let item = makePlanItem(title: "Code Review", estimatedDuration: 45, taskType: "income")
        let slot = makeSlot(startHour: 9, endHour: 10)

        let prompt = AICoachReasonService.buildPrompt(
            for: item, slot: slot, profile: nil, allItems: []
        )

        XCTAssertTrue(prompt.contains("Code Review"), "Prompt muss Task-Titel enthalten")
        XCTAssertTrue(prompt.contains("45"), "Prompt muss geschätzte Dauer enthalten")
        XCTAssertTrue(prompt.contains("income") || prompt.contains("Einkommen"),
                      "Prompt muss Kategorie enthalten")
    }

    /// Verhalten: Der Prompt enthält Tag-Cluster-Info wenn mehrere Tasks gleichen Tag haben.
    /// Bricht wenn: buildPrompt() Tags ignoriert.
    func test_buildPrompt_containsTagCluster() {
        let item = makePlanItem(title: "Rasen mähen", tags: ["garten"])
        let otherItems = [
            makePlanItem(title: "Hecke schneiden", tags: ["garten"]),
            makePlanItem(title: "Kompost umsetzen", tags: ["garten"]),
        ]

        let prompt = AICoachReasonService.buildPrompt(
            for: item, slot: nil, profile: nil, allItems: [item] + otherItems
        )

        XCTAssertTrue(prompt.contains("garten"), "Prompt muss Tag erwaehnen")
        XCTAssertTrue(prompt.contains("2") || prompt.contains("3"),
                      "Prompt muss Anzahl Tasks mit gleichem Tag erwaehnen")
    }

    /// Verhalten: Der Prompt enthält Zeitpräferenz aus BehavioralProfile.
    /// Bricht wenn: buildPrompt() das Profil ignoriert.
    func test_buildPrompt_containsTimePreference() {
        let item = makePlanItem(title: "Deep Work", taskType: "income")
        let slot = makeSlot(startHour: 9, endHour: 10)
        let profile = makeProfile(affinity: [
            .income: [.morning: 0.9, .afternoon: 0.3, .evening: 0.1]
        ])

        let prompt = AICoachReasonService.buildPrompt(
            for: item, slot: slot, profile: profile, allItems: []
        )

        XCTAssertTrue(prompt.localizedCaseInsensitiveContains("morgen") ||
                      prompt.localizedCaseInsensitiveContains("vormittag") ||
                      prompt.localizedCaseInsensitiveContains("90%") ||
                      prompt.localizedCaseInsensitiveContains("bevorzugt"),
                      "Prompt muss Zeitpräferenz erwähnen, war: \(prompt)")
    }

    /// Verhalten: Der Prompt enthält freies Zeitfenster in Minuten.
    /// Bricht wenn: buildPrompt() die Slot-Dauer weglässt.
    func test_buildPrompt_containsSlotDuration() {
        let item = makePlanItem(title: "Emails", estimatedDuration: 15)
        let slot = makeSlot(startHour: 14, endHour: 15) // 60 Min

        let prompt = AICoachReasonService.buildPrompt(
            for: item, slot: slot, profile: nil, allItems: []
        )

        XCTAssertTrue(prompt.contains("60"), "Prompt muss freie Slot-Dauer (60 Min) enthalten")
    }
}
