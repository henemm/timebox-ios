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
    static let minDaysForMeetingLoad: Int = 3
    static let minTotalDaysForCalendarCorrelation: Int = 5
    static let minTasksForProcrastination: Int = 3

    // MARK: - Public API

    /// Gibt das gecachte Profil zurück oder berechnet es neu.
    /// Cache wird invalidiert wenn computedAt von einem anderen Kalendertag ist.
    static func profile(
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        calendarEvents: [CalendarEvent] = [],
        now: Date = Date()
    ) -> BehavioralProfile {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        if let cached = _cache,
           calendar.startOfDay(for: cached.date) == today {
            return cached.profile
        }

        let computed = compute(tasks: tasks, focusBlocks: focusBlocks, calendarEvents: calendarEvents, now: now)
        _cache = (profile: computed, date: now)
        return computed
    }

    /// Berechnet ein frisches Profil ohne Cache (für Tests und erzwungene Neuberechnung).
    static func compute(
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        calendarEvents: [CalendarEvent] = [],
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
            estimationFactor: computeEstimationFactor(from: windowedTasks, focusBlocks: focusBlocks),
            capacityByMeetingLoad: computeCapacityByMeetingLoad(from: windowedTasks, calendarEvents: calendarEvents, now: now),
            procrastinationPatterns: computeProcrastinationPatterns(from: tasks)
        )
    }

    /// Loescht den in-memory Cache.
    static func invalidateCache() {
        _cache = nil
    }

    // MARK: - Komponente 1: Tageszeit-Affinitaet

    /// Berechnet für jede Kategorie den Anteil pro Tageszeit-Fenster.
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

    // MARK: - Komponente 4: Kalender-Korrelation

    /// Durchschnittliche Task-Completion pro Meeting-Dichte-Bucket.
    static func computeCapacityByMeetingLoad(
        from tasks: [LocalTask],
        calendarEvents: [CalendarEvent],
        now: Date = Date()
    ) -> [MeetingLoad: Double]? {
        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -28, to: now) ?? now
        )

        // Tasks pro Tag zaehlen
        var tasksByDay: [Date: Int] = [:]
        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            let day = calendar.startOfDay(for: completedAt)
            tasksByDay[day, default: 0] += 1
        }

        // Non-allDay Events pro Tag zaehlen
        var meetingsByDay: [Date: Int] = [:]
        for event in calendarEvents where !event.isAllDay {
            let day = calendar.startOfDay(for: event.startDate)
            guard day >= windowStart && day <= now else { continue }
            meetingsByDay[day, default: 0] += 1
        }

        // Nur Tage mit sowohl Tasks als auch Events
        let daysWithBoth = Set(tasksByDay.keys).intersection(Set(meetingsByDay.keys))
        guard daysWithBoth.count >= minTotalDaysForCalendarCorrelation else { return nil }

        // Pro MeetingLoad-Bucket: Tasks sammeln
        var bucketTasks: [MeetingLoad: [Int]] = [:]
        for day in daysWithBoth {
            let load = meetingLoad(for: meetingsByDay[day] ?? 0)
            bucketTasks[load, default: []].append(tasksByDay[day] ?? 0)
        }

        // Nur Buckets mit genug Tagen aufnehmen
        var result: [MeetingLoad: Double] = [:]
        for (load, taskCounts) in bucketTasks {
            guard taskCounts.count >= minDaysForMeetingLoad else { continue }
            let total = taskCounts.reduce(0, +)
            result[load] = Double(total) / Double(taskCounts.count)
        }

        return result.isEmpty ? nil : result
    }

    /// Klassifiziert Meeting-Anzahl in MeetingLoad-Bucket.
    static func meetingLoad(for count: Int) -> MeetingLoad {
        switch count {
        case 0...2: return .low
        case 3...4: return .medium
        default:    return .high
        }
    }

    // MARK: - Komponente 5: Verschiebungs-Muster

    /// Clustert Tasks mit rescheduleCount >= 3 nach Kategorie.
    /// Kein 28-Tage-Fenster — alle Tasks (completed + nicht-completed).
    static func computeProcrastinationPatterns(
        from allTasks: [LocalTask]
    ) -> [ProcrastinationPattern]? {
        let chronic = allTasks.filter { $0.rescheduleCount >= 3 }
        guard chronic.count >= minTasksForProcrastination else { return nil }

        // Gruppierung nach Kategorie
        var groups: [TaskCategory?: [LocalTask]] = [:]
        for task in chronic {
            let category = TaskCategory(rawValue: task.taskType)
            groups[category, default: []].append(task)
        }

        // Pro Gruppe ein Pattern erstellen
        var patterns: [ProcrastinationPattern] = []
        for (category, tasks) in groups {
            let avgReschedule = Double(tasks.map(\.rescheduleCount).reduce(0, +)) / Double(tasks.count)
            let withImportance = tasks.compactMap(\.importance)
            let avgImportance: Double? = withImportance.isEmpty
                ? nil
                : Double(withImportance.reduce(0, +)) / Double(withImportance.count)

            patterns.append(ProcrastinationPattern(
                category: category,
                taskCount: tasks.count,
                avgRescheduleCount: avgReschedule,
                avgImportance: avgImportance
            ))
        }

        return patterns.sorted { $0.taskCount > $1.taskCount }
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
