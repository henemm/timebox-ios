# Bug-Analyse: BacklogView Toolbar-Inkonsistenz (#285)

## Root Cause

BacklogView hat eine eigene manuelle Toolbar mit 4 Buttons (plus, sparkles, viewModeSwitcher, gear).
Das `sparkles`-Icon ("Aufräumen"/Hygiene) war nie spezifiziert.
BacklogView und CoachView nutzen NICHT das gemeinsame `.withSettingsToolbar()`-Pattern.

## Ist-Zustand

| View | Toolbar-Pattern | Gear? | Extras |
|------|----------------|-------|--------|
| BacklogView | Manuell (4 Buttons) | Ja (inline) | sparkles (nie spezifiziert) |
| CoachView | Kein .toolbar | NEIN | — |
| BlockPlanningView | .withSettingsToolbar() | Ja | — |
| FocusLiveView | .withSettingsToolbar() | Ja | — |
| DailyReviewView | .withSettingsToolbar() | Ja | — |

## Soll-Zustand

- Sparkles aus BacklogView-Toolbar entfernen
- BacklogView: manuelles gear durch .withSettingsToolbar() ersetzen
- CoachView: .withSettingsToolbar() hinzufügen
- Hygiene-Feature bleibt über bestehendes In-List-Banner erreichbar
