---
entity_id: backlog_search
type: feature
created: 2026-02-18
updated: 2026-02-18
status: draft
version: "1.0"
tags: [search, backlog, ios, macos, cross-platform]
---

# Generische Suche im Backlog (iOS + macOS)

## Approval

- [ ] Approved

## Purpose

Suchfeld im Backlog, das Tasks nach Titel, Tags und Kategorie filtert. Auf beiden Plattformen (iOS + macOS) verfuegbar. Ermoeglicht schnelles Finden von Tasks bei wachsender Backlog-Groesse.

## Source

- **iOS:** `Sources/Views/BacklogView.swift` — `.searchable()` Modifier
- **macOS:** `FocusBloxMac/ContentView.swift` — `.searchable()` Modifier

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/BacklogView.swift` | MODIFY | `@State searchText`, `.searchable()`, Filter-Funktion |
| `FocusBloxMac/ContentView.swift` | MODIFY | `@State searchText`, `.searchable()`, Filter in `filteredTasks` |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `PlanItem` | Model | iOS Task-Wrapper — Felder: title, tags, taskType |
| `LocalTask` | Model | SwiftData Model — gleiche Felder, von macOS direkt genutzt |
| `TaskCategory` | Enum | `localizedName` fuer Kategorie-Matching |

## Implementation Details

### iOS (BacklogView)

1. Neuer State: `@State private var searchText = ""`
2. `.searchable(text: $searchText, prompt: "Tasks durchsuchen")` auf `NavigationStack`
3. Neue private Funktion:

```swift
private func matchesSearch(_ item: PlanItem) -> Bool {
    guard !searchText.isEmpty else { return true }
    let query = searchText
    if item.title.localizedCaseInsensitiveContains(query) { return true }
    if item.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
    if let cat = TaskCategory(rawValue: item.taskType),
       cat.localizedName.localizedCaseInsensitiveContains(query) { return true }
    return false
}
```

4. Alle bestehenden computed properties erweitern mit `.filter { matchesSearch($0) }`:
   - `backlogTasks` — Hauptliste
   - `nextUpTasks` — Next Up Sektion
   - Gruppierte Views (category, duration, dueDate) — vor Gruppierung filtern

### macOS (ContentView)

1. Neuer State: `@State private var searchText = ""`
2. `.searchable(text: $searchText, prompt: "Tasks durchsuchen")` auf `NavigationSplitView`
3. `filteredTasks` computed property erweitern — am Ende der bestehenden Filterlogik:

```swift
// Bestehende Sidebar-Filter bleiben
// + Suchfilter hinzufuegen:
if !searchText.isEmpty {
    result = result.filter { task in
        task.title.localizedCaseInsensitiveContains(searchText)
        || task.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        || TaskCategory(rawValue: task.taskType)?.localizedName
            .localizedCaseInsensitiveContains(searchText) == true
    }
}
```

### Suchbare Felder

| Feld | Typ | Beispiel-Suche |
|------|-----|----------------|
| `title` | String | "Steuererklaerung" |
| `tags` | [String] | "arbeit", "privat" |
| `taskType` via `TaskCategory.localizedName` | String | "Geld", "Pflege", "Energie" |

### Verhalten

- Leerer Suchtext = kein Filter (aktuelles Verhalten beibehalten)
- Suche ist **case-insensitive** und **locale-aware**
- Suche wirkt **orthogonal** zu allen bestehenden Filtern (ViewMode auf iOS, SidebarFilter auf macOS)
- Suche wirkt in **allen 8 ViewModes** (iOS)
- Ergebnisse aktualisieren sich **live** beim Tippen

## Expected Behavior

- **Input:** User tippt Text in Suchfeld
- **Output:** Backlog-Liste zeigt nur Tasks die im Titel, Tags oder Kategorie-Name matchen
- **Side effects:** Keine — rein additiv, kein bestehendes Verhalten geaendert

## Scope

- **Dateien:** 2 (+ Tests)
- **LoC:** ~25 netto
- **Risiko:** LOW

## Test Plan

### UI Tests (iOS)
1. **Suchfeld sichtbar:** Backlog Tab oeffnen, Suchfeld ist vorhanden
2. **Suche nach Titel:** Task erstellen, nach Titel suchen, Task erscheint in Ergebnissen
3. **Suche ohne Treffer:** Unbekannten Text suchen, keine Ergebnisse

### Unit Tests
- Nicht noetig — Logik ist trivial (String-Matching) und wird durch UI Tests abgedeckt

## Known Limitations

- Suche durchsucht nicht `taskDescription` (bewusste Entscheidung — nur Titel/Tags/Kategorie)
- Kein Highlighting der Treffer in den Rows (kann spaeter ergaenzt werden)
- Kein Suchverlauf / Suchvorschlaege

## Changelog

- 2026-02-18: Initial spec created
