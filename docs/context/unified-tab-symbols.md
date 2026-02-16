# Context: Einheitliche Symbole Tab-Bar/Sidebar

## Request Summary
iOS Tab-Bar und macOS Sidebar nutzen unterschiedliche SF Symbols fuer die gleichen 5 Bereiche. Beide Plattformen sollen einheitliche Symbole verwenden.

## Aktuelle Unterschiede (4 von 5 verschieden)

| Bereich | iOS Symbol | macOS Symbol |
|---------|-----------|--------------|
| Backlog | `list.bullet` | `tray.full` |
| Planen/Bloecke | `rectangle.split.3x1` | `calendar` |
| Zuweisen | `arrow.up.and.down.text.horizontal` | `arrow.up.arrow.down` |
| Focus | `target` | `target` |
| Review/Rueckblick | `clock.arrow.circlepath` | `chart.bar` |

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/MainTabView.swift` | iOS Tab-Bar mit 5 Tabs (Zeilen 5-31) |
| `FocusBloxMac/SidebarView.swift` | macOS MainSection enum (Zeilen 11-27) + Sidebar Filter |
| `FocusBloxMac/ContentView.swift` | macOS Toolbar-Picker nutzt MainSection (Zeilen 164-176) |

## Existing Patterns
- iOS: `.tabItem { Label("Name", systemImage: "symbol") }`
- macOS: `Label("Name", systemImage: "symbol")` im Toolbar-Picker + Sidebar

## Dependencies
- Upstream: SF Symbols Framework
- Downstream: Keine - rein visuelle Aenderung

## Risks & Considerations
- Rein kosmetisch, kein Logik-Impact
- macOS Sidebar hat ZUSAETZLICHE Filter-Icons (Next Up, TBD, etc.) die iOS nicht hat - diese bleiben unberuehrt
- Nur die 5 Haupt-Navigation-Symbole muessen angeglichen werden
- Labels/Bezeichnungen unterscheiden sich auch leicht ("Bloecke" vs "Planen", "Rueckblick" vs "Review") - das ist ein separates Thema

## Analysis

### Type
Feature (kosmetisch)

### Entscheidung: Einheitliche Symbole

| Bereich | iOS vorher | macOS vorher | Neu (beide) |
|---------|-----------|--------------|-------------|
| Backlog | `list.bullet` | `tray.full` | `list.bullet` |
| Planen | `rectangle.split.3x1` | `calendar` | `calendar` |
| Zuweisen | `arrow.up.and.down.text.horizontal` | `arrow.up.arrow.down` | `arrow.up.arrow.down` |
| Focus | `target` | `target` | `target` |
| Review | `clock.arrow.circlepath` | `chart.bar` | `chart.bar` |

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Views/MainTabView.swift | MODIFY | 3 Symbole aendern (Zeilen 8, 13, 18, 28) |
| FocusBloxMac/SidebarView.swift | MODIFY | 1 Symbol aendern (Zeile 20: backlog) |

### Scope Assessment
- Files: 2
- Estimated LoC: ~4 geaendert
- Risk Level: NULL (rein kosmetisch)
