import Foundation
import SwiftData

/// Handles recurring task instance generation when a task is completed.
/// Stateless enum - all methods are static.
enum RecurrenceService {

    /// Calculates the next due date based on recurrence pattern.
    /// - Parameters:
    ///   - pattern: Recurrence pattern string (none/daily/weekly/biweekly/monthly/custom)
    ///   - weekdays: Selected weekdays for weekly/biweekly (1=Mon...7=Sun)
    ///   - monthDay: Day of month for monthly (1-31, 32=last day)
    ///   - interval: Custom interval multiplier (nil or 1 = default). E.g. 3 = "every 3 days"
    ///   - baseDate: Starting date (typically the completed task's dueDate or today)
    /// - Returns: Next due date, or nil if pattern is "none"
    static func nextDueDate(
        pattern: String,
        weekdays: [Int]?,
        monthDay: Int?,
        interval: Int? = nil,
        from baseDate: Date
    ) -> Date? {
        let cal = Calendar.current
        let n = max(interval ?? 1, 1)

        switch pattern {
        case "daily":
            return cal.date(byAdding: .day, value: n, to: baseDate)

        case "weekdays":
            return nextWeekdayDate(from: baseDate, weekdays: [1, 2, 3, 4, 5], weeksToAdd: 0)

        case "weekends":
            return nextWeekdayDate(from: baseDate, weekdays: [6, 7], weeksToAdd: 0)

        case "weekly":
            return nextWeekdayDate(from: baseDate, weekdays: weekdays, weeksToAdd: n - 1)
                ?? cal.date(byAdding: .day, value: 7 * n, to: baseDate)

        case "biweekly":
            return nextWeekdayDate(from: baseDate, weekdays: weekdays, weeksToAdd: 1)
                ?? cal.date(byAdding: .day, value: 14, to: baseDate)

        case "monthly":
            return nextMonthlyDate(from: baseDate, monthDay: monthDay, monthsToAdd: n)

        case "quarterly":
            return cal.date(byAdding: .month, value: 3, to: baseDate)

        case "semiannually":
            return cal.date(byAdding: .month, value: 6, to: baseDate)

        case "yearly":
            return cal.date(byAdding: .year, value: n, to: baseDate)

        case "custom":
            // Custom pattern stores base frequency in monthDay: 1001=daily, 1002=weekly, 1003=monthly, 1004=yearly
            let basePattern: String
            switch monthDay {
            case 1001: basePattern = "daily"
            case 1002: basePattern = "weekly"
            case 1003: basePattern = "monthly"
            case 1004: basePattern = "yearly"
            default: basePattern = "daily"
            }
            return nextDueDate(pattern: basePattern, weekdays: weekdays, monthDay: nil, interval: interval, from: baseDate)

        default:
            return nil
        }
    }

    /// Creates a new task instance for a recurring series.
    /// Robust replacement for the legacy fragile logic, delegates to ensureNextInstance.
    /// Returns nil if the task is not recurring (pattern == "none").
    @MainActor
    @discardableResult
    static func createNextInstance(
        from completedTask: LocalTask,
        in modelContext: ModelContext
    ) -> LocalTask? {
        return ensureNextInstance(for: completedTask, in: modelContext)
    }

    /// Robust successor creation for a recurring task. Fixes RC-1/RC-2/RC-3 from Bug #315.
    /// Returns nil only when the series is intentionally ended (recurrencePattern == "none").
    @MainActor
    @discardableResult
    static func ensureNextInstance(for task: LocalTask, in modelContext: ModelContext) -> LocalTask? {
        guard task.recurrencePattern != "none" else { return nil }

        // RC-1: fall back to today when dueDate is nil — no silent nil-return
        let baseDate = task.dueDate ?? Date()
        guard let newDueDate = nextDueDate(
            pattern: task.recurrencePattern,
            weekdays: task.recurrenceWeekdays,
            monthDay: task.recurrenceMonthDay,
            interval: task.recurrenceInterval,
            from: baseDate
        ) else { return nil }

        // Lazy groupID assignment for legacy tasks
        let groupID: String
        if let existing = task.recurrenceGroupID {
            groupID = existing
        } else {
            groupID = UUID().uuidString
            task.recurrenceGroupID = groupID
        }

        // Dedup: bail if open instance for this date already exists
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: newDueDate)
        if let _ = findOpenInstance(groupID: groupID, targetDay: targetDay, calendar: cal, in: modelContext) {
            return nil
        }

        // RC-2: lazy template creation — missing template is a data error, not user intent
        let source: LocalTask
        if let existing = findTemplate(groupID: groupID, in: modelContext) {
            source = existing
        } else {
            let newTemplate = createTemplateFrom(task, groupID: groupID)
            modelContext.insert(newTemplate)
            source = newTemplate
        }

        let instance = LocalTask(
            title: source.title,
            importance: source.importance,
            tags: source.tags,
            dueDate: newDueDate,
            estimatedDuration: source.estimatedDuration,
            urgency: source.urgency,
            taskType: source.taskType,
            recurrencePattern: source.recurrencePattern,
            recurrenceWeekdays: source.recurrenceWeekdays,
            recurrenceMonthDay: source.recurrenceMonthDay,
            recurrenceInterval: source.recurrenceInterval,
            recurrenceGroupID: groupID,
            taskDescription: source.taskDescription
        )
        modelContext.insert(instance)
        return instance
    }

    /// Finds an existing open instance for a specific date in a recurring series.
    @MainActor
    private static func findOpenInstance(
        groupID: String,
        targetDay: Date,
        calendar: Calendar,
        in modelContext: ModelContext
    ) -> LocalTask? {
        let gid = groupID // Explicit capture
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> {
                $0.recurrenceGroupID == gid && $0.isCompleted == false && $0.isTemplate == false
            }
        )
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.first { task in
            guard let due = task.dueDate else { return false }
            return calendar.startOfDay(for: due) == targetDay
        }
    }

    /// Finds the template (mother instance) for a recurring series.
    @MainActor
    static func findTemplate(groupID: String, in modelContext: ModelContext) -> LocalTask? {
        let gid = groupID // Explicit capture
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> {
                $0.recurrenceGroupID == gid && $0.isTemplate == true
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Template Migration

    /// One-time migration: creates a template (mother instance) for each recurring series
    /// that doesn't have one yet. Idempotent — skips series that already have a template.
    @MainActor
    @discardableResult
    static func migrateToTemplateModel(in modelContext: ModelContext) -> Int {
        // No UserDefaults guard — runs every app start.
        // Already idempotent: skips series that have a template.
        // Cheap: one fetch + in-memory check per series.

        // Fetch all incomplete recurring tasks (candidates for template creation)
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && $0.recurrencePattern != "none" }
        )
        guard let recurringTasks = try? modelContext.fetch(descriptor) else {
            print("[TemplateMigration] Fetch failed — no recurring tasks found")
            return 0
        }
        guard !recurringTasks.isEmpty else {
            print("[TemplateMigration] No incomplete recurring tasks — nothing to migrate")
            return 0
        }

        let existingTemplates = recurringTasks.filter { $0.isTemplate }
        let existingChildren = recurringTasks.filter { !$0.isTemplate }
        print("[TemplateMigration] Found \(recurringTasks.count) recurring tasks (\(existingTemplates.count) templates, \(existingChildren.count) children)")

        // Group by recurrenceGroupID
        var groupedByID: [String: [LocalTask]] = [:]
        var tasksWithoutGroupID: [LocalTask] = []

        for task in recurringTasks {
            if let gid = task.recurrenceGroupID {
                // Include templates in group so the dedup check below finds them
                groupedByID[gid, default: []].append(task)
            } else if !task.isTemplate {
                tasksWithoutGroupID.append(task)
            }
        }

        print("[TemplateMigration] \(groupedByID.count) groups with ID, \(tasksWithoutGroupID.count) tasks without groupID")

        var created = 0

        // For tasks without groupID: assign one and create template
        for task in tasksWithoutGroupID {
            let gid = UUID().uuidString
            task.recurrenceGroupID = gid
            let template = createTemplateFrom(task, groupID: gid)
            modelContext.insert(template)
            created += 1
            print("[TemplateMigration] Created template for '\(task.title)' (no groupID, new gid: \(gid.prefix(8))...)")
        }

        // For groups with groupID: create template if none exists
        for (gid, tasks) in groupedByID {
            // Check if template already exists
            if tasks.contains(where: { $0.isTemplate }) {
                print("[TemplateMigration] Skipping group \(gid.prefix(8))... — template exists")
                continue
            }

            // Use the oldest open task as the source
            let source = tasks.sorted(by: { $0.createdAt < $1.createdAt }).first!
            let template = createTemplateFrom(source, groupID: gid)
            modelContext.insert(template)
            created += 1
            print("[TemplateMigration] Created template for '\(source.title)' (group: \(gid.prefix(8))...)")
        }

        if created > 0 {
            do {
                try modelContext.save()
                print("[TemplateMigration] ✅ Saved \(created) new template(s)")
            } catch {
                print("[TemplateMigration] ❌ SAVE FAILED: \(error)")
            }
        } else {
            print("[TemplateMigration] No new templates needed — all series already have templates")
        }

        // DIAGNOSTIC: List all templates for debugging duplicate analysis
        dumpTemplates(in: modelContext)

        return created
    }

    /// Diagnostic: prints all templates grouped by title+pattern to identify duplicates.
    /// Remove after bug-wiederkehrend-duplicates is resolved.
    @MainActor
    static func dumpTemplates(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isTemplate && !$0.isCompleted }
        )
        guard let templates = try? modelContext.fetch(descriptor) else {
            print("[TemplateDiag] ❌ Fetch failed")
            return
        }

        print("[TemplateDiag] === ALLE TEMPLATES (\(templates.count) total) ===")

        // Group by title + pattern to find duplicates
        var grouped: [String: [(groupID: String, pattern: String, interval: Int?, weekdays: [Int]?, monthDay: Int?)]] = [:]
        for t in templates {
            let key = "\(t.title)||\(t.recurrencePattern)"
            grouped[key, default: []].append((
                groupID: t.recurrenceGroupID ?? "nil",
                pattern: t.recurrencePattern,
                interval: t.recurrenceInterval,
                weekdays: t.recurrenceWeekdays,
                monthDay: t.recurrenceMonthDay
            ))
        }

        for (key, entries) in grouped.sorted(by: { $0.key < $1.key }) {
            let isDuplicate = entries.count > 1 ? " ⚠️ DUPLIKAT" : ""
            print("[TemplateDiag] \(key) — \(entries.count) template(s)\(isDuplicate)")
            for e in entries {
                var details = "  groupID=\(e.groupID.prefix(8))..."
                if let i = e.interval, i > 1 { details += " interval=\(i)" }
                if let w = e.weekdays, !w.isEmpty { details += " weekdays=\(w)" }
                if let m = e.monthDay { details += " monthDay=\(m)" }
                print("[TemplateDiag]   \(details)")
            }
        }

        let uniqueKeys = grouped.count
        let duplicateKeys = grouped.filter { $0.value.count > 1 }.count
        print("[TemplateDiag] === SUMMARY: \(templates.count) templates, \(uniqueKeys) unique series, \(duplicateKeys) with duplicates ===")
    }

    // MARK: - Template Deduplication

    /// Consolidates duplicate templates into one per series (grouped by title).
    /// Historical bug: 3 independent code paths generated different GroupIDs for the same
    /// logical series, resulting in multiple templates per series.
    /// Returns the number of deleted duplicate templates.
    @MainActor
    @discardableResult
    static func deduplicateTemplates(in modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isTemplate && !$0.isCompleted }
        )
        guard let templates = try? modelContext.fetch(descriptor), templates.count > 1 else {
            return 0
        }

        // Group by title (NOT title+pattern, because pattern can change over time)
        var grouped: [String: [LocalTask]] = [:]
        for t in templates {
            grouped[t.title, default: []].append(t)
        }

        var deleted = 0

        for (title, group) in grouped {
            guard group.count > 1 else { continue }

            // Keep newest template (has most current recurrence settings)
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            let survivor = sorted.last!
            let duplicates = sorted.dropLast()

            print("[Dedup] \(title): \(group.count) templates → keeping \(survivor.recurrenceGroupID?.prefix(8) ?? "nil")...")

            // Reassign ALL children of duplicate templates to survivor's GroupID
            for dup in duplicates {
                guard let oldGroupID = dup.recurrenceGroupID,
                      let newGroupID = survivor.recurrenceGroupID else { continue }

                let childDescriptor = FetchDescriptor<LocalTask>(
                    predicate: #Predicate<LocalTask> {
                        $0.recurrenceGroupID == oldGroupID && !$0.isTemplate
                    }
                )
                if let children = try? modelContext.fetch(childDescriptor) {
                    for child in children {
                        child.recurrenceGroupID = newGroupID
                    }
                    if !children.isEmpty {
                        print("[Dedup]   Reassigned \(children.count) children from \(oldGroupID.prefix(8))... → \(newGroupID.prefix(8))...")
                    }
                }

                modelContext.delete(dup)
                deleted += 1
            }
        }

        if deleted > 0 {
            try? modelContext.save()
            print("[Dedup] ✅ Deleted \(deleted) duplicate templates")
        }

        return deleted
    }

    /// Creates a template LocalTask from an existing recurring task.
    private static func createTemplateFrom(_ source: LocalTask, groupID: String) -> LocalTask {
        let template = LocalTask(
            title: source.title,
            importance: source.importance,
            tags: source.tags,
            dueDate: nil, // Templates have no due date
            estimatedDuration: source.estimatedDuration,
            urgency: source.urgency,
            taskType: source.taskType,
            recurrencePattern: source.recurrencePattern,
            recurrenceWeekdays: source.recurrenceWeekdays,
            recurrenceMonthDay: source.recurrenceMonthDay,
            recurrenceInterval: source.recurrenceInterval,
            recurrenceGroupID: groupID,
            taskDescription: source.taskDescription
        )
        template.isTemplate = true
        return template
    }

    // MARK: - Child Instance Deduplication

    /// Removes duplicate open child instances within the same series and date.
    /// After deduplicateTemplates() reassigns children from deleted templates to the survivor,
    /// multiple open instances can exist for the same (groupID, dueDate). This function
    /// keeps the oldest instance per group and deletes the rest.
    /// Returns the number of deleted duplicates.
    @MainActor
    @discardableResult
    static func deduplicateChildInstances(in modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate }
        )
        guard let openChildren = try? modelContext.fetch(descriptor) else { return 0 }

        let recurring = openChildren.filter { $0.recurrenceGroupID != nil && $0.recurrencePattern != "none" }
        guard recurring.count > 1 else { return 0 }

        let cal = Calendar.current
        // Group by (recurrenceGroupID, startOfDay(dueDate))
        var groups: [String: [LocalTask]] = [:]
        for task in recurring {
            guard let gid = task.recurrenceGroupID, let due = task.dueDate else { continue }
            let key = "\(gid)_\(cal.startOfDay(for: due).timeIntervalSince1970)"
            groups[key, default: []].append(task)
        }

        var deleted = 0
        for (_, group) in groups where group.count > 1 {
            // Keep oldest (earliest createdAt), delete rest
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            for duplicate in sorted.dropFirst() {
                print("[ChildDedup] Deleting duplicate '\(duplicate.title)' (created: \(duplicate.createdAt), due: \(duplicate.dueDate?.description ?? "nil"))")
                modelContext.delete(duplicate)
                deleted += 1
            }
        }

        if deleted > 0 {
            try? modelContext.save()
            print("[ChildDedup] Deleted \(deleted) duplicate child instance(s)")
        }

        return deleted
    }

    // MARK: - Repair Orphaned Series

    /// Finds completed recurring tasks whose series has no open successor,
    /// and creates the missing next instance for each.
    /// Returns the number of repaired series.
    @MainActor
    @discardableResult
    static func repairOrphanedRecurringSeries(in modelContext: ModelContext) -> Int {
        // 1. Fetch all completed recurring tasks
        let completedDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isCompleted }
        )
        guard let completedTasks = try? modelContext.fetch(completedDescriptor) else { return 0 }

        let recurringCompleted = completedTasks.filter { $0.recurrencePattern != "none" }
        guard !recurringCompleted.isEmpty else { return 0 }

        // 2. Fetch all open instance tasks (excluding templates) to find existing successors
        let openDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate }
        )
        let openTasks = (try? modelContext.fetch(openDescriptor)) ?? []

        var openGroupIDs = Set<String>()
        for task in openTasks {
            if let gid = task.recurrenceGroupID { openGroupIDs.insert(gid) }
        }

        // 3. For each orphaned series, create successor from most recent completion
        var seenGroupIDs = Set<String>()
        var repaired = 0
        var anySkippedDateReset = false

        let sorted = recurringCompleted.sorted {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }

        for task in sorted {
            guard let groupID = task.recurrenceGroupID else { continue }
            guard !seenGroupIDs.contains(groupID) else { continue }
            seenGroupIDs.insert(groupID)

            guard !openGroupIDs.contains(groupID) else { continue }

            // RC-2 fix: missing template is a data error, not user intent.
            // ensureNextInstance creates a lazy template if needed.
            // lastSkippedDate check still applies when a template exists.
            if let template = findTemplate(groupID: groupID, in: modelContext) {
                // Bug #209 / Bug #KlavierSpielen: Don't repair if user manually deleted an instance
                // within the current recurrence cycle.
                if let skippedDate = template.lastSkippedDate {
                    let reference = task.completedAt ?? .distantPast
                    if skippedDate > reference {
                        let cycleSeconds = cycleLength(
                            pattern: template.recurrencePattern,
                            interval: template.recurrenceInterval
                        )
                        let elapsed = Date().timeIntervalSince(skippedDate)
                        if elapsed < cycleSeconds {
                            continue  // Still within the cycle — honour the deletion
                        }
                        // Cycle has passed — reset the skip marker and allow repair
                        template.lastSkippedDate = nil
                        anySkippedDateReset = true
                    }
                }
            }

            if let _ = ensureNextInstance(for: task, in: modelContext) {
                repaired += 1
            }
        }

        if repaired > 0 || anySkippedDateReset { try? modelContext.save() }
        return repaired
    }

    // MARK: - Cleanup Duplicate Open Instances

    /// Removes duplicate open instances that have the same title (created by the groupID-fallback bug).
    /// For each title with > 1 open instance, keeps the one with the earliest dueDate, deletes the rest.
    /// Returns the number of deleted tasks.
    @MainActor
    @discardableResult
    static func cleanupDuplicateOpenInstances(in modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate }
        )
        guard let openTasks = try? modelContext.fetch(descriptor) else { return 0 }

        // Group by title — tasks with the same title are candidates for deduplication
        var byTitle: [String: [LocalTask]] = [:]
        for task in openTasks {
            byTitle[task.title, default: []].append(task)
        }

        var deleted = 0
        for (_, tasks) in byTitle where tasks.count > 1 {
            // Keep the one with the earliest dueDate; delete the rest
            let sorted = tasks.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            for task in sorted.dropFirst() {
                modelContext.delete(task)
                deleted += 1
            }
        }

        if deleted > 0 { try? modelContext.save() }
        return deleted
    }

    // MARK: - Legacy Migration

    /// One-time migration: groups completed legacy recurring tasks (those without a recurrenceGroupID)
    /// by title+pattern, assigns a shared groupID to each group, and creates one open successor.
    /// Skips groups that already have an open instance with the same title.
    /// Safe to call multiple times (idempotent).
    @MainActor
    @discardableResult
    static func migrateLegacyTasksWithoutGroupID(in modelContext: ModelContext) -> Int {
        let completedDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isCompleted && $0.recurrenceGroupID == nil }
        )
        guard let legacyTasks = try? modelContext.fetch(completedDescriptor),
              !legacyTasks.isEmpty else { return 0 }

        let recurring = legacyTasks.filter { $0.recurrencePattern != "none" }
        guard !recurring.isEmpty else { return 0 }

        // Build set of existing open task titles to avoid duplicates
        let openDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate }
        )
        let existingOpenTitles = Set((try? modelContext.fetch(openDescriptor))?.map(\.title) ?? [])

        // Group by title+pattern (best proxy for "same series" in legacy data)
        var groups: [String: [LocalTask]] = [:]
        for task in recurring {
            let key = "\(task.title)|\(task.recurrencePattern)"
            groups[key, default: []].append(task)
        }

        var migrated = 0
        for (_, tasks) in groups {
            guard let representative = tasks.max(by: {
                ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
            }) else { continue }

            // Skip if an open instance with this title already exists
            if existingOpenTitles.contains(representative.title) { continue }

            // Assign same groupID to all tasks in this cluster
            let groupID = UUID().uuidString
            for task in tasks { task.recurrenceGroupID = groupID }

            if ensureNextInstance(for: representative, in: modelContext) != nil {
                migrated += 1
            }
        }

        if migrated > 0 { try? modelContext.save() }
        return migrated
    }

    // MARK: - Consolidate Multiple Instances

    /// Removes excess open instances within the same recurring series.
    /// Keeps the instance with the earliest dueDate per recurrenceGroupID,
    /// deletes the rest. Returns the number of deleted instances.
    @MainActor
    @discardableResult
    static func consolidateMultipleInstances(in modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> {
                !$0.isCompleted && !$0.isTemplate
            }
        )
        guard let openTasks = try? modelContext.fetch(descriptor) else { return 0 }

        // Only recurring tasks with a groupID
        let recurring = openTasks.filter {
            $0.recurrenceGroupID != nil && $0.recurrencePattern != "none"
        }

        // Group by recurrenceGroupID
        var groups: [String: [LocalTask]] = [:]
        for task in recurring {
            guard let gid = task.recurrenceGroupID else { continue }
            groups[gid, default: []].append(task)
        }

        var deleted = 0
        for (_, group) in groups where group.count > 1 {
            // Keep the instance with the earliest dueDate
            let sorted = group.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            for excess in sorted.dropFirst() {
                modelContext.delete(excess)
                deleted += 1
            }
        }

        if deleted > 0 {
            try? modelContext.save()
            print("[Consolidate] Deleted \(deleted) excess recurring instance(s)")
        }

        return deleted
    }

    /// Returns the approximate cycle length in seconds for a recurrence pattern.
    /// Used to determine when a manual deletion (lastSkippedDate) has "expired".
    private static func cycleLength(pattern: String, interval: Int?) -> TimeInterval {
        let n = Double(max(interval ?? 1, 1))
        switch pattern {
        case "daily":        return n * 86400
        case "weekdays",
             "weekends":     return 86400
        case "weekly":       return n * 7 * 86400
        case "biweekly":     return 14 * 86400
        case "monthly":      return n * 30 * 86400
        case "quarterly":    return 90 * 86400
        case "semiannually": return 180 * 86400
        case "yearly":       return n * 365 * 86400
        default:             return 86400
        }
    }

    // MARK: - Private Helpers

    /// Finds the next matching weekday after baseDate.
    /// weeksToAdd: 0 for weekly, 1 for biweekly (adds extra week)
    private static func nextWeekdayDate(from baseDate: Date, weekdays: [Int]?, weeksToAdd: Int) -> Date? {
        guard let weekdays = weekdays, !weekdays.isEmpty else { return nil }

        let cal = Calendar.current
        // Convert our 1=Mon...7=Sun to Calendar weekday (1=Sun, 2=Mon...7=Sat)
        let currentCalWeekday = cal.component(.weekday, from: baseDate)
        // Our system: 1=Mon, 2=Tue, ..., 7=Sun
        // Calendar:   2=Mon, 3=Tue, ..., 7=Sat, 1=Sun
        let currentOurWeekday = currentCalWeekday == 1 ? 7 : currentCalWeekday - 1

        let sorted = weekdays.sorted()

        // First try: find a later day this week
        if let nextDay = sorted.first(where: { $0 > currentOurWeekday }) {
            let daysAhead = nextDay - currentOurWeekday + (weeksToAdd * 7)
            return cal.date(byAdding: .day, value: daysAhead, to: baseDate)
        }

        // Wrap around: first day of next cycle
        if let firstDay = sorted.first {
            let daysAhead = (7 - currentOurWeekday) + firstDay + (weeksToAdd * 7)
            return cal.date(byAdding: .day, value: daysAhead, to: baseDate)
        }

        return nil
    }

    /// Calculates the next monthly date.
    private static func nextMonthlyDate(from baseDate: Date, monthDay: Int?, monthsToAdd: Int = 1) -> Date? {
        let cal = Calendar.current
        guard let advancedDate = cal.date(byAdding: .month, value: monthsToAdd, to: baseDate) else {
            return nil
        }
        var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: advancedDate)

        if let day = monthDay {
            if day == 32 {
                // Last day of month
                components.day = 1
                if let firstOfMonth = cal.date(from: components),
                   let endOfMonth = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth) {
                    return endOfMonth
                }
            } else {
                // Specific day, clamped to month length
                components.day = 1
                if let firstOfMonth = cal.date(from: components),
                   let range = cal.range(of: .day, in: .month, for: firstOfMonth) {
                    components.day = min(day, range.count)
                }
            }
        }

        return cal.date(from: components)
    }
}
