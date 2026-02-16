---
entity_id: recurring-tasks-phase1a
type: feature
created: 2026-02-16
updated: 2026-02-16
status: draft
version: "1.0"
tags: [recurring, completion, badge, phase1a]
---

# Recurring Tasks Phase 1A: Instance Generation + Badge

## Approval

- [ ] Approved

## Purpose

Wenn ein wiederkehrender Task abgehakt wird, soll automatisch eine neue Instanz mit dem naechsten Faelligkeitsdatum erstellt werden. Zusaetzlich soll ein visueller Indikator im Backlog zeigen, welche Tasks wiederkehrend sind.

**Aktuell:** recurrencePattern wird gespeichert aber ignoriert. Completion loescht den Task wie jeden anderen.
**Nachher:** Completion erzeugt neue Instanz mit berechnetem naechsten Datum. Badge zeigt Pattern an.

## Context

- **Context Doc:** `docs/context/recurring-tasks-instance-logic.md`
- **Workflow:** `recurring-tasks-instance-logic`

## Scope

| Metrik | Wert |
|--------|------|
| Dateien | 5 (3 MODIFY, 2 CREATE) |
| LoC (produktiv) | ~110 |
| LoC (Tests) | ~80 |
| Risiko | MEDIUM |

## Affected Files

| File | Change | Description |
|------|--------|-------------|
| `Sources/Services/RecurrenceService.swift` | CREATE | Naechstes-Datum-Berechnung + Instanz-Erstellung |
| `Sources/Services/SyncEngine.swift` | MODIFY | `completeTask()` ruft RecurrenceService auf (~8 LoC) |
| `Sources/Services/FocusBlockActionService.swift` | MODIFY | `completeTask()` ruft RecurrenceService auf (~8 LoC) |
| `Sources/Views/BacklogRow.swift` | MODIFY | Recurrence-Badge in metadataRow (~15 LoC) |
| `FocusBloxTests/RecurrenceServiceTests.swift` | CREATE | Unit Tests fuer Datums-Berechnung (~80 LoC) |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask` | Model | Task mit recurrence-Feldern (existiert) |
| `RecurrencePattern` | Enum | Pattern-Definitionen (existiert) |
| `ModelContext` | SwiftData | Neue Instanz einfuegen |
| `SyncEngine` | Service | Backlog-Completion-Pfad |
| `FocusBlockActionService` | Service | FocusBlock-Completion-Pfad |

## Implementation Details

### 1. RecurrenceService (CREATE)

```swift
// Sources/Services/RecurrenceService.swift
import Foundation
import SwiftData

enum RecurrenceService {

    /// Berechnet das naechste Faelligkeitsdatum basierend auf Pattern.
    /// - from: Ausgangsdatum (dueDate des erledigten Tasks, oder Date() wenn kein dueDate)
    static func nextDueDate(
        pattern: String,
        weekdays: [Int]?,
        monthDay: Int?,
        from baseDate: Date
    ) -> Date?

    /// Erstellt eine neue Task-Instanz als Kopie des erledigten Tasks.
    /// - Kopiert: title, importance, urgency, estimatedDuration, tags, taskType,
    ///   recurrencePattern, recurrenceWeekdays, recurrenceMonthDay, taskDescription
    /// - Setzt: neues UUID, isCompleted=false, completedAt=nil, neues dueDate,
    ///   isNextUp=false, assignedFocusBlockID=nil, neues createdAt
    @MainActor
    static func createNextInstance(
        from completedTask: LocalTask,
        in modelContext: ModelContext
    ) -> LocalTask?
}
```

**Datums-Berechnung:**

| Pattern | Logik |
|---------|-------|
| `none` | return nil (kein naechstes Datum) |
| `daily` | baseDate + 1 Tag |
| `weekly` | Naechster passender Wochentag aus `weekdays`. Wenn weekdays nil/leer: baseDate + 7 Tage |
| `biweekly` | Naechster passender Wochentag + 14 Tage Offset. Wenn weekdays nil/leer: baseDate + 14 Tage |
| `monthly` | Naechster Monat am `monthDay`. Wenn monthDay nil: baseDate + 1 Monat. Wenn monthDay=32: letzter Tag des Monats |

**Basis-Datum:** `completedTask.dueDate ?? Date()`. Wenn dueDate existiert, wird von dort aus gerechnet. Wenn nicht, ab heute.

### 2. SyncEngine Integration (MODIFY)

```swift
// In SyncEngine.completeTask() - NACH task.isCompleted = true
func completeTask(itemID: String) throws {
    guard let task = try findTask(byID: itemID) else { return }
    task.isCompleted = true
    task.completedAt = Date()
    task.assignedFocusBlockID = nil
    task.isNextUp = false

    // NEU: Recurring Task Instanz-Generierung
    if task.recurrencePattern != "none" {
        RecurrenceService.createNextInstance(from: task, in: modelContext)
    }

    try modelContext.save()
}
```

### 3. FocusBlockActionService Integration (MODIFY)

```swift
// In FocusBlockActionService.completeTask() - NACH localTask.isCompleted = true
if let localTasks = try? modelContext.fetch(fetchDescriptor),
   let localTask = localTasks.first(where: { $0.id == taskID }) {
    localTask.isCompleted = true
    localTask.completedAt = Date()
    localTask.assignedFocusBlockID = nil

    // NEU: Recurring Task Instanz-Generierung
    if localTask.recurrencePattern != "none" {
        RecurrenceService.createNextInstance(from: localTask, in: modelContext)
    }

    try? modelContext.save()
}
```

### 4. BacklogRow Recurrence Badge (MODIFY)

In `metadataRow` zwischen `categoryBadge` und Tags einfuegen:

```swift
// Nur sichtbar wenn recurring
if let pattern = item.recurrencePattern, pattern != "none" {
    HStack(spacing: 4) {
        Image(systemName: "arrow.triangle.2.circlepath")
        Text(RecurrencePattern(rawValue: pattern)?.displayName ?? pattern)
            .lineLimit(1)
    }
    .font(.caption2)
    .foregroundStyle(.purple)
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(
        RoundedRectangle(cornerRadius: 6)
            .fill(.purple.opacity(0.2))
    )
}
```

## Expected Behavior

### Szenario 1: Taeglicher Task im Backlog abhaken
- **Input:** User tippt Checkbox auf Task mit `recurrencePattern: "daily"`, `dueDate: 2026-02-16`
- **Output:** Alter Task wird `isCompleted=true`. Neuer Task erscheint mit `dueDate: 2026-02-17`, gleichen Attributen, `isCompleted=false`
- **Visuell:** Neuer Task hat lila Badge "Taeglich" in metadataRow

### Szenario 2: Woechentlicher Task waehrend FocusBlock erledigen
- **Input:** User tippt "Erledigt" in FocusLiveView auf Task mit `recurrencePattern: "weekly"`, `recurrenceWeekdays: [1,3,5]` (Mo/Mi/Fr), heute ist Montag
- **Output:** Alter Task completed. Neuer Task mit `dueDate: Mittwoch` (naechster passender Wochentag)

### Szenario 3: Task ohne dueDate
- **Input:** Recurring daily Task OHNE gesetztes dueDate wird abgehakt
- **Output:** Neuer Task mit `dueDate: morgen` (berechnet ab heute)

### Szenario 4: Normaler Task (nicht recurring)
- **Input:** Task mit `recurrencePattern: "none"` wird abgehakt
- **Output:** Keine Instanz-Generierung. Verhalten wie bisher.

## Test Plan

### Unit Tests (RecurrenceServiceTests)

| # | Test | Erwartung |
|---|------|-----------|
| 1 | `testNextDueDate_daily` | baseDate + 1 Tag |
| 2 | `testNextDueDate_weekly_withWeekdays` | Naechster passender Wochentag |
| 3 | `testNextDueDate_weekly_noWeekdays` | baseDate + 7 Tage |
| 4 | `testNextDueDate_biweekly` | baseDate + 14 Tage |
| 5 | `testNextDueDate_monthly_withMonthDay` | Naechster Monat am Tag X |
| 6 | `testNextDueDate_monthly_lastDay` | monthDay=32 → letzter Tag des naechsten Monats |
| 7 | `testNextDueDate_none` | return nil |
| 8 | `testCreateNextInstance_copiesAttributes` | Alle Attribute kopiert, neues UUID |
| 9 | `testCreateNextInstance_resetsState` | isCompleted=false, completedAt=nil, isNextUp=false |
| 10 | `testCreateNextInstance_nonePattern` | return nil (kein neuer Task) |

### UI Tests

| # | Test | Erwartung |
|---|------|-----------|
| 1 | `testRecurrenceBadgeVisible` | Badge mit "Taeglich" sichtbar auf recurring Task |
| 2 | `testRecurrenceBadgeHidden` | Kein Badge auf nicht-recurring Task |

## Known Limitations

- **Phase 1A deckt nicht ab:** macOS direkte Toggles (TaskInspector, ContentView), Siri/Shortcuts Intent, Delete-Dialog, Backlog-Filterung
- **Keine Dedup-Pruefung:** Wenn SyncEngine UND FocusBlockActionService denselben Task zeitnah completen, koennte theoretisch doppelte Instanz entstehen (unwahrscheinlich da verschiedene Code-Pfade)
- **Kein Template-Konzept:** Tasks sind flach (kein parentTaskID). Jede Instanz ist ein eigenstaendiger Task mit recurrence-Pattern. Serie loeschen = einzeln loeschen.

## Nicht im Scope (Phase 1B/2)

| Feature | Phase |
|---------|-------|
| macOS TaskInspector/ContentView Toggle → RecurrenceService | 1B |
| macOS MacBacklogRow Recurrence Badge | 1B |
| Siri CompleteTaskIntent → RecurrenceService | 1B |
| Delete-Dialog "Nur diese Instanz / Ganze Serie" | 2 |
| Backlog-Filter recurring vs einmalig | 2 |

## Changelog

- 2026-02-16: Initial spec created (Phase 1A)
