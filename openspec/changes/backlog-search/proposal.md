# Feature: Generische Suche (iOS + macOS)

## Zusammenfassung

Freitext-Suchfeld fuer den Backlog auf beiden Plattformen. Durchsucht Tasks nach Titel, Tags und Beschreibung. Nutzt den nativen SwiftUI `.searchable()` Modifier fuer plattformgerechtes Look & Feel.

---

## Ist-Zustand

### Keine Suchfunktion vorhanden

- Kein `.searchable()` Modifier in der gesamten App
- Kein `searchText` State
- Filterung nur ueber vordefinierte Kategorien (Backlog-Filter: Kategorie, Status, Matrix, Dauer, TBD, Erledigt)
- Freitext-Suche nach Task-Titel nicht moeglich

### Bestehende Filter

**iOS (`BacklogView.swift`):**
- ViewMode-Picker: Liste, Matrix, Kategorie, Dauer, Faelligkeit, TBD, Erledigt
- Filterung via SwiftData `@Query` + lokale Praedikate

**macOS (`SidebarView.swift` + `ContentView.swift`):**
- Sidebar-Filter: All, Next Up, TBD, Ueberfaellig, Bald faellig, Erledigt, pro Kategorie
- 3-Spalten NavigationSplitView

---

## Soll-Zustand

### Phase 1: Task-Suche im Backlog (dieses Ticket)

**iOS:**
```
┌──────────────────────────┐
│ 🔍 Suchen...             │  ← .searchable() auf BacklogView
├──────────────────────────┤
│ [Liste] [Matrix] [...]   │  ← bestehende Filter bleiben
│                          │
│ Task "Meeting vorbere..." │
│ Task "Slides erstellen"  │
└──────────────────────────┘
```

- `.searchable()` Modifier auf `BacklogView`
- Suchfeld erscheint nativ oben in der ScrollView (Pull-Down auf iOS)
- Suche filtert die angezeigte Task-Liste in Echtzeit
- Kombinierbar mit bestehenden ViewMode-Filtern

**macOS:**
```
┌─────────┬──────────────────────────────┬──────────┐
│ Sidebar │ 🔍 Suchen...                 │Inspector │
│ ─────── │ ──────────────────────────── │          │
│ All     │ Task "Meeting vorbere..."    │ Details  │
│ Next Up │ Task "Slides erstellen"      │          │
│ TBD     │                              │          │
└─────────┴──────────────────────────────┴──────────┘
```

- `.searchable()` Modifier auf dem Backlog-Listenbereich in `ContentView`
- Suchfeld erscheint nativ in der Toolbar
- Kombinierbar mit Sidebar-Filtern

### Was durchsucht wird

| Feld | Match-Typ |
|------|-----------|
| `title` | case-insensitive contains |
| `tags` | case-insensitive contains (jeder Tag einzeln) |
| `taskDescription` | case-insensitive contains |

### Was NICHT durchsucht wird (Phase 1)

- Kalender-Events (CalendarEvent)
- Focus Blocks
- Kategorie-Namen (dafuer gibt es bereits Filter)

---

## Technischer Plan

### Shared State (Sources/)

Neues Property in einer bestehenden View oder als Binding:

```swift
@State private var searchText = ""
```

### Suchlogik (Shared)

SwiftData `#Predicate` mit Suchtext:

```swift
// In der View oder als computed property
var filteredTasks: [LocalTask] {
    guard !searchText.isEmpty else { return tasks }
    let search = searchText.lowercased()
    return tasks.filter { task in
        task.title.localizedCaseInsensitiveContains(search)
        || (task.taskDescription?.localizedCaseInsensitiveContains(search) ?? false)
        || task.tags.contains { $0.localizedCaseInsensitiveContains(search) }
    }
}
```

### iOS Implementation (BacklogView.swift)

```swift
NavigationStack {
    // ... bestehender Content
}
.searchable(text: $searchText, prompt: "Tasks durchsuchen")
```

Die gefilterte Liste wird aus `filteredTasks` statt direkt aus `tasks` gebaut.

### macOS Implementation (ContentView.swift)

```swift
// Im Backlog-Bereich der NavigationSplitView
.searchable(text: $searchText, prompt: "Tasks durchsuchen")
```

### Dateien (2-3 Dateien, ~25 LoC netto)

| Datei | Aenderung | LoC |
|-------|-----------|-----|
| `Sources/Views/BacklogView.swift` | `@State searchText`, `.searchable()`, Filter-Logik | ~12 LoC |
| `FocusBloxMac/ContentView.swift` | `@State searchText`, `.searchable()`, Filter-Logik | ~10 LoC |
| (optional) `FocusBloxMac/SidebarView.swift` | searchText-Binding falls noetig | ~3 LoC |

---

## Abgrenzung (Out of Scope)

- Keine Spotlight-Integration (existiert bereits rudimentaer auf macOS)
- Keine Suche ueber Kalender-Events oder Focus Blocks (Phase 2)
- Kein separater SearchService - einfache lokale Filterung reicht
- Keine Such-Historie oder Vorschlaege
- Keine neue View - nur `.searchable()` auf bestehende Views

---

## Acceptance Criteria

1. iOS BacklogView: Suchfeld erscheint beim Runterziehen der Liste
2. macOS ContentView: Suchfeld in der Toolbar (Backlog-Section)
3. Suche filtert Tasks nach Titel (case-insensitive)
4. Suche filtert Tasks nach Tags (case-insensitive)
5. Suche filtert Tasks nach Beschreibung (case-insensitive)
6. Leeres Suchfeld zeigt alle Tasks (wie bisher)
7. Suche kombinierbar mit bestehenden Filtern (ViewMode, Kategorie, etc.)
8. Keine Performance-Probleme bei typischen Task-Mengen (<500 Tasks)

---

## Geschaetzter Aufwand

**KLEIN** (~15-20k Tokens, 2-3 Dateien, ~25 LoC)

Nativer SwiftUI `.searchable()` Modifier macht den Grossteil der Arbeit. Keine neuen Views, keine neuen Services, keine neuen Models.
