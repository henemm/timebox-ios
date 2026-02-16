# Context: Report - Tasks ausserhalb Sprints

## Request Summary
Tasks die ausserhalb eines FocusBlocks (im Backlog) abgehakt werden, erscheinen nicht im Tagesreport. Eigene Sektion "Ausserhalb von Sprints erledigt" hinzufuegen.

## Problem-Analyse

### iOS (DailyReviewView.swift)
- `computeCategoryStats()` zaehlt NUR Tasks deren ID in `block.completedTaskIDs` steht
- `totalCompleted` zaehlt nur `block.completedTaskIDs.count`
- `blocksSection` zeigt nur Block-zugeordnete Tasks
- `loadData()` laedt zwar ALLE LocalTasks (Zeile 559), aber filtert sie nie nach `completedAt`
- **Kein Zugriff auf `completedAt`-Datum** - nur auf Block-Zuordnung

### macOS (MacReviewView.swift)
- `todayTasks` filtert korrekt nach `completedAt >= startOfToday` via `@Query`
- `DayReviewContent` erhaelt `completedTasks` Parameter
- ABER: `totalCompleted` zaehlt auch nur `blocks.reduce(0) { $0 + $1.completedTaskIDs.count }`
- Die `completedTasks` werden nur fuer Kategorie-Stats und Block-Cards genutzt
- **Gleiche Luecke**: Tasks ausserhalb von Blocks werden in Stats gezaehlt, aber nicht als eigene Sektion angezeigt

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/DailyReviewView.swift` | MODIFY - Hauptaenderung iOS: Sektion + Stats |
| `FocusBloxMac/MacReviewView.swift` | MODIFY - Hauptaenderung macOS: Sektion in DayReviewContent |
| `Sources/Views/ReviewComponents.swift` | Shared Components (StatItem, CategoryBar) - evtl. ReviewTaskRow |
| `Sources/Views/SprintReviewSheet.swift` | Hat ReviewTaskRow - wiederverwendbar |
| `Sources/Models/ReviewStatsCalculator.swift` | READ - Verstehen wie Stats berechnet werden |
| `Sources/Models/LocalTask.swift` | READ - completedAt, isCompleted Felder |
| `Sources/Models/PlanItem.swift` | READ - completedAt Property |

## Bestehende Patterns
- Block-Tasks werden via `block.completedTaskIDs.contains(task.id)` identifiziert
- `ReviewTaskRow` zeigt einen einzelnen Task mit Checkmark + Titel + Duration
- macOS `DayReviewContent` bekommt `completedTasks: [LocalTask]` separat
- iOS `DailyReviewView` hat `allTasks: [PlanItem]` mit ALLEN Tasks

## Loesung
1. Identifiziere "Outside-Sprint" Tasks: `completedAt` am heutigen Tag, ABER ID NICHT in irgendeinem `block.completedTaskIDs`
2. Eigene Sektion nach den Block-Cards anzeigen
3. In Stats-Header mitzaehlen (optional: als separater Counter)
4. Auf beiden Plattformen (iOS + macOS) implementieren

## Abhaengigkeiten
- Upstream: FocusBlock (completedTaskIDs), LocalTask (completedAt), PlanItem
- Downstream: Keine - rein additive Aenderung

## Risiken
- GERING: Rein additive UI-Sektion, keine bestehende Logik wird geaendert
- PlanItem.completedAt muss verfuegbar sein (pruefen ob aus LocalTask gemappt)
