# Context: FEATURE_023 — Disziplin-Trend (Multi-Wochen)

## Request Summary
Multi-Wochen-Trend-Ansicht fuer das Disziplin-Profil in CoachMeinTagView. Gestapeltes Balkendiagramm (4-8 Wochen) mit Swift Charts, Trend-Erkennung und staerkstes/schwaechstes Disziplin-Highlight. Aufbauend auf FEATURE_016 (Phase 1: Disziplin-Profil Heute+Woche — bereits erledigt).

## User Story Referenz
`docs/project/stories/monster-coach.md` — Erfolgskriterium:
> "Ich sehe ueber die Zeit an welchen Disziplinen ich gewachsen bin"

## Related Files

| File | Relevanz |
|------|----------|
| `Sources/Models/Discipline.swift` | 4 Disziplinen (enum), `classify()` + `classifyOpen()`, Farben/Icons/Monster-Images |
| `Sources/Services/DisciplineStatsService.swift` | `breakdown(for:)` — berechnet DisciplineStat-Array fuer beliebige Task-Liste. Kern-Aggregationslogik wiederverwendbar |
| `Sources/Views/ReviewComponents.swift` | `DisciplineStat` struct + `DisciplineBar` View — bestehende Datentypen |
| `Sources/Views/CoachMeinTagView.swift` | Integrationspunkt: Hier wird der Trend-Chart eingefuegt (Woche-Tab, 303 LoC aktuell) |
| `Sources/Services/IntentionEvaluationService.swift` | `completedToday()`, `completedThisWeek()` — Pattern fuer Datums-Filterung, aber KEINE Multi-Wochen-Methode |
| `Sources/Models/LocalTask.swift` | SwiftData Model mit `completedAt: Date?`, `rescheduleCount`, `importance`, `estimatedDuration`, `manualDiscipline` |
| `Sources/Models/CoachType.swift` | Coach↔Discipline Mapping (Troll=Konsequenz, Feuer=Mut, Eule=Fokus, Golem=Ausdauer) |
| `docs/specs/features/discipline-history.md` | Phase-1-Spec (erledigt) — dokumentiert Architekturentscheidungen |
| `docs/context/discipline-history.md` | Phase-1-Kontext — Daten-Verfuegbarkeitsanalyse, Pattern-Referenzen |

## Was EXISTIERT (Phase 1, erledigt)

### Daten-Layer
- **DisciplineStatsService.breakdown(for:)** — nimmt `[LocalTask]`, gibt `[DisciplineStat]` zurueck
- **Discipline.classify()** — Klassifikation anhand rescheduleCount/importance/duration
- **IntentionEvaluationService** — Datums-Filterung (completedToday, completedThisWeek)
- **LocalTask.completedAt** — Timestamp fuer alle erledigten Tasks, nie geloescht

### UI-Layer
- **DisciplineStat** — `{ discipline: Discipline, count: Int, total: Int }`
- **DisciplineBar** — Horizontaler Fortschrittsbalken mit Monster-Icon + Farbe
- **disciplineBreakdownSection()** — Card mit Header "Dein Disziplin-Profil"
- Integration in CoachMeinTagView fuer Heute + Diese Woche

### Tests
- Unit Tests: `DisciplineStatsServiceTests.swift` (6 Tests)
- UI Tests: `DisciplineHistoryUITests.swift` (3 Tests)
- Unit Tests: `DisciplineTests.swift` (10 Tests fuer classify/resolveOpen)

## Was FEHLT (Phase 2, dieses Ticket)

1. **Multi-Wochen-Aggregation** — Methode die Tasks in Wochen-Buckets aufteilt (4-8 Wochen zurueck)
2. **Swift Charts** — Framework ist NICHT im Projekt. Erster Einsatz
3. **Gestapeltes Balkendiagramm** — 4 Disziplinen pro Woche gestapelt
4. **Trend-Erkennung** — z.B. "Konsequenz waechst seit 3 Wochen"
5. **Staerkstes/Schwaechstes Highlight** — Ueber Gesamtzeitraum berechnet
6. **Trend-View** — Neue SwiftUI View mit Chart + Trend-Text

## Existing Patterns

### DisciplineStatsService (wiederverwendbar)
```
DisciplineStatsService.breakdown(for: [LocalTask]) -> [DisciplineStat]
```
Funktioniert fuer JEDE gefilterte Task-Liste. Multi-Wochen = breakdown() N-mal aufrufen mit woechentlich gefilterter Liste.

### IntentionEvaluationService Wochen-Pattern
```swift
let calendar = Calendar.current
guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
return tasks.filter { completedAt >= weekInterval.start && completedAt < weekInterval.end }
```
Erweitern: Rueckwaerts iterieren fuer vergangene Wochen.

### ReviewComponents Bar-Pattern
DisciplineBar nutzt `GeometryReader` + `RoundedRectangle` fuer einfache Balken.
Swift Charts ersetzt dieses Pattern fuer den Trend-Chart (professionellere Visualisierung).

### CoachMeinTagView Glassmorphismus
Bestehende Sections nutzen `.ultraThinMaterial` + `RoundedRectangle(cornerRadius: 16)`.

## Dependencies

### Upstream
- `LocalTask` (SwiftData) — Datenquelle, `completedAt` fuer Wochen-Zuordnung
- `Discipline.classify()` — Klassifikationslogik
- `DisciplineStatsService.breakdown()` — Aggregationslogik (wiederverwendbar)
- `IntentionEvaluationService` — Pattern fuer Datums-Filterung
- **Swift Charts Framework (NEU)** — Apple-Framework, seit iOS 16, keine externe Dependency

### Downstream
- `CoachMeinTagView` (shared iOS + macOS) — einzige View die den Trend anzeigt

## Existing Specs
- `docs/specs/features/discipline-history.md` — Phase-1-Spec (erledigt)
- `docs/specs/features/discipline-override.md` — Manual Override (erledigt)
- `docs/project/stories/monster-coach.md` — Gesamt-User-Story

## Daten-Verfuegbarkeit

### Retroaktiv berechenbar (kein neues Schema noetig)
- Jeder `LocalTask` mit `completedAt != nil` hat alle Felder fuer `Discipline.classify()`
- Tasks werden nie geloescht — alle historischen Daten vorhanden
- Wochen-Buckets: `Calendar.dateInterval(of: .weekOfYear, for: date)` fuer beliebige vergangene Wochen
- `DisciplineStatsService.breakdown()` akzeptiert jede `[LocalTask]`-Liste

### Limitierungen
- Tasks ohne `completedAt` (alte Daten vor dem Feature) fehlen im Trend
- Tasks per Toggle erledigt (ohne Focus Block) haben keine `effectiveDuration` → klassifiziert als Ausdauer
- Keine Persistierung der Aggregation — live berechnet bei jedem View-Load
- Performance: Bei vielen Tasks muss N-mal gefiltert werden (N=Wochen)

## Risiken & Einschraenkungen

1. **Erster Swift Charts Einsatz**: Kein bestehendes Pattern im Projekt. Aber: Apple-Standard-Framework, gut dokumentiert
2. **Leere Wochen**: User koennte Wochen ohne erledigte Tasks haben → Chart muss das sauber darstellen
3. **Wenige Daten**: Bei neuem User gibt es vielleicht nur 1-2 Wochen → Mindestens 2 Wochen fuer sinnvollen Trend
4. **Performance**: 8 Wochen × alle Tasks filtern. Bei 500 Tasks: 4000 Iterationen — kein Problem
5. **Cross-Platform**: Swift Charts funktioniert auf iOS 16+ UND macOS 13+ — shared Code moeglich
6. **Scoping**: Feature hat 3 Teilaspekte (Chart, Trend-Text, Highlights) — muss unter ±250 LoC bleiben

---

## Analysis (Phase 2)

### Type
Feature

### Affected Files

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `Sources/Services/DisciplineStatsService.swift` | MODIFY | +`weeklyHistory(tasks:weeksBack:now:)` fuer Multi-Wochen-Aggregation, +`trends(from:)` fuer Trend-Erkennung (~60 LoC) |
| `Sources/Views/ReviewComponents.swift` | MODIFY | +`WeeklyDisciplineSnapshot` struct, +`DisciplineTrend` struct, +`TrendDirection` enum (~40 LoC) |
| `Sources/Views/DisciplineTrendChart.swift` | CREATE | Neue View: Gestapeltes Balkendiagramm (Swift Charts) + Trend-Highlights + Accessibility (~90 LoC) |
| `Sources/Views/CoachMeinTagView.swift` | MODIFY | ReviewMode um `.trend` erweitern, lazy Data-Loading, Trend-Section einfuegen (~50 LoC) |

Test-Dateien (separat):
| `FocusBloxTests/DisciplineTrendServiceTests.swift` | CREATE | Unit Tests: weeklyHistory(), trends(), Edge Cases |
| `FocusBloxUITests/DisciplineTrendUITests.swift` | CREATE | UI Tests: Trend-Tab, Chart sichtbar, Highlights |

### Scope Assessment
- **Files:** 4 Produktiv-Dateien (1 CREATE, 3 MODIFY) + 2 Test-Dateien
- **Estimated LoC:** ~240 (knapp innerhalb ±250 Limit)
- **Risk Level:** LOW-MEDIUM (Swift Charts Erstnutzung, aber Apple-Standard)

### Technischer Ansatz (Empfehlung)

**DisciplineStatsService erweitern (kein neuer Service):**
- `weeklyHistory(tasks:weeksBack:now:)` → `[WeeklyDisciplineSnapshot]`
  - Iteriert N Wochen rueckwaerts per `Calendar.dateInterval(of: .weekOfYear)`
  - Ruft bestehende `breakdown(for:)` pro Woche auf — maximale Wiederverwendung
- `trends(from:)` → `[DisciplineTrend]`
  - Prueft 3+ konsekutive Wochen mit monoton steigendem Prozentwert
  - Leere Wochen zaehlen nicht als Wachstum

**Neue Datentypen in ReviewComponents.swift:**
- `WeeklyDisciplineSnapshot { weekStart: Date, stats: [DisciplineStat] }`
- `DisciplineTrend { discipline: Discipline, direction: TrendDirection, consecutiveWeeks: Int }`
- `TrendDirection { growing, declining, stable }`

**DisciplineTrendChart.swift (neue Datei):**
- Swift Charts `BarMark` mit expliziten Disziplin-Farben (NICHT automatisches foregroundStyle(by:))
- X-Achse: Kalenderwochen (KW XX), Y-Achse: Task-Count
- Darunter: Trend-Text ("Konsequenz waechst seit 3 Wochen") + staerkstes/schwaechstes Highlight
- `.ultraThinMaterial` Card konsistent mit bestehenden Sections

**CoachMeinTagView: Dritter Segment "Trend":**
- ReviewMode erweitert um `.trend`
- Lazy Loading: Trend-Daten nur bei Segment-Wechsel berechnen
- Zeigt DisciplineTrendChart mit weeklyHistory-Daten

### Build-Reihenfolge
1. `WeeklyDisciplineSnapshot` + `DisciplineTrend` Structs (ReviewComponents) — alle anderen haengen davon ab
2. `DisciplineStatsService.weeklyHistory()` + `trends()` — Unit-testbar ohne UI
3. `DisciplineTrendChart.swift` — setzt Structs + Service voraus
4. `CoachMeinTagView` Integration — setzt alles voraus

### Dependencies
- **Upstream:** `LocalTask`, `Discipline.classify()`, `DisciplineStatsService.breakdown()`, Swift Charts Framework
- **Downstream:** `CoachMeinTagView` (shared iOS + macOS)
- **Cross-Platform:** Alles in `Sources/` — funktioniert automatisch auf beiden Plattformen

### Open Questions
- Keine — Ansatz ist klar, Daten vorhanden, Pattern etabliert
