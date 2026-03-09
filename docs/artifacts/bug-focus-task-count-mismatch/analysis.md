# Bug Analysis: Focus View Task Count Mismatch

**Date:** 2026-03-09
**Reporter:** Henning
**Platform:** iOS (macOS hat identisches Pattern)
**Related:** Bug 81 (FocusBlock Task Disappearing)

## Symptom

Focus View zeigt gleichzeitig:
- Header: **"2/3 Tasks"** (1 Task noch offen)
- Content: **"Alle Tasks erledigt!"** (alle fertig)

Widerspruch: Der 3. Task ist weder als offen sichtbar noch als erledigt gezaehlt.

## Root Cause: Zwei verschiedene Datenquellen

### Header-Counter (FocusLiveView.swift:286)
```swift
Text("\(tasksForBlock(block).filter { block.completedTaskIDs.contains($0.id) }.count)/\(block.taskIDs.count) Tasks")
```
- **Zaehler (Numerator):** `tasksForBlock(block)` → haengt von `allTasks` ab (SwiftData)
- **Nenner (Denominator):** `block.taskIDs.count` → kommt direkt aus FocusBlock (EventKit)

### "Alle Tasks erledigt!" Check (FocusLiveView.swift:199-212)
```swift
let tasks = tasksForBlock(block)  // compactMap ueber allTasks
let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
let currentTask = remainingTasks.first
if let task = currentTask { ... } else { allTasksCompletedView(block: block) }
```

### `tasksForBlock()` (FocusLiveView.swift:498-502)
```swift
private func tasksForBlock(_ block: FocusBlock) -> [PlanItem] {
    block.taskIDs.compactMap { taskID in
        allTasks.first { $0.id == taskID }  // compactMap SCHLUCKT fehlende Tasks
    }
}
```

### Das Problem

`block.taskIDs` = ["task1", "task2", "task3"] (3 IDs in EventKit)
`block.completedTaskIDs` = ["task1", "task2"]
`allTasks` (SwiftData) = [task1, task2] → **task3 existiert NICHT in SwiftData**

1. **Header:** `tasksForBlock()` findet 2 Tasks, davon 2 completed → Numerator = 2. Denominator = `block.taskIDs.count` = 3. Ergebnis: **"2/3 Tasks"**
2. **Content:** `tasksForBlock()` findet 2 Tasks, filter nicht-completed = leer → **"Alle Tasks erledigt!"**

**Der Nenner vertraut blind auf `block.taskIDs.count` (EventKit), aber die Logik nutzt `compactMap` das fehlende Tasks stumm verschluckt.**

## Hypothesen: WARUM fehlt der 3. Task in SwiftData?

### Hypothese 1: Task wurde aus dem Backlog geloescht (HOCH)
- User hat Task per Swipe-Delete geloescht waehrend er einem FocusBlock zugewiesen war
- `SyncEngine.deleteTask()` und `LocalTaskSource.deleteTask()` loeschen NUR aus SwiftData
- **Kein Code raeumt block.taskIDs in EventKit auf** — Task-ID bleibt als verwaiste Referenz
- **Beweis:** Beide delete-Funktionen haben KEINEN Cleanup fuer FocusBlock-Referenzen

### Hypothese 2: Recurring Series geloescht (MITTEL)
- `deleteRecurringSeries()` loescht alle offenen Tasks einer Serie
- Wenn ein offener Recurring-Task einem FocusBlock zugewiesen war → verwaiste Referenz
- Gleicher Mechanismus wie Hypothese 1

### Hypothese 3: Dedup-Logik hat Task geloescht (MITTEL)
- `FocusBloxApp.deduplicateTasks()` loescht Duplikate basierend auf externalID
- Koennte einen Task loeschen der einem FocusBlock zugewiesen ist
- Gleicher Mechanismus wie Hypothese 1

### Hypothese 4: Bug 81 Stale Snapshot (NIEDRIG fuer dieses Symptom)
- Bug 81 ueberschreibt taskIDs → wuerde taskIDs REDUZIEREN, nicht orphan-IDs erzeugen
- Passt nicht zum Symptom (taskIDs.count = 3 ist korrekt, Task fehlt in SwiftData)

## Eigentlicher Code-Bug

**Unabhaengig davon WARUM der Task fehlt: Die View muss konsistent sein.**

Der Bug ist: `block.taskIDs.count` und `tasksForBlock(block).count` koennen unterschiedliche Werte haben, weil `compactMap` verwaiste IDs verschluckt. Beide Anzeigen muessen dieselbe Quelle nutzen.

## Blast Radius

| Location | File | Betroffen? |
|----------|------|-----------|
| iOS Focus Header | FocusLiveView.swift:286 | JA |
| macOS Focus Header | MacFocusView.swift:190 | JA (identisches Pattern) |
| Live Activity | FocusBlockLiveActivity.swift:54,133 | JA (nutzt totalTaskCount aus block.taskIDs.count) |
| Live Activity Manager | LiveActivityManager.swift:40 | JA (setzt totalTaskCount bei Start) |
| End Notification | NotificationService.swift:246 | JA |
| macOS Menu Bar | MenuBarView.swift:153 | JA |
| Menu Bar Icon State | MenuBarIconState.swift:21-22 | JA |
| Daily Review | DailyReviewView.swift:123,136 | JA |
| Sprint Review | SprintReviewSheet.swift | JA |

**9+ Stellen nutzen `block.taskIDs.count` als "Total" ohne zu pruefen ob die Tasks noch existieren.**

## Fix-Vorschlag

**Zwei Ebenen:**

### A) View-Konsistenz (MUSS)
Counter-Denominator von `block.taskIDs.count` auf `tasksForBlock(block).count` aendern, oder eine konsistente Helper-Property einfuehren die an ALLEN 9+ Stellen genutzt wird.

### B) Datenintegritaet (SOLLTE)
Beim Loeschen eines Tasks (`SyncEngine.deleteTask()`, `LocalTaskSource.deleteTask()`) pruefen ob der Task einem FocusBlock zugewiesen ist und die ID aus `block.taskIDs` entfernen.
