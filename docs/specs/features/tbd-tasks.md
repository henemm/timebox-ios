---
entity_id: tbd-tasks
type: feature
created: 2026-01-25
status: draft
workflow: tbd-tasks
user_story: docs/project/stories/quick-capture.md
---

# TBD Tasks (Unvollständige Tasks)

## Approval

- [x] Approved for implementation (2026-01-25)

## Purpose

Tasks ohne ausreichende Informationen für Priorisierung werden mit `tbd` ("to be defined") markiert. Der User sieht auf einen Blick, welche Tasks noch Daten brauchen, um sinnvoll entscheiden zu können: "Task A oder Task B zuerst?"

**Prinzip:** Keine Fake-Defaults. Ehrlich zeigen, was fehlt.

## User Story Reference

> **When** mir unterwegs ein Gedanke einfällt,
> **I want to** ihn mit minimalem Aufwand festhalten,
> **So that** ich ihn später in Ruhe anreichern kann.

## Konzept

### Was braucht man für Priorisierung?

| Dimension | Frage | Ohne diese Info |
|-----------|-------|-----------------|
| **Wichtigkeit** | Welcher Task hat mehr Impact? | Alles gleich wichtig |
| **Dringlichkeit** | Welcher Task hat mehr Zeitdruck? | Alles kann warten |
| **Dauer** | Passt der Task ins Zeitfenster? | Kann nicht planen |

### Was ist ein "tbd" Task?

Ein Task ist `tbd` wenn **mindestens eines** dieser Felder unbekannt ist:
- Wichtigkeit (`nil`)
- Dringlichkeit (`nil`)
- Dauer (`nil`)

### Wann wird "tbd" entfernt?

**Automatisch** sobald alle drei Felder gesetzt sind:

```swift
var isTbd: Bool {
    importance == nil || urgency == nil || duration == nil
}
```

Keine manuelle Aktion nötig. User füllt Felder aus → `tbd` verschwindet.

### Keine Defaults mehr

| Feld | Alt (mit Default) | Neu (ohne Default) |
|------|-------------------|-------------------|
| Wichtigkeit | Default: Mittel | `nil` (unbekannt) |
| Dringlichkeit | Default: Nicht dringend | `nil` (unbekannt) |
| Dauer | Default: 15 min | `nil` (unbekannt) |

**Warum?** Defaults führen dazu, dass alle Tasks "gleich" aussehen. Die Eisenhower-Matrix wird nutzlos, weil 80% der Tasks im selben Quadranten landen.

## Scope

| Datei | Änderung |
|-------|----------|
| `Sources/Models/LocalTask.swift` | Felder optional machen, `isTbd` computed property |
| `Sources/Models/PlanItem.swift` | `isTbd` durchreichen |
| `Sources/Views/BacklogView.swift` | TBD ViewMode, Filter für Matrix |
| `Sources/Views/BacklogRow.swift` | Kursiver Titel + `tbd` Tag |
| `Sources/Views/EditTaskSheet.swift` | "Wichtigkeit" statt "Priorität" |
| `Sources/Views/TaskDetailSheet.swift` | "Wichtigkeit" statt "Priorität" |

**Estimated:** +80 / -40 LoC

## Visuelle Darstellung

### TBD Task (unvollständig)

```
○  Steuererklärung           ← kursiver Titel
   tbd  •  —  •  —           ← Tag + fehlende Werte
```

### Vollständiger Task

```
○  Steuererklärung
   Hoch  •  Dringend  •  45m
```

### Teilweise ausgefüllt

```
○  Zahnarzt anrufen          ← kursiv (noch tbd)
   tbd  •  Dringend  •  —    ← Wichtigkeit + Dauer fehlen
```

## Auswirkung auf Views

| View | TBD Tasks |
|------|-----------|
| **Liste** | Sichtbar, kursiv + `tbd` Tag |
| **Matrix** | NICHT sichtbar (kann nicht eingeordnet werden) |
| **Kategorie** | Sichtbar (Art kann auch bei tbd gesetzt sein) |
| **Dauer** | NICHT sichtbar wenn Dauer fehlt |
| **Fälligkeit** | Sichtbar wenn Deadline gesetzt |
| **TBD (neu)** | NUR tbd Tasks (für fokussierte Vervollständigung) |

### TBD ViewMode

Neuer ViewMode im Toggle: `TBD (3)`

- Zeigt nur unvollständige Tasks
- Badge mit Anzahl (wenn > 0)
- Ermöglicht fokussierte "Triage"

## Implementation Details

### 1. LocalTask.swift - Optionale Felder

```swift
// ALT:
var priority: Int = 1
var urgency: String = "not_urgent"
var manualDuration: Int?

// NEU:
var importance: Int?      // nil = unbekannt, 1/2/3 = Niedrig/Mittel/Hoch
var urgency: String?      // nil = unbekannt, "urgent"/"not_urgent"
var estimatedDuration: Int?  // nil = unbekannt, sonst Minuten

var isTbd: Bool {
    importance == nil || urgency == nil || estimatedDuration == nil
}
```

### 2. Umbenennung: priority → importance

```swift
// ALT:
var priority: Int = 1

// NEU:
var importance: Int?  // "Wichtigkeit" in UI
```

**UI Labels:**
- "Priorität" → "Wichtigkeit"
- Werte: "Niedrig" / "Mittel" / "Hoch" (bleiben gleich)

### 3. BacklogRow.swift - TBD Styling

```swift
var body: some View {
    HStack {
        // Titel
        Text(item.title)
            .italic(item.isTbd)  // Kursiv wenn tbd

        Spacer()

        // Tags
        if item.isTbd {
            Text("tbd")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
    }
}
```

### 4. BacklogView.swift - TBD ViewMode

```swift
enum ViewMode: String, CaseIterable {
    case list = "Liste"
    case eisenhowerMatrix = "Matrix"
    case category = "Kategorie"
    case duration = "Dauer"
    case dueDate = "Fälligkeit"
    case tbd = "TBD"  // NEU
}

private var tbdTasks: [PlanItem] {
    planItems.filter { $0.isTbd && !$0.isCompleted }
}

// Matrix filtert tbd raus:
private var doFirstTasks: [PlanItem] {
    planItems.filter {
        !$0.isTbd &&  // NEU: nur vollständige
        $0.urgency == "urgent" &&
        $0.importance == 3 &&
        !$0.isCompleted
    }
}
```

### 5. Migration bestehender Tasks

Bestehende Tasks mit alten Defaults:
- `priority: 1` → `importance: 1` (behalten, nicht nil)
- `urgency: "not_urgent"` → `urgency: "not_urgent"` (behalten)
- `manualDuration: nil` → `estimatedDuration: nil` (bleibt nil → tbd!)

**Effekt:** Alle Tasks ohne manuell gesetzte Dauer werden `tbd`. Das ist gewollt - sie hatten vorher Fake-15min.

## Test Plan

### Unit Tests

| Test | GIVEN | WHEN | THEN |
|------|-------|------|------|
| `testTbdWhenAllNil` | Task ohne Werte | `isTbd` abfragen | `true` |
| `testTbdWhenOneNil` | Wichtigkeit+Dringlichkeit gesetzt, Dauer nil | `isTbd` abfragen | `true` |
| `testNotTbdWhenAllSet` | Alle drei Werte gesetzt | `isTbd` abfragen | `false` |
| `testTbdAutoRemoval` | tbd Task | Dauer setzen (war letztes nil) | `isTbd == false` |

### UI Tests

| Test | GIVEN | WHEN | THEN |
|------|-------|------|------|
| `testTbdTagVisible` | Task mit isTbd=true | BacklogView Liste | `tbd` Tag sichtbar |
| `testTbdTitleItalic` | Task mit isTbd=true | BacklogView Liste | Titel kursiv |
| `testTbdNotInMatrix` | Task mit isTbd=true | Matrix ViewMode | Task NICHT sichtbar |
| `testTbdViewModeShowsOnly` | 2 tbd, 3 vollständig | TBD ViewMode | Nur 2 Tasks sichtbar |
| `testTbdBadgeCount` | 3 tbd Tasks | ViewMode Toggle | "TBD (3)" Badge |
| `testImportanceLabel` | EditTaskSheet | Öffnen | "Wichtigkeit" statt "Priorität" |

## Acceptance Criteria

- [ ] Felder `importance`, `urgency`, `estimatedDuration` sind optional (nullable)
- [ ] `isTbd` computed property: true wenn mindestens ein Feld nil
- [ ] Keine automatischen Defaults mehr bei Task-Erstellung
- [ ] TBD Tasks: Kursiver Titel + `tbd` Tag in Liste
- [ ] TBD Tasks: Nicht in Matrix sichtbar
- [ ] TBD ViewMode im Toggle mit Badge
- [ ] Umbenennung: "Priorität" → "Wichtigkeit" in allen UI Labels
- [ ] Migration: Bestehende Tasks behalten ihre Werte (außer Fake-Dauer)

## Edge Cases

1. **Quick Capture:** Nur Titel → alles nil → `isTbd = true` ✓
2. **Apple Reminders Sync:** Haben Priorität, aber keine Dauer → `isTbd = true` ✓
3. **Vollständiges Formular:** User füllt alles aus → `isTbd = false` ✓
4. **Nachträgliches Leeren:** User setzt Wichtigkeit auf "—" → `isTbd = true` ✓

## Zusammenhang mit anderen Features

- **Quick Capture (Watch/Widget):** Erstellt automatisch tbd Tasks
- **Backlog Row Redesign:** Styling für tbd Tasks
- **Umbenennung Priorität→Wichtigkeit:** Teil dieser Spec

## Changelog

- 2026-01-25: Initial spec (ersetzt inbox-concept.md)
