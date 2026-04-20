---
entity_id: toolbar-consistency
type: bugfix
created: 2026-04-20
updated: 2026-04-20
status: draft
version: "1.0"
tags: [toolbar, ui, consistency]
---

# Toolbar-Konsistenz: BacklogView + CoachView (Bug #285)

## Approval

- [ ] Approved

## Purpose

BacklogView hat einen nie spezifizierten "Sparkles"-Button (Backlog Hygiene) in der Toolbar und baut das Gear-Icon manuell statt das gemeinsame `.withSettingsToolbar()`-Pattern zu nutzen. CoachView hat gar kein Gear-Icon. Beide Views müssen auf das einheitliche Pattern umgestellt werden.

## Source

- **File:** `Sources/Views/BacklogView.swift` — Toolbar-Definition (Zeilen 198–223), `@State var showSettings` (Zeile 73)
- **File:** `Sources/Views/CoachView.swift` — kein `.toolbar`, kein `.withSettingsToolbar()`
- **Reference:** `Sources/Views/SettingsToolbarModifier.swift` — `.withSettingsToolbar()` Extension

## Implementation Details

### BacklogView — Toolbar bereinigen

1. `sparkles`-Button (Zeile 210, `showHygieneSheet`) aus der Toolbar ENTFERNEN
2. Manuelles `gear`-Icon aus der Toolbar ENTFERNEN
3. `@State private var showSettings = false` (Zeile 73) ENTFERNEN
4. Zugehöriges `.sheet(isPresented: $showSettings)` ENTFERNEN
5. `.withSettingsToolbar()` am Body der View anhängen

Die Toolbar behält nur: `plus` (Task erstellen) + `viewModeSwitcher`

Das Hygiene-Feature bleibt über das bestehende In-List-Banner erreichbar (`BacklogHygieneNudgeBanner`, ca. Zeile 1180).

### CoachView — Gear-Icon hinzufügen

`.withSettingsToolbar()` am Body der View anhängen. Fertig.

## Acceptance Criteria

1. BacklogView-Toolbar zeigt NUR: "+" Button und View-Mode-Switcher (kein Sparkles, kein manuelles Gear)
2. BacklogView hat ein Gear-Icon via `.withSettingsToolbar()` das Settings öffnet
3. CoachView hat ein Gear-Icon via `.withSettingsToolbar()` das Settings öffnet
4. Das Hygiene-Feature ("Aufräumen") ist weiterhin über das In-List-Banner erreichbar
5. Keine Regressions in anderen Views die `.withSettingsToolbar()` nutzen

## Known Limitations

- Der Sparkles-Einstieg verschwindet aus der Toolbar — User die ihn gewohnt waren müssen das Banner nutzen

## Changelog

- 2026-04-20: Initial spec
