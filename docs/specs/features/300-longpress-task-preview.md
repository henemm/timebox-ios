---
entity_id: feature_300_longpress_task_preview
type: feature
created: 2026-05-02
updated: 2026-05-02
status: draft
version: "1.0"
tags: [backlog, coach, tagesplan, contextmenu, preview]
---

# Feature #300 — Long Press: Task-Preview-Karte

## Approval

- [ ] Approved

## Purpose

Ein langer Fingerdruck auf einen Task öffnet eine Read-only-Karte mit dem vollständigen Titel und allen Eigenschaften des Tasks. Die Karte schließt sich, sobald der Finger losgelassen wird. Ziel: Schnelles Nachschauen ohne Navigationswechsel.

## Source

- **File:** `Sources/Views/TaskPreviewView.swift` (bestehende Komponente, wird erweitert)
- **Identifier:** `struct TaskPreviewView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `TaskPreviewView` | View | Zeigt vollständige Task-Eigenschaften — wird in alle neuen `.contextMenu(preview:)` Blöcke eingehängt |
| `BacklogView` | View | Erhält `preview:` Block in bestehenden `.contextMenu` der BacklogRow (Hauptliste + Abgeschlossen-Sektion) |
| `CoachView` | View | Erhält `preview:` Block in bestehendem `.contextMenu` der BacklogRow |
| `ScheduledTaskBlock` | View | Erhält neuen optionalen Parameter `task: PlanItem?` und `preview:` Block im `.contextMenu` |
| `PositionedScheduledTask` | Model | Erhält neues optionales Feld `task: PlanItem?` damit der Aufrufer das PlanItem durchreichen kann |
| `BlockPlanningView` | View | Aufrufer von `ScheduledTaskBlock` — muss `task:` befüllen (Lookup via `taskID` aus SwiftData) |
| `TimelineView` | View | Aufrufer von `ScheduledTaskBlock` — muss `task:` befüllen (Lookup via `taskID` aus SwiftData) |

## Acceptance Criteria

1. **Backlog — Hauptliste:** Wenn ich auf einen Task in der Backlog-Hauptliste lange drücke, erscheint eine Karte mit dem vollständigen Titel und allen Eigenschaften (Wichtigkeit, Dringlichkeit, Kategorie, Dauer, Wiederholung, Tags, Fälligkeitsdatum, Beschreibung).
2. **Backlog — Abgeschlossen:** Wenn ich auf einen abgeschlossenen Task lange drücke, erscheint dieselbe Karte.
3. **Coach-Backlog:** Wenn ich auf einen Task in der Coach-Backlog-Liste lange drücke, erscheint dieselbe Karte.
4. **Tagesplan-Block:** Wenn ich auf einen geplanten Task-Block im Tagesplan lange drücke, erscheint dieselbe Karte.
5. **Schließen:** Sobald ich den Finger loslasse, schließt sich die Karte automatisch. Es gibt keinen X-Button.
6. **Read-only:** Ein Tippen auf eine Eigenschaft in der Karte löst keine Aktion aus.
7. **Konsistenz:** Das Verhalten ist auf allen vier Stellen identisch mit dem bestehenden Long-Press in `NextUpSection` und `TaskAssignmentView`.

## Implementation Details

### Pattern (bereits etabliert)

```swift
.contextMenu {
    // bestehende Menüeinträge unverändert
} preview: {
    TaskPreviewView(task: task)
}
```

Dieses Pattern wird in `BacklogView`, `CoachView` und `ScheduledTaskBlock` ergänzt. Bestehende `.contextMenu`-Modifier werden **nicht ersetzt**, sondern um den `preview:`-Parameter erweitert.

### Änderungen im Detail

**`TaskPreviewView.swift`**
- `.accessibilityIdentifier("taskPreviewCard")` auf die Root-`VStack` setzen (Pflicht für UI-Tests).

**`BacklogView.swift`**
- Zeile ~1112 (BacklogRow Hauptliste): `preview: { TaskPreviewView(task: task) }` in das bestehende `.contextMenu` einfügen.
- Zeile ~1469 (BacklogRow Abgeschlossen): ebenso.

**`CoachView.swift`**
- Zeile ~798 (BacklogRow): `preview: { TaskPreviewView(task: task) }` in das bestehende `.contextMenu` einfügen.

**`ScheduledTaskBlock.swift`**
- Neuer optionaler Parameter: `let task: PlanItem?`
- Im `.contextMenu` ergänzen: `preview: { if let t = task { TaskPreviewView(task: t) } }`

**`PositionedScheduledTask` (TimelineItem.swift)**
- Neues optionales Feld: `let task: PlanItem?`

**`BlockPlanningView.swift`**
- In `positionedScheduledTasks`: `PlanItem` per `taskID` aus dem SwiftData-Kontext nachschlagen und in `PositionedScheduledTask.task` befüllen.
- Beim Instanziieren von `ScheduledTaskBlock`: `task: positioned.task` übergeben.

**`TimelineView.swift`**
- Analog zu `BlockPlanningView`: `task:` aus dem übergebenen Kontext nachschlagen und an `ScheduledTaskBlock` weitergeben.

### Wichtig: Nur ein `.contextMenu` pro View

SwiftUI erlaubt genau einen `.contextMenu`-Modifier pro View. Es darf **kein zweiter** `.contextMenu` hinzugefügt werden — der `preview:`-Parameter wird immer in den **bestehenden** Modifier eingehängt.

## Expected Behavior

- **Input:** Langer Fingerdruck auf eine Task-Row oder einen Tagesplan-Block
- **Output:** `TaskPreviewView`-Karte erscheint als iOS-System-Preview (Thumbnail)
- **Side effects:** Keine. Read-only, keine Mutations, kein Navigation-Push.

## Out of Scope

- macOS-Änderungen (Inspector-Panel deckt den Use Case ab)
- Edit-Funktionalität auf der Karte
- Tap-Verhalten auf einzelne Eigenschaften der Karte
- Eigenes Preview-Layout (bestehende `TaskPreviewView` wird unverändert wiederverwendet, nur `accessibilityIdentifier` wird ergänzt)

## Test-Strategie

**UI-Tests (TDD RED vor Implementation):**

| Test-Case | View | Erwartung |
|---|---|---|
| `testBacklogMainListLongPressShowsPreview` | `BacklogView` | Long Press auf BacklogRow → `taskPreviewCard` erscheint |
| `testBacklogCompletedListLongPressShowsPreview` | `BacklogView` (Abgeschlossen) | Long Press → `taskPreviewCard` erscheint |
| `testCoachBacklogLongPressShowsPreview` | `CoachView` | Long Press auf Coach-BacklogRow → `taskPreviewCard` erscheint |
| `testScheduledTaskBlockLongPressShowsPreview` | `BlockPlanningView` / `TimelineView` | Long Press auf `scheduledTaskBlock_*` → `taskPreviewCard` erscheint |

Voraussetzung: `TaskPreviewView` bekommt `.accessibilityIdentifier("taskPreviewCard")` — ohne diesen Identifier können UI-Tests den Preview nicht erkennen.

## Known Limitations

- `ScheduledTaskBlock` bekommt derzeit kein `PlanItem` — der Scope umfasst explizit die notwendige Signaturerweiterung und den Lookup in `BlockPlanningView` und `TimelineView`.
- Wenn `task` im `ScheduledTaskBlock` `nil` ist (Lookup schlägt fehl), wird kein Preview gezeigt — kein Crash.
- `TaskPreviewView` zeigt leere Felder nicht an (bestehende Guard-Logik bleibt unverändert).

## Affected Files (Code, keine Tests)

1. `Sources/Views/TaskPreviewView.swift` — `accessibilityIdentifier` ergänzen
2. `Sources/Views/BacklogView.swift` — `preview:` in 2 `.contextMenu`-Aufrufe einhängen
3. `Sources/Views/CoachView.swift` — `preview:` in 1 `.contextMenu`-Aufruf einhängen
4. `Sources/Views/ScheduledTaskBlock.swift` — optionalen `task: PlanItem?` Parameter + `preview:`
5. `Sources/Models/TimelineItem.swift` — `PositionedScheduledTask` um `task: PlanItem?` erweitern
6. `Sources/Views/BlockPlanningView.swift` — PlanItem-Lookup + `task:` an `ScheduledTaskBlock` übergeben
7. `Sources/Views/TimelineView.swift` — analog zu `BlockPlanningView`

## Changelog

- 2026-05-02: Initial spec created
