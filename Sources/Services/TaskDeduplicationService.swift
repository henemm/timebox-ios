import Foundation
import SwiftData

/// Plattform-uebergreifender Service zum Bereinigen von Task-Duplikaten im SwiftData-Store.
///
/// Beide Apps (iOS + macOS) rufen diesen Service beim Startup auf, um CloudKit-Sync-Artefakte
/// zu bereinigen, die beim Sync zwischen Geraeten entstehen koennen.
/// Hintergrund: `LocalTask` hat keinen `#Unique`-Constraint auf `uuid`, daher koennen
/// CloudKit-Race-Conditions zu doppelten Entries fuehren.
enum TaskDeduplicationService {

    /// Bug 255: Entfernt LocalTask-Duplikate mit identischer UUID (CloudKit-Sync-Artefakt).
    /// Behaelt jeweils die Variante mit den meisten enrichten Attributen, bei Gleichstand die aelteste.
    /// Returns: Anzahl geloeschter Tasks, oder -1 bei Fehler.
    @discardableResult
    static func cleanupUUIDDuplicates(in context: ModelContext) -> Int {
        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            guard allTasks.count > 1 else { return 0 }

            var groups: [UUID: [LocalTask]] = [:]
            for task in allTasks {
                groups[task.uuid, default: []].append(task)
            }

            var deletedCount = 0
            for (_, tasks) in groups where tasks.count > 1 {
                let sorted = tasks.sorted { a, b in
                    let scoreA = Self.attributeScore(a)
                    let scoreB = Self.attributeScore(b)
                    if scoreA != scoreB { return scoreA > scoreB }
                    return a.createdAt < b.createdAt
                }
                for task in sorted.dropFirst() {
                    context.delete(task)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                try context.save()
            }
            return deletedCount
        } catch {
            return -1
        }
    }

    /// Bug 34 v2: Entfernt Reminders-Import-Duplikate (gleiche `externalID`).
    /// Behaelt jeweils die Variante mit den meisten enrichten Attributen, bei Gleichstand die aelteste.
    /// Returns: Anzahl geloeschter Tasks, oder -1 bei Fehler.
    @discardableResult
    static func cleanupRemindersDuplicates(in context: ModelContext) -> Int {
        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            let tasksWithExternalID = allTasks.filter { $0.externalID != nil }
            guard !tasksWithExternalID.isEmpty else { return 0 }

            // Group by externalID
            var groups: [String: [LocalTask]] = [:]
            for task in tasksWithExternalID {
                let key = task.externalID!
                groups[key, default: []].append(task)
            }

            var deletedCount = 0
            for (_, tasks) in groups where tasks.count > 1 {
                // Sort by attribute score descending, then by createdAt ascending (older first)
                let sorted = tasks.sorted { a, b in
                    let scoreA = Self.attributeScore(a)
                    let scoreB = Self.attributeScore(b)
                    if scoreA != scoreB { return scoreA > scoreB }
                    return a.createdAt < b.createdAt
                }
                // Keep first (highest score / oldest), delete rest
                for task in sorted.dropFirst() {
                    context.delete(task)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                try context.save()
            }
            return deletedCount
        } catch {
            return -1
        }
    }

    /// Score how many enrichment attributes a task has filled.
    private static func attributeScore(_ task: LocalTask) -> Int {
        var score = 0
        if task.importance != nil { score += 1 }
        if task.urgency != nil { score += 1 }
        if task.estimatedDuration != nil { score += 1 }
        if !task.taskType.isEmpty { score += 1 }
        if !(task.tags ?? []).isEmpty { score += 1 }
        return score
    }
}
