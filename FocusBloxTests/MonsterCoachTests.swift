import Testing
import Foundation
@testable import FocusBlox

@Suite("MonsterCoach Tests")
struct MonsterCoachTests {

    // MARK: - Discipline Classification

    @Test("Procrastinated task (rescheduleCount >= 2) -> konsequenz")
    func classify_procrastinated_returnsKonsequenz() {
        let discipline = Discipline.classify(
            rescheduleCount: 3,
            importance: 1,
            effectiveDuration: 15,
            estimatedDuration: 15
        )
        #expect(discipline == .konsequenz)
    }

    @Test("High importance task (importance == 3) -> mut")
    func classify_highImportance_returnsMut() {
        let discipline = Discipline.classify(
            rescheduleCount: 0,
            importance: 3,
            effectiveDuration: 10,
            estimatedDuration: 15
        )
        #expect(discipline == .mut)
    }

    @Test("Task completed within estimated duration -> fokus")
    func classify_withinEstimate_returnsFokus() {
        let discipline = Discipline.classify(
            rescheduleCount: 0,
            importance: 1,
            effectiveDuration: 12,
            estimatedDuration: 15
        )
        #expect(discipline == .fokus)
    }

    @Test("Default task -> ausdauer")
    func classify_default_returnsAusdauer() {
        let discipline = Discipline.classify(
            rescheduleCount: 0,
            importance: 1,
            effectiveDuration: 20,
            estimatedDuration: 15
        )
        #expect(discipline == .ausdauer)
    }

    // MARK: - MonsterCoach XP

    @Test("awardXP increments correct discipline")
    func awardXP_incrementsCorrectDiscipline() {
        var coach = MonsterCoach(name: "Testmonster")
        coach.awardXP(for: .mut, amount: 10)
        #expect(coach.xp[Discipline.mut.rawValue] == 10)
        #expect(coach.xp[Discipline.fokus.rawValue, default: 0] == 0)
    }

    // MARK: - Evolution Level

    @Test("Evolution level increases with total XP")
    func evolutionLevel_increasesWithXP() {
        var coach = MonsterCoach(name: "Testmonster")
        // Level 0: Ei (0-49)
        #expect(coach.evolutionLevel == 0)

        // Level 1: Baby (50-199)
        coach.awardXP(for: .konsequenz, amount: 50)
        #expect(coach.evolutionLevel == 1)

        // Level 2: Junior (200-499)
        coach.awardXP(for: .mut, amount: 150)
        #expect(coach.evolutionLevel == 2)

        // Level 3: Erwachsen (500-999)
        coach.awardXP(for: .fokus, amount: 300)
        #expect(coach.evolutionLevel == 3)

        // Level 4: Meister (1000+)
        coach.awardXP(for: .ausdauer, amount: 500)
        #expect(coach.evolutionLevel == 4)
    }

    // MARK: - Persistence

    @Test("MonsterCoach save/load roundtrip via UserDefaults")
    func saveLoad_roundtrip() {
        let key = "monsterCoachState_test_\(UUID().uuidString)"
        var original = MonsterCoach(name: "Roundtrip")
        original.awardXP(for: .konsequenz, amount: 25)
        original.awardXP(for: .mut, amount: 10)
        original.totalTasksCompleted = 5

        original.save(key: key)
        let loaded = MonsterCoach.load(key: key)

        #expect(loaded.name == "Roundtrip")
        #expect(loaded.xp[Discipline.konsequenz.rawValue] == 25)
        #expect(loaded.xp[Discipline.mut.rawValue] == 10)
        #expect(loaded.totalTasksCompleted == 5)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }
}
