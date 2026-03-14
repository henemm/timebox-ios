# Context: Monster Coach — Eigene Views im Coach-Modus

> Erstellt: 2026-03-14
> Workflow: feature-coach-views

## Problem

Der Coach-Modus streut aktuell Coach-Elemente in bestehende Views ein:
- BacklogView: `intentionFilterOptions` filtert Tasks hart weg (intransparent)
- DailyReviewView: MorningIntentionView + EveningReflectionCard als Karten eingebettet
- MainTabView: Tab-Label wechselt "Review" → "Mein Tag"

Das ist unuebersichtlich und verwirrend. Tasks verschwinden ohne Erklaerung.

## Loesung: Saubere View-Trennung

Coach AN = eigene Views pro Tab, keine Modifikationen an bestehenden Views.

| Tab | Coach AUS | Coach AN |
|-----|-----------|----------|
| Backlog | BacklogView | **CoachBacklogView** |
| Review/Mein Tag | DailyReviewView | **CoachMeinTagView** |
| Blox | BlockPlanningView | unveraendert |
| Focus | FocusLiveView | unveraendert |

## Betroffene Dateien

### Neu
- `Sources/Views/CoachBacklogView.swift` — Monster + gerankte Tasks + Discipline-Kreise
- `Sources/Views/CoachMeinTagView.swift` — MorningIntention + EveningReflection eigene View

### Aenderungen
- `Sources/Views/MainTabView.swift` — Bedingte View-Auswahl pro Tab
- `Sources/Views/BacklogView.swift` — Intention-Filter-Logik entfernen (wird in CoachBacklogView neu geloest)
- `Sources/Views/DailyReviewView.swift` — Coach-Karten entfernen (werden in CoachMeinTagView)

### Wiederverwendete Komponenten
- `MorningIntentionView` — bleibt unveraendert, wird in CoachMeinTagView eingebettet
- `EveningReflectionCard` — bleibt unveraendert, wird in CoachMeinTagView eingebettet
- `BacklogRow` — wird wiederverwendet, plus Discipline-Kreis-Erweiterung

### Model-Aenderungen
- `DailyIntention.swift` — `matchesFilter()` ergaenzen um `boostScore()` fuer Ranking
- `Discipline.swift` — `classifyOpen()` fuer offene Tasks (Phase 4b Logik)

## Abhaengigkeiten

- Discipline Enum (Sources/Models/Discipline.swift) — existiert
- DailyIntention Model (Sources/Models/DailyIntention.swift) — existiert
- IntentionOption.matchesFilter() — wird durch Ranking ersetzt
- Monster Assets (monsterFokus/Mut/Ausdauer/Konsequenz) — existieren in Assets.xcassets
- IntentionOption.monsterDiscipline Mapping — existiert

## PO-Entscheidungen (bereits getroffen)

1. **Ranking statt Hard-Filter** — Tasks nach oben sortieren, nicht ausblenden
2. **Eigene Views** — Komplett separate Views im Coach-Modus
3. **Monster + gerankte Tasks** im Backlog — Monster-Header oben, alle Tasks sichtbar
4. **Phase 4b integriert** — Farbige Discipline-Kreise nur in Coach-Views
