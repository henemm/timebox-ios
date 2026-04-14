---
entity_id: FEATURE_217-aufteilen-dialog
type: feature
created: 2026-04-13
updated: 2026-04-13
status: draft
version: "2.0"
tags: [ui, task-split, ai, backlog, consistency]
github_issue: "#217"
---

# Aufteilen Dialog — BacklogRow-Konsistenz mit vererbten Attributen

## Approval

- [ ] Approved

## Purpose

Der Aufteilen-Dialog zeigt AI-Vorschläge als echte BacklogRow-Cards — identisch zur Backlog-Darstellung. Sub-Tasks erben Attribute (Kategorie, Dringlichkeit, Wichtigkeit, Tags, Fälligkeitsdatum) vom Original-Task, damit der User vor dem Erstellen sieht, wie die neuen Tasks aussehen werden. Keine Überraschungen nach dem Erstellen.

## Source

- **File:** `Sources/Views/TaskSplitView.swift`
- **Identifier:** `struct TaskSplitView`
- **Test File:** `FocusBloxUITests/TaskSplitUITests.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Sources/Views/BacklogRow.swift` | view | Wiederverwendung der Card-Darstellung für Sub-Task-Vorschläge |
| `Sources/Models/PlanItem.swift` | model | Temporäre PlanItems für Preview-Darstellung |
| `Sources/Views/DurationPicker.swift` | view | Dauer-Änderung per Tap auf Duration-Badge |
| `Sources/Services/TaskSplitService.swift` | service | Erweitert: Vererbung von Attributen bei persistSplit() |
| `Sources/Views/BacklogHygieneView.swift` | view | Keine Änderung; ruft TaskSplitView auf |

## Implementation Details

### 1. Temporäre PlanItems aus AI-Vorschlägen + Original-Attributen

Wenn die AI Vorschläge liefert (title + minutes), werden daraus temporäre `PlanItem`-Instanzen erstellt. Alle vererbbaren Attribute kommen vom Original-Task (`planItem`):

```
Vererbt vom Original:
  - taskType (Kategorie)
  - importance (Wichtigkeit)
  - urgency (Dringlichkeit)
  - tags
  - dueDate (Fälligkeitsdatum)

Vom AI-Vorschlag:
  - title (neuer Titel)
  - estimatedDuration (geschätzte Dauer)

Defaults für Sub-Tasks:
  - id: neue UUID
  - isCompleted: false
  - recurrencePattern: nil (Sub-Tasks sind nicht wiederkehrend)
  - parentTaskID: Original-Task-ID (wird bei Persist gesetzt)
```

### 2. BacklogRow als Card-Darstellung

Jeder Vorschlag wird als `BacklogRow(item: tempPlanItem)` dargestellt. Aktive Callbacks:

- `onTitleSave`: Inline-Titel-Editing (Doppel-Tap) → aktualisiert Vorschlag-Titel
- `onDurationTap`: Öffnet DurationPicker Sheet → aktualisiert Vorschlag-Dauer
- `onDeleteTap`: Entfernt Vorschlag (nur wenn > 1 verbleibt)
- `onImportanceCycle`: Importance pro Vorschlag änderbar
- `onUrgencyToggle`: Urgency pro Vorschlag änderbar

Nicht benötigte Callbacks (nil/nicht gesetzt):
- `onComplete`, `onCancelCompletion`, `onAddToNextUp`, `onEditTap`, `onStartFocusSprint`

### 3. Swipe-to-Delete (Backlog-Pattern)

Löschen per Swipe-Geste auf der BacklogRow-Card (`.swipeActions`). Expliziter Löschen-Button entfällt — konsistent mit dem Backlog-Pattern. Swipe ist disabled bei letztem Vorschlag.

### 4. "Neu generieren" mit Bestätigungs-Alert

Wie in v1.0: Label "Neu generieren", Alert "Änderungen verwerfen?" bei vorgenommenen Änderungen.

### 5. persistSplit() erweitern — Attribut-Vererbung

`TaskSplitService.persistSplit()` erhält zusätzliche Parameter für vererbte Attribute:

```swift
static func persistSplit(
    originalTaskID: String,
    suggestions: [(title: String, minutes: Int)],
    taskType: String,
    importance: Int?,
    urgency: String?,
    tags: [String],
    dueDate: Date?,
    modelContext: ModelContext
) -> Int
```

Jeder neue `LocalTask` bekommt diese Attribute.

### 6. Dependency Chain — Kaskadierung der Sub-Tasks (Bug #220)

Sub-Tasks werden als Finish-to-Start Dependency Chain erstellt:
- Erster Sub-Task: `blockerTaskID = nil` (frei verfügbar)
- Jeder weitere: `blockerTaskID = vorheriger Sub-Task ID`
- `sortOrder` wird sequentiell gesetzt (0, 1, 2, ...)

Dadurch erscheint im Backlog nur der erste Sub-Task als aktiv — die restlichen sind blockiert und werden erst nach Abschluss des Vorgängers sichtbar.

Zusätzlich: Wenn der Original-Task selbst andere Tasks blockierte (`blockerTaskID == original.id`), werden diese beim Split befreit (analog zu `SyncEngine.completeTask()` → `freeDependents()`).

### Accessibility Identifiers

Bestehend (angepasst):
- `splitOriginalTitle`, `splitLoadingIndicator`
- `splitAddButton`, `splitRegenerateButton`, `splitCreateButton`
- `splitInfoText`

Über BacklogRow (automatisch via item.id):
- `taskTitle_<id>` — Titel pro Vorschlag
- `durationBadge_<id>` — Duration Badge pro Vorschlag
- `importanceBadge_<id>` — Importance Badge
- `urgencyBadge_<id>` — Urgency Badge
- `categoryBadge_<id>` — Kategorie Badge

Entfernt (ersetzt durch BacklogRow):
- `splitSuggestionTitle_N`, `splitDurationBadge_N`, `splitDeleteButton_N`

## Geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/TaskSplitView.swift` | Komplett-Umbau: BacklogRow statt eigene Zeilen, temporäre PlanItems, Attribut-Vererbung |
| `Sources/Services/TaskSplitService.swift` | persistSplit() erweitern um vererbte Attribute |
| `FocusBloxUITests/TaskSplitUITests.swift` | Tests komplett neu: BacklogRow-Identifier, Swipe-Delete, vererbte Badges |

## Acceptance Criteria

- **AC1 — BacklogRow-Darstellung:** Jeder AI-Vorschlag wird als BacklogRow-Card angezeigt (gleiche Optik wie Backlog).
- **AC2 — Vererbte Attribute sichtbar:** Kategorie, Wichtigkeit, Dringlichkeit, Tags und Fälligkeitsdatum des Originals sind in jeder Vorschlags-Card sichtbar.
- **AC3 — Dauer editierbar:** Tap auf Duration-Badge öffnet DurationPicker, Wert wird aktualisiert.
- **AC4 — Titel editierbar:** Doppel-Tap auf Titel erlaubt Inline-Editing (BacklogRow-Pattern).
- **AC5 — Swipe-to-Delete:** Swipe-Geste auf Card entfernt Vorschlag. Disabled bei letztem Vorschlag.
- **AC6 — Label "Neu generieren":** Button trägt Label "Neu generieren".
- **AC7 — Bestätigungs-Alert:** Bei Änderungen erscheint "Änderungen verwerfen?" Alert vor Regenerierung.
- **AC8 — Attribute werden persistiert:** Beim Erstellen erben Sub-Tasks alle vererbten Attribute (nicht nur taskType).
- **AC9 — Dependency Chain (Bug #220):** Sub-Tasks werden als Finish-to-Start Kette erstellt — erster frei, jeder weitere blockt auf Vorgänger.
- **AC10 — sortOrder (Bug #220):** Sub-Tasks haben deterministische Reihenfolge (0, 1, 2, ...).
- **AC11 — freeDependents (Bug #220):** Tasks die vom Original-Task abhingen werden beim Split befreit.

## Test Plan

Alle Tests in `FocusBloxUITests/TaskSplitUITests.swift`:

| Test | Beschreibung |
|------|-------------|
| `test_splitView_showsBacklogRowCards` | Nach AI-Vorschlag: taskTitle_<id> und categoryBadge_<id> existieren |
| `test_splitView_showsInheritedCategory` | Kategorie-Badge zeigt Kategorie des Original-Tasks |
| `test_splitView_showsInheritedImportance` | Importance-Badge zeigt Wichtigkeit des Original-Tasks |
| `test_splitView_durationBadgeTapOpensPicker` | Tap auf durationBadge öffnet DurationPicker |
| `test_splitView_durationUpdatesAfterPick` | Auswahl im Picker aktualisiert Duration-Badge |
| `test_splitView_swipeToDelete` | Swipe-Links auf Card entfernt Vorschlag |
| `test_splitView_cannotDeleteLastSuggestion` | Letzter Vorschlag kann nicht geswiped werden |
| `test_regenerateButton_labelIsNeuGenerieren` | Button-Label ist "Neu generieren" |
| `test_regenerateWithChanges_showsAlert` | Alert erscheint nach Änderung + Tap auf "Neu generieren" |
| `test_splitView_createPersistsInheritedAttributes` | Nach Erstellen: neue Tasks haben vererbte Kategorie |
| `test_persistSplit_createsDependencyChain` | Sub-Tasks bilden Finish-to-Start Kette via blockerTaskID (AC9) |
| `test_persistSplit_setsSortOrder` | Sub-Tasks haben sortOrder 0, 1, 2 (AC10) |
| `test_persistSplit_freesDependentsOfOriginal` | Dependents des Originals werden befreit (AC11) |
| `test_persistSplit_singleSubTaskHasNoBlocker` | Einzelner Sub-Task hat keinen Blocker (Edge Case) |

## Nicht im Scope

- Drag & Drop Reihenfolge der Vorschläge
- Kategorie-Änderung pro Vorschlag (erbt nur vom Original)
- macOS-Pendant
- Undo nach Erstellen

## Changelog

- 2026-04-13: v1.0 Initial spec (einfache Dauer-Badges + Löschen-Button)
- 2026-04-13: v2.0 Redesign — BacklogRow-Konsistenz mit vererbten Attributen
- 2026-04-14: v2.1 Bug #220 — Dependency Chain (AC9-AC11): blockerTaskID-Kaskadierung, sortOrder, freeDependents
