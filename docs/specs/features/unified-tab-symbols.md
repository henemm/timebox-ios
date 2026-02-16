---
entity_id: unified-tab-symbols
type: feature
created: 2026-02-16
updated: 2026-02-16
status: draft
version: "1.0"
tags: [ui, cross-platform, sf-symbols]
---

# Einheitliche Symbole Tab-Bar/Sidebar

## Approval

- [ ] Approved

## Purpose

iOS Tab-Bar und macOS Toolbar/Sidebar nutzen unterschiedliche SF Symbols fuer die gleichen 5 Navigations-Bereiche. Beide Plattformen sollen identische Symbole verwenden fuer ein konsistentes Nutzererlebnis.

## Source

- **File (iOS):** `Sources/Views/MainTabView.swift`
- **File (macOS):** `FocusBloxMac/SidebarView.swift` (MainSection enum)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SF Symbols | Framework | Icon-Rendering |

## Implementation Details

### Symbol-Mapping (vorher → nachher)

| Bereich | iOS vorher | macOS vorher | Neu (beide) |
|---------|-----------|--------------|-------------|
| Backlog | `list.bullet` | `tray.full` | `list.bullet` |
| Planen | `rectangle.split.3x1` | `calendar` | `calendar` |
| Zuweisen | `arrow.up.and.down.text.horizontal` | `arrow.up.arrow.down` | `arrow.up.arrow.down` |
| Focus | `target` | `target` | `target` (keine Aenderung) |
| Review | `clock.arrow.circlepath` | `chart.bar` | `chart.bar` |

### Aenderungen pro Datei

**MainTabView.swift (iOS) - 3 Aenderungen:**
- Zeile 13: `rectangle.split.3x1` → `calendar`
- Zeile 18: `arrow.up.and.down.text.horizontal` → `arrow.up.arrow.down`
- Zeile 28: `clock.arrow.circlepath` → `chart.bar`

**SidebarView.swift (macOS) - 1 Aenderung:**
- Zeile 20: `tray.full` → `list.bullet`

## Expected Behavior

- **Input:** Keine (rein visuelle Aenderung)
- **Output:** Identische SF Symbols auf beiden Plattformen
- **Side effects:** Keine - Labels bleiben unveraendert

## Test Plan

- UI Test (iOS): Pruefen dass Tab-Bar die korrekten accessibility identifiers hat
- UI Test (macOS): Nicht testbar (Toolbar-Picker), Unit Test fuer MainSection.icon Werte

## Known Limitations

- Labels unterscheiden sich weiterhin ("Bloecke" vs "Planen", "Rueckblick" vs "Review") - separates Item
- macOS Sidebar-Filter-Icons (Next Up, TBD, etc.) bleiben unberuehrt

## Scope

- **Files:** 2
- **LoC:** ~4 geaendert
- **Risk:** NULL (rein kosmetisch)

## Changelog

- 2026-02-16: Initial spec created
