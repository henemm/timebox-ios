---
entity_id: feature-023-v2-inline-search
type: feature
created: 2026-03-19
updated: 2026-03-19
status: implemented
version: "1.0"
tags: [macos, search, backlog, feature-023]
---

# FEATURE_023_v2 — macOS Backlog: Inline-Suchfeld

## Approval

- [ ] Approved

## Purpose

Ersetzt den `.searchable()` Modifier in der macOS ContentView durch ein Inline-TextField direkt oberhalb der Task-Liste, sodass die Suche dauerhaft sichtbar ist (analog zum iOS-Verhalten). Schließt damit den letzten ausstehenden Punkt aus FEATURE_023 Spec v1.1 ab und bringt gleichzeitig die vier FEATURE_004-TDD-RED-Tests in MacCoachBacklogUITests.swift auf GREEN.

## Source

- **File:** `FocusBloxMac/ContentView.swift`
- **Identifier:** `backlogView` (View-Property, enthält die Task-Liste mit Suchfeld)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `searchText: String` | @State (ContentView, Zeile 79) | Bereits vorhandener State, wird weiterhin genutzt |
| `matchesSearch()` | function (Sources/) | Filtert Tasks anhand von `searchText`, keine Änderung nötig |
| `filteredTasks` | computed property (ContentView) | Nutzt `matchesSearch()`, keine Änderung nötig |
| `regularFilteredTasks` | computed property (ContentView) | Nutzt `matchesSearch()`, keine Änderung nötig |
| `FEATURE_023` | spec | Vorige Version, deren letzter Punkt hier abgeschlossen wird |
| `FEATURE_004` | spec | Coach-Backlog-Suche — Tests werden durch diese Änderung GREEN |

## Implementation Details

### 1. Entfernen in `ContentView.swift` (Zeile 237)

```swift
// ENTFERNEN:
.searchable(text: $searchText, prompt: "Tasks durchsuchen")
```

### 2. Einfügen in `backlogView` — direkt VOR `List(selection: $selectedTasks)`

```swift
// MARK: - Inline Search (FEATURE_023_v2: replaces .searchable() toolbar search)
HStack(spacing: 8) {
    Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
    TextField("Tasks durchsuchen", text: $searchText)
        .textFieldStyle(.plain)
        .accessibilityIdentifier("backlogSearchField")
    if !searchText.isEmpty {
        Button {
            searchText = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
.padding(.horizontal, 12)
.padding(.vertical, 8)
Divider()
```

### 3. Test-Updates: `MacUnifiedSearchUITests.swift`

`testSearchFieldExists`: Suchfeld-Lookup von `app.searchFields.firstMatch` auf `app.textFields["backlogSearchField"]` umstellen. Comment und assertion message entsprechend aktualisieren.

### 4. Test-Updates: `MacCoachBacklogUITests.swift`

4 FEATURE_004-RED-Tests (T1–T4, Zeilen 356–449): `app.searchFields.firstMatch` → `app.textFields["backlogSearchField"]`. Nach Umstellung werden alle vier Tests GREEN, da `matchesSearch()` / `filteredTasks` bereits korrekt implementiert sind.

## Expected Behavior

- **Input:** Nutzer tippt in das Inline-TextField oberhalb der Task-Liste
- **Output:** Task-Liste filtert in Echtzeit via bestehende `matchesSearch()` / `filteredTasks` Logik; bei nicht-leerem Suchtext erscheint ein X-Button zum Leeren
- **Side effects:** `.searchable()` Toolbar-Suchfeld verschwindet aus der macOS-Toolbar; das Inline-Feld ist jederzeit sichtbar ohne Toolbar-Interaktion

## Test Plan

| # | Test | Datei | Erwartetes Ergebnis nach Implementierung |
|---|------|-------|------------------------------------------|
| 1 | `testQuickAddTextFieldDoesNotExist` | MacUnifiedSearchUITests | `newTaskTextField` existiert NICHT (unverändert) |
| 2 | `testAddTaskToolbarButtonExists` | MacUnifiedSearchUITests | `macAddTaskButton` existiert (unverändert) |
| 3 | `testAddTaskButtonOpensFormSheet` | MacUnifiedSearchUITests | Klick öffnet Sheet (unverändert) |
| 4 | `testSearchFieldExists` (UPDATED) | MacUnifiedSearchUITests | `textFields["backlogSearchField"]` existiert |
| 5 | `test_coachBacklog_searchFieldExists` (UPDATED) | MacCoachBacklogUITests | `textFields["backlogSearchField"]` in Coach-Mode |
| 6–8 | T2–T4 FEATURE_004 (UPDATED) | MacCoachBacklogUITests | Filterlogik via Inline-TextField GREEN |

## Affected Files

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `FocusBloxMac/ContentView.swift` | MODIFY | `.searchable()` auf Zeile 237 entfernen; Inline-TextField-HStack vor `List` in `backlogView` einfügen |
| `FocusBloxMacUITests/MacUnifiedSearchUITests.swift` | MODIFY | `testSearchFieldExists`: Lookup von `searchFields` auf `textFields["backlogSearchField"]` umstellen |
| `FocusBloxMacUITests/MacCoachBacklogUITests.swift` | MODIFY | 4 FEATURE_004-RED-Tests (T1–T4): `searchFields` → `textFields["backlogSearchField"]` |

## Scope

- Dateien: 3
- LoC: +15 / -5 (ContentView) + ca. 10 (Test-Updates)
- Risiko: LOW

## Known Limitations

- Das Inline-Suchfeld nutzt `.textFieldStyle(.plain)` — kein nativer macOS-Suchfeld-Stil. Falls in Zukunft ein dekorierter Stil gewünscht wird, kann `.textFieldStyle(.roundedBorder)` oder ein custom Style eingesetzt werden.
- Padding und Divider sind hartcodiert; bei einem globalen Layout-Update ggf. anpassen.

## Changelog

- 2026-03-19: Initial spec created (FEATURE_023_v2 — Abschluss Spec v1.1, Inline-Suchfeld ersetzt .searchable())
