# Context: FEATURE_023_v2 — macOS Suche vereinheitlichen (Abschluss)

## Request Summary

FEATURE_023 wurde teilweise implementiert (Quick-Add Bar entfernt, (+) Toolbar-Button hinzugefügt). Noch ausstehend aus Spec v1.1: `.searchable()` durch Inline-TextField direkt über der Task-Liste ersetzen (wie auf iOS sichtbar, nicht in der Toolbar versteckt).

## Status nach FEATURE_023

| Änderung | Status |
|----------|--------|
| Quick-Add Bar "Neuer Task..." entfernt | ✅ DONE |
| (+) Toolbar-Button → öffnet MacTaskCreateSheet | ✅ DONE |
| Cmd+N öffnet TaskFormSheet | ✅ DONE (via `focusNewTaskField()`) |
| `.searchable()` entfernen → Inline-TextField | ❌ AUSSTEHEND |

## Related Files

| Datei | Relevanz |
|-------|----------|
| `FocusBloxMac/ContentView.swift` | Hauptdatei — `.searchable()` Zeile 237 muss entfernt werden, Inline-TextField in `backlogView` (ab Zeile 385) hinzufügen |
| `FocusBloxMacUITests/MacUnifiedSearchUITests.swift` | Tests müssen aktualisiert werden: `testSearchFieldExists` prüft `.searchable()` → muss Inline-TextField prüfen |

## Was zu ändern ist

### ContentView.swift

1. **Zeile 237:** `.searchable(text: $searchText, prompt: "Tasks durchsuchen")` entfernen
2. **Zeile 386 (backlogView VStack):** Inline-TextField MIT Lupe-Icon vor der `List(...)` einfügen:
   ```swift
   HStack {
       Image(systemName: "magnifyingglass")
           .foregroundStyle(.secondary)
       TextField("Tasks durchsuchen", text: $searchText)
           .textFieldStyle(.plain)
           .accessibilityIdentifier("backlogSearchField")
       if !searchText.isEmpty {
           Button { searchText = "" } label: {
               Image(systemName: "xmark.circle.fill")
                   .foregroundStyle(.secondary)
           }
           .buttonStyle(.plain)
       }
   }
   .padding(.horizontal, 12)
   .padding(.vertical, 8)
   ```

### MacUnifiedSearchUITests.swift

`testSearchFieldExists` muss angepasst werden: statt `app.searchFields.firstMatch` jetzt `app.textFields["backlogSearchField"]` prüfen.

## Existing Patterns

- `searchText` State ist bereits vorhanden (Zeile 79)
- `matchesSearch()` und `filteredTasks` nutzen `searchText` bereits — keine Logik-Änderungen nötig
- iOS BacklogView nutzt `.searchable()` (verhält sich auf iOS anders — oben an der Liste sichtbar)
- macOS: `.searchable()` = Toolbar → versteckt; Inline = direkt sichtbar

## Dependencies

- `searchText: String` (@State, Zeile 79) — bereits vorhanden
- `matchesSearch()` — bereits vorhanden, kein Änderungsbedarf
- `filteredTasks` + `regularFilteredTasks` — bereits vorhanden

## Analysis

### Type
Feature (Abschluss von FEATURE_023 Spec v1.1)

### Kritischer Fund: FEATURE_004 Coach-Backlog Search Tests

`MacCoachBacklogUITests.swift` hat 4 TDD-RED-Tests (Zeile 356–449) für FEATURE_004 die `app.searchFields.firstMatch` checken. Da `navigateToBacklog()` ContentView's `backlogView` (mit coach mode) rendert — NICHT eine separate MacCoachBacklogView — basieren diese Tests auf ContentViews `.searchable()`.

**Konsequenz:** Nach Entfernung von `.searchable()`:
- Diese 4 Tests finden `searchFields` nicht mehr → schlagen fehl (für den falschen Grund)
- Inline-TextField (`backlogSearchField`) ist auch in Coach-Mode sichtbar
- Die Filterlogik (`matchesSearch`, `filteredTasks`) funktioniert bereits im Coach-Modus
- → FEATURE_004 ist faktisch schon implementiert (via ContentView-Logik)

**Lösung:** Die 4 FEATURE_004-Tests auf `textFields["backlogSearchField"]` umstellen — dann werden sie nach FEATURE_023_v2 GREEN (korrekt, da FEATURE_004 durch ContentView bereits implementiert ist).

### Affected Files

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `FocusBloxMac/ContentView.swift` | MODIFY | `.searchable()` Zeile 237 entfernen; Inline-TextField vor der List in `backlogView` einfügen |
| `FocusBloxMacUITests/MacUnifiedSearchUITests.swift` | MODIFY | `testSearchFieldExists`: `searchFields.firstMatch` → `textFields["backlogSearchField"]` |
| `FocusBloxMacUITests/MacCoachBacklogUITests.swift` | MODIFY | 4 FEATURE_004 TDD-RED-Tests: `searchFields.firstMatch` → `textFields["backlogSearchField"]` |

### Scope Assessment

- **Dateien:** 3
- **LoC:** +15 / -5 (ContentView) + ~10 (Tests aktualisieren)
- **Risiko:** LOW — bestehende Filterlogik unverändert, nur UI-Präsentation ändert sich

### Technical Approach

1. `.searchable(text: $searchText, ...)` auf Zeile 237 entfernen
2. In `backlogView` (Zeile 386), vor der `List(...)`, eine `HStack`-Suchleiste einfügen:
   - `Image(systemName: "magnifyingglass")` + `TextField` + optionaler Clear-Button
   - `accessibilityIdentifier("backlogSearchField")`
   - Styling: `.padding(.horizontal, 12).padding(.vertical, 8)` + Divider
3. Tests: `app.searchFields.firstMatch` → `app.textFields["backlogSearchField"]`

### Open Questions
Keine — Scope und Ansatz sind klar definiert.
