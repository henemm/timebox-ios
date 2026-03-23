import Foundation

/// Berechnet ein Verhaltensprofil aus LocalTask- und FocusBlock-Daten.
/// Pattern: enum mit static methods (wie CategoryStatsService).
/// Cache: in-memory, kein AppSettings.
enum BehavioralProfileService {

    // MARK: - Cache

    nonisolated(unsafe) private static var _cache: (profile: BehavioralProfile, date: Date)?

    // MARK: - Minimum-Sample-Schwellen

    static let minTasksForAffinity: Int = 10
    static let minActiveDaysForCapacity: Int = 5
    static let minTasksForEstimation: Int = 10

    // MARK: - Public API

    /// Gibt das gecachte Profil zurueck oder berechnet es neu.
    /// Cache wird invalidiert wenn computedAt von einem anderen Kalendertag ist.
    static func profile(
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> BehavioralProfile {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        if let cached = _cache,
           calendar.startOfDay(for: cached.date) == today {
            return cached.profile
        }

        let computed = compute(tasks: tasks, focusBlocks: focusBlocks, now: now)
        _cache = (profile: computed, date: now)
        return computed
    }

    /// Berechnet ein frisches Profil ohne Cache (fuer Tests und erzwungene Neuberechnung).
    static func compute(
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> BehavioralProfile {
        let windowStart = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now
        )
        let windowedTasks = tasks.filter { task in
            task.isCompleted
                && task.completedAt != nil
                && task.completedAt! >= windowStart
                && task.completedAt! <= now
        }

        return BehavioralProfile(
            computedAt: now,
            categoryTimeAffinity: computeTimeAffinity(from: windowedTasks),
            avgTasksPerDay: computeAvgTasksPerDay(from: windowedTasks),
            avgMinutesPerDay: computeAvgMinutesPerDay(from: windowedTasks, focusBlocks: focusBlocks),
            estimationFactor: computeEstimationFactor(from: windowedTasks, focusBlocks: focusBlocks)
        )
    }

    /// Loescht den in-memory Cache.
    static func invalidateCache() {
        _cache = nil
    }

    // MARK: - Komponente 1: Tageszeit-Affinitaet

    /// Berechnet fuer jede Kategorie den Anteil pro Tageszeit-Fenster.
    /// Nur Tasks mit gesetzter Kategorie werden gezaehlt.
    static func computeTimeAffinity(
        from tasks: [LocalTask]
    ) -> [TaskCategory: [DayPeriod: Double]]? {
        let categorized = tasks.filter {
            TaskCategory(rawValue: $0.taskType) != nil && $0.completedAt != nil
        }
        guard categorized.count >= minTasksForAffinity else { return nil }

        var result: [TaskCategory: [DayPeriod: Double]] = [:]

        for category in TaskCategory.allCases {
            let categoryTasks = categorized.filter { $0.taskType == category.rawValue }
            guard !categoryTasks.isEmpty else {
                result[category] = [.morning: 0.0, .afternoon: 0.0, .evening: 0.0]
                continue
            }

            var counts: [DayPeriod: Int] = [.morning: 0, .afternoon: 0, .evening: 0]
            for task in categoryTasks {
                guard let completedAt = task.completedAt else { continue }
                let period = dayPeriod(for: completedAt)
                counts[period, default: 0] += 1
            }

            let total = Double(categoryTasks.count)
            result[category] = [
                .morning:   Double(counts[.morning]   ?? 0) / total,
                .afternoon: Double(counts[.afternoon] ?? 0) / total,
                .evening:   Double(counts[.evening]   ?? 0) / total,
            ]
        }

        return result
    }

    // MARK: - Komponente 2: Taegliche Kapazitaet

    /// Durchschnittliche Anzahl erledigter Tasks pro aktivem Tag.
    static func computeAvgTasksPerDay(from tasks: [LocalTask]) -> Double? {
        let calendar = Calendar.current
        var tasksByDay: [Date: Int] = [:]

        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            let day = calendar.startOfDay(for: completedAt)
            tasksByDay[day, default: 0] += 1
        }

        guard tasksByDay.count >= minActiveDaysForCapacity else { return nil }

        let total = tasksByDay.values.reduce(0, +)
        return Double(total) / Double(tasksByDay.count)
    }

    /// Durchschnittliche tatsaechliche Arbeitszeit pro aktivem Tag (Minuten).
    static func computeAvgMinutesPerDay(
        from tasks: [LocalTask],
        focusBlocks: [FocusBlock]
    ) -> Double? {
        let calendar = Calendar.current

        var taskDayMap: [String: Date] = [:]
        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            taskDayMap[task.id] = calendar.startOfDay(for: completedAt)
        }

        var secondsByDay: [Date: Int] = [:]
        for block in focusBlocks {
            for (taskID, seconds) in block.taskTimes {
                guard let day = taskDayMap[taskID] else { continue }
                secondsByDay[day, default: 0] += seconds
            }
        }

        guard secondsByDay.count >= minActiveDaysForCapacity else { return nil }

        let totalSeconds = secondsByDay.values.reduce(0, +)
        return Double(totalSeconds) / Double(secondsByDay.count) / 60.0
    }

    // MARK: - Komponente 3: Schaetz-Genauigkeit

    /// Faktor geschaetzte vs. tatsaechliche Dauer.
    static func computeEstimationFactor(
        from tasks: [LocalTask],
        focusBlocks: [FocusBlock]
    ) -> Double? {
        var actualSecondsByTask: [String: Int] = [:]
        for block in focusBlocks {
            for (taskID, seconds) in block.taskTimes {
                actualSecondsByTask[taskID, default: 0] += seconds
            }
        }

        var ratios: [Double] = []
        for task in tasks {
            guard let estimatedMinutes = task.estimatedDuration,
                  estimatedMinutes > 0,
                  let actualSeconds = actualSecondsByTask[task.id],
                  actualSeconds > 0
            else { continue }

            let estimatedSeconds = Double(estimatedMinutes) * 60.0
            ratios.append(Double(actualSeconds) / estimatedSeconds)
        }

        guard ratios.count >= minTasksForEstimation else { return nil }

        return ratios.reduce(0, +) / Double(ratios.count)
    }

    // MARK: - Helpers

    /// Ordnet einen Zeitpunkt einem Tageszeit-Fenster zu.
    static func dayPeriod(for date: Date) -> DayPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12:  return .morning
        case 12..<18: return .afternoon
        default:      return .evening
        }
    }
}
