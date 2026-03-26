import Foundation
import SwiftData

/// Silently resets unfinished Next-Up tasks and clears past scheduled dates
/// on the first app start of each new calendar day.
@MainActor
enum EveningResetService {

    /// Performs the daily reset if today differs from AppSettings.lastResetDate.
    ///
    /// - Parameter context: The main ModelContext (must be on @MainActor).
    /// - Returns: Number of tasks modified (0 = already reset today).
    @discardableResult
    static func performResetIfNeeded(context: ModelContext) throws -> Int {
        let settings = AppSettings.shared
        let today = isoString(for: Date(), resetHour: settings.resetHour)

        // Idempotency guard: already reset today
        guard settings.lastResetDate != today else { return 0 }

        var modifiedCount = 0
        let now = Date()

        // --- Pass 1: Clear Next-Up status from unfinished tasks ---
        let nextUpDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isNextUp == true && $0.isCompleted == false }
        )
        let nextUpTasks = try context.fetch(nextUpDescriptor)
        for task in nextUpTasks {
            task.isNextUp = false
            task.nextUpSortOrder = nil
            task.assignedFocusBlockID = nil
            task.rescheduleCount += 1
            task.modifiedAt = now
            modifiedCount += 1
        }

        // --- Pass 2: Clear scheduledDate that lies before today's start ---
        let startOfDay = Calendar.current.startOfDay(for: now)
        let scheduledDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.scheduledDate != nil && $0.isCompleted == false }
        )
        let scheduledTasks = try context.fetch(scheduledDescriptor)
        for task in scheduledTasks {
            guard let date = task.scheduledDate, date < startOfDay else { continue }
            task.scheduledDate = nil
            task.scheduledDuration = nil
            task.modifiedAt = now
            modifiedCount += 1
        }

        // --- Persist all mutations in one save ---
        if modifiedCount > 0 {
            try context.save()
        }

        // --- Record reset date (even if 0 tasks changed) ---
        settings.lastResetDate = today

        return modifiedCount
    }

    // MARK: - Private Helpers

    /// Returns the ISO-8601 date string for the logical "day",
    /// taking resetHour into account.
    private static func isoString(for date: Date, resetHour: Int) -> String {
        let adjusted: Date
        if resetHour > 0 {
            adjusted = Calendar.current.date(
                byAdding: .hour, value: -resetHour, to: date
            ) ?? date
        } else {
            adjusted = date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = Calendar.current.timeZone
        return formatter.string(from: Calendar.current.startOfDay(for: adjusted))
    }
}
