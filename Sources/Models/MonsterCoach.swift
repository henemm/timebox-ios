import Foundation

/// Persistent Monster Coach state, stored as JSON in UserDefaults.
struct MonsterCoach: Codable, Equatable {
    var name: String
    var xp: [String: Int]
    var totalTasksCompleted: Int
    var createdAt: Date

    static let defaultKey = "monsterCoachState"

    init(name: String) {
        self.name = name
        self.xp = [:]
        self.totalTasksCompleted = 0
        self.createdAt = Date()
    }

    // MARK: - XP

    var totalXP: Int {
        xp.values.reduce(0, +)
    }

    mutating func awardXP(for discipline: Discipline, amount: Int) {
        xp[discipline.rawValue, default: 0] += amount
    }

    // MARK: - Evolution

    /// Evolution level: 0=Ei(0-49), 1=Baby(50-199), 2=Junior(200-499), 3=Erwachsen(500-999), 4=Meister(1000+)
    var evolutionLevel: Int {
        let total = totalXP
        switch total {
        case 0..<50: return 0
        case 50..<200: return 1
        case 200..<500: return 2
        case 500..<1000: return 3
        default: return 4
        }
    }

    var evolutionName: String {
        switch evolutionLevel {
        case 0: "Ei"
        case 1: "Baby"
        case 2: "Junior"
        case 3: "Erwachsen"
        default: "Meister"
        }
    }

    var evolutionIcon: String {
        switch evolutionLevel {
        case 0: "oval"
        case 1: "hare"
        case 2: "dog"
        case 3: "lion"
        default: "crown"
        }
    }

    // MARK: - Persistence

    func save(key: String = MonsterCoach.defaultKey) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load(key: String = MonsterCoach.defaultKey) -> MonsterCoach {
        guard let data = UserDefaults.standard.data(forKey: key),
              let coach = try? JSONDecoder().decode(MonsterCoach.self, from: data) else {
            return MonsterCoach(name: "Monster")
        }
        return coach
    }
}
