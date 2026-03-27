import Foundation
import SwiftData

enum FailureProtocolService {

    /// Speichert einen Failure-Record. Append-only, nie loeschen.
    /// Prueft Duplikate: gleicher taskID + gleiches Datum = kein Insert.
    static func save(
        taskID: String,
        reason: FailureReason,
        context: ModelContext,
        date: Date = Date()
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<TaskFailureRecord>(
            predicate: #Predicate<TaskFailureRecord> { record in
                record.taskID == taskID &&
                record.date >= startOfDay &&
                record.date < endOfDay
            }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let record = TaskFailureRecord(taskID: taskID, date: date, reason: reason)
        context.insert(record)
        try? context.save()
    }

    /// Holt alle Failure-Records fuer ein bestimmtes Datum.
    static func fetchForDate(
        _ date: Date,
        context: ModelContext
    ) -> [TaskFailureRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<TaskFailureRecord>(
            predicate: #Predicate<TaskFailureRecord> { record in
                record.date >= startOfDay && record.date < endOfDay
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
