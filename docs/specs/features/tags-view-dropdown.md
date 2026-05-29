---
entity_id: backlog-tags-view
type: feature
created: 2026-05-29
updated: 2026-05-29
status: draft
version: "1.0"
tags: []
---

# Backlog Tags-View

## Approval

- [x] Approved

## Purpose

Ersetzt den bisherigen "Überfällig"-Eintrag im Backlog-Dropdown durch eine "Tags"-Ansicht, die Backlog-Tasks nach ihren Tags gruppiert anzeigt. Ziel ist es, Nutzerinnen einen mentalen "Themenbereich"-Modus zu geben (z.B. Arbeit / Privat), um gezielt in eine Tag-Gruppe einzutauchen statt durch eine flache Liste zu scrollen.

## Source

- **File:** `Sources/Views/BacklogView.swift`
- **Identifier:** `enum ViewMode` + `var tagsView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `PlanItem` | model | Liefert `tags: [String]` (leer = kein Tag) und `priorityScore` |
| `LocalTask` | model | Persistenzschicht; `tags` ist `[String]?` (nil = kein Tag) |
| `nextUpListSection` | view | Heute-Sektion, unverändert wiederverwendet ganz oben |
| `backlogRowWithSwipe(_:)` | view | Einzelne Task-Zeile mit Swipe-Actions, unverändert wiederverwendet |
| `effectivePriorityScore(for:)` | function | Sortierung innerhalb einer Tag-Sektion nach Score absteigend |
| `backlogTasks` | computed property | Datenquelle: bereits gefiltert (kein Completed, kein NextUp, kein FocusBlock assigned) |

## Implementation Details

### 1. ViewMode-Enum: `overdue` → `tags`

```swift
// Vorher:
case overdue = "Überfällig"

// Nachher:
case tags = "Tags"
```

Icon-Zuordnung (in `var icon`):
```swift
case .tags: return "tag.fill"
```

Empty-State-Meldung (in `var emptyStateMessage`):
```swift
case .tags:
    return ("Keine Tags", "Weise Tasks Tags zu, um sie hier gruppiert zu sehen.")
```

### 2. Switch-Verzweigung in `body`

```swift
// Vorher:
case .overdue:
    overdueView

// Nachher:
case .tags:
    tagsView
```

### 3. Computed Properties für Tag-Gruppierung

Neue computed property `tasksByTag`:

- Filtert `nextUpTasks`-IDs heraus (keine Duplikate mit "Heute")
- Tasks mit mindestens einem Tag werden nach `tags[0]` (erstem Tag) gruppiert
- Tasks ohne Tags landen in der "Kein Tag"-Gruppe
- Gruppen werden alphabetisch nach Tag-Namen sortiert
- Innerhalb jeder Gruppe: absteigend nach `effectivePriorityScore`
- Leere Gruppen (nach Filterung) werden nicht ausgegeben
- "Kein Tag"-Gruppe steht immer am Ende

### 4. tagsView

Struktur der View:

1. `nextUpListSection` — "Heute"-Sektion oben, vollständig unverändert wiederverwendet
2. Für jede Gruppe in `tasksByTag`: eine `Section` mit Header (Tag-Name + Count-Badge) und `backlogRowWithSwipe` für jeden Task
3. Header-AccessibilityIdentifier: `tagSection_<tagname>` bzw. `tagSection_noTag`
4. Empty-State via `ContentUnavailableView` wenn `tasksByTag` leer ist

### Hinweis: Ein Task — ein Tag

Ein Task mit mehreren Tags erscheint ausschliesslich in der Gruppe seines **ersten Tags** (`task.tags[0]`). Diese Regel verhindert Duplikate (AC5) und ist einfach zu implementieren. Sollte zukünftig Multi-Tag-Sichtbarkeit gewünscht sein, ist das ein separates Feature.

### AppStorage-Key-Migration

`@AppStorage("backlogViewMode")` speichert den `rawValue` des Enums. Nach der Umbenennung von `"Überfällig"` auf `"Tags"` wird beim ersten App-Start der gespeicherte Wert nicht mehr zu einem gültigen Case matchen — Swift fällt auf den `@AppStorage`-Default `.priority` zurück. Das ist korrektes, gewünschtes Verhalten (kein Migration-Aufwand nötig).

## Expected Behavior

- **Input:** `backlogTasks` (nicht abgeschlossen, kein NextUp-Flag, kein FocusBlock zugeordnet)
- **Output:** Gruppierte Listen-View: `nextUpListSection` oben, darunter eine `Section` pro verwendetem Tag (alphabetisch), ganz unten optionale "Kein Tag"-Sektion
- **Side effects:** Keine; rein darstellend, keine Daten-Mutation

### Acceptance Criteria

| # | Kriterium | Wie testbar |
|---|-----------|-------------|
| **AC-1** | "Tags" erscheint im Dropdown; "Überfällig" nicht mehr | UI-Test: `viewModeSwitcher` öffnen, Button "Tags" existiert, Button "Überfällig" fehlt |
| **AC-2** | Tasks werden nach Tag gruppiert angezeigt | UI-Test: Task mit Tag "arbeit" anlegen → Section-Header mit Identifier `tagSection_arbeit` sichtbar |
| **AC-3** | "Heute"-Sektion steht über allen Tag-Gruppen | UI-Test: `nextUpSection` accessibility ID erscheint vor erstem `tagSection_*` |
| **AC-4** | Tasks ohne Tag erscheinen in Sektion "Kein Tag" ganz unten | UI-Test: Task ohne Tag anlegen → `tagSection_noTag` sichtbar, steht nach allen benannten Tag-Sektionen |
| **AC-5** | Kein Task erscheint doppelt | Unit-Test: `tasksByTag` für Task mit Tag + isNextUp=true → Task nicht in Tag-Gruppe enthalten |

## Known Limitations

- Ein Task mit mehreren Tags erscheint nur unter seinem ersten Tag. Multi-Tag-Anzeige ist nicht im Scope.
- Die "Überfällig"-Standalone-View wird entfernt. Überfällige Tasks bleiben weiterhin in der "Priorität"-View sichtbar (dort als eigene Sektion ganz oben).
- Leere Tag-Sektionen (alle Tasks der Gruppe sind in "Heute") werden ausgeblendet — gewünschtes Verhalten.

## Changelog

- 2026-05-29: Initial spec created
