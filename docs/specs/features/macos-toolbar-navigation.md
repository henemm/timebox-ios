# macOS Toolbar Navigation

## Status: IN PROGRESS

## Zusammenfassung

Umbau der macOS Navigation von vertikaler Sidebar zu horizontaler Toolbar mit Segmented Control.

## Aktueller Zustand (IST)

```
┌─────────────────────────────────────────────────────────┐
│ Titelleiste                                             │
├───────────┬─────────────────────────────┬───────────────┤
│ Sidebar:  │                             │               │
│ - Backlog │      Main Content           │   Inspector   │
│ - Planen  │                             │               │
│ - Zuweisen│                             │               │
│ - Focus   │                             │               │
│ - Review  │                             │               │
└───────────┴─────────────────────────────┴───────────────┘
```

## Ziel-Zustand (SOLL)

```
┌─────────────────────────────────────────────────────────┐
│ Toolbar: [Backlog] [Planen] [Zuweisen] [Focus] [Review] │
├───────────┬─────────────────────────────┬───────────────┤
│ Filter    │                             │               │
│ (nur bei  │      Main Content           │   Inspector   │
│  Backlog) │                             │               │
└───────────┴─────────────────────────────┴───────────────┘
```

## Änderungen

| Datei | Aktion | LoC |
|-------|--------|-----|
| `FocusBloxMac/ContentView.swift` | Toolbar mit Picker hinzufügen | ~60 |
| `FocusBloxMac/SidebarView.swift` | Auf Filter-only reduzieren | ~40 |
| **Gesamt** | | ~100 |

## UI Tests (TDD RED)

### Test 1: Toolbar hat Navigation Picker
- Toolbar muss existieren
- Picker mit 5 Optionen (Backlog, Planen, Zuweisen, Focus, Review)
- Accessibility Identifier: `mainNavigationPicker`

### Test 2: Picker wechselt View
- Tap auf "Planen" → PlanningView wird angezeigt
- Tap auf "Backlog" → BacklogView wird angezeigt

### Test 3: Sidebar nur bei Backlog sichtbar
- Bei Backlog: Sidebar mit Filter-Optionen sichtbar
- Bei Planen/Zuweisen/etc.: Keine Sidebar

## Acceptance Criteria

- [ ] Navigation-Tabs erscheinen in der Toolbar
- [ ] Sidebar erscheint nur bei Backlog (für Filter)
- [ ] Alle 5 Bereiche erreichbar via Toolbar
- [ ] Build erfolgreich
- [ ] UI Tests grün
