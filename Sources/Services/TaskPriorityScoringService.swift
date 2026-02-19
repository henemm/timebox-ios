import Foundation

/// Deterministic priority scoring for tasks.
/// Replaces AI-based scoring with a transparent, reproducible algorithm.
/// Same data = same result, no async, no AI dependencies.
struct TaskPriorityScoringService {

    // MARK: - Priority Tiers

    enum PriorityTier: Int, CaseIterable {
        case doNow = 1       // 60-100
        case planSoon = 2    // 35-59
        case eventually = 3  // 10-34
        case someday = 4     // 0-9

        var label: String {
            switch self {
            case .doNow: return "Sofort erledigen"
            case .planSoon: return "Bald einplanen"
            case .eventually: return "Bei Gelegenheit"
            case .someday: return "Irgendwann"
            }
        }

        static func from(score: Int) -> PriorityTier {
            switch score {
            case 60...100: return .doNow
            case 35...59: return .planSoon
            case 10...34: return .eventually
            default: return .someday
            }
        }
    }

    // MARK: - Main Scoring

    /// Calculate total priority score (0-100) from task attributes.
    static func calculateScore(
        importance: Int?,
        urgency: String?,
        dueDate: Date?,
        createdAt: Date,
        rescheduleCount: Int,
        estimatedDuration: Int?,
        taskType: String,
        isNextUp: Bool,
        now: Date = Date()
    ) -> Int {
        let eisenhower = eisenhowerScore(importance: importance, urgency: urgency)
        let deadline = deadlineScore(dueDate: dueDate, now: now)
        let neglect = neglectScore(createdAt: createdAt, rescheduleCount: rescheduleCount, now: now)
        let completeness = completenessScore(
            importance: importance,
            urgency: urgency,
            duration: estimatedDuration,
            taskType: taskType
        )
        let nextUp = nextUpBonus(isNextUp: isNextUp)

        return min(100, eisenhower + deadline + neglect + completeness + nextUp)
    }

    // MARK: - Eisenhower Matrix (0-50)

    static func eisenhowerScore(importance: Int?, urgency: String?) -> Int {
        let isUrgent = urgency == "urgent"
        let isNotUrgent = urgency == "not_urgent"

        switch (importance, isUrgent, isNotUrgent) {
        // Both set
        case (3, true, _):  return 50
        case (3, _, true):  return 38
        case (2, true, _):  return 35
        case (1, true, _):  return 30
        case (2, _, true):  return 20
        case (1, _, true):  return 10

        // Only urgency set
        case (nil, true, _):  return 25
        case (nil, _, true):  return 8

        // Only importance set
        case (let imp?, false, false) where imp >= 1: return 15

        // Neither set
        default: return 0
        }
    }

    // MARK: - Deadline Proximity (0-25)

    static func deadlineScore(dueDate: Date?, now: Date = Date()) -> Int {
        guard let dueDate else { return 0 }

        let calendar = Calendar.current
        let daysUntil = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0

        switch daysUntil {
        case ...0:   return 25  // Overdue or today
        case 1:      return 22  // Tomorrow
        case 2...3:  return 18  // Within 3 days
        case 4...7:  return 12  // This week
        case 8...14: return 6   // Within 2 weeks
        case 15...30: return 3  // Within 1 month
        default:     return 0   // Later
        }
    }

    // MARK: - Neglect Score (0-15)

    static func neglectScore(createdAt: Date, rescheduleCount: Int, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let daysOld = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdAt), to: calendar.startOfDay(for: now)).day ?? 0

        // Age component: 0-10 points, linearly scaled over 30 days
        let ageScore = min(10, daysOld * 10 / 30)

        // Reschedule component: 0-5 points
        let rescheduleScore = min(5, rescheduleCount)

        return ageScore + rescheduleScore
    }

    // MARK: - Completeness Score (0-5)

    static func completenessScore(importance: Int?, urgency: String?, duration: Int?, taskType: String) -> Int {
        var score = 0
        if importance != nil { score += 1 }
        if urgency != nil { score += 1 }
        if duration != nil { score += 1 }
        if !taskType.isEmpty { score += 1 }
        if score == 4 { score += 1 } // Bonus for all 4 set
        return score
    }

    // MARK: - Next Up Bonus (0-5)

    static func nextUpBonus(isNextUp: Bool) -> Int {
        isNextUp ? 5 : 0
    }
}
