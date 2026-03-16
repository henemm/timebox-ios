# Context: Disziplin-Entwicklung sichtbar machen

## Request Summary
Historische Auswertung ueber Wochen/Monate — welche Disziplinen hat der User gestaerkt? Der User soll sehen, wie sich sein Disziplin-Profil ueber die Zeit entwickelt.

## User Story Referenz
`docs/project/stories/monster-coach.md` — Erfolgskriterium:
> "Ich sehe ueber die Zeit an welchen Disziplinen ich gewachsen bin"

## Related Files

| File | Relevanz |
|------|----------|
| `Sources/Models/Discipline.swift` | 4 Disziplinen (Konsequenz/Ausdauer/Mut/Fokus), `classify()` fuer completed Tasks, `classifyOpen()` fuer offene, `resolveOpen()` mit Manual Override |
| `Sources/Models/CoachType.swift` | 1:1 Mapping Coach↔Discipline (Troll=Konsequenz, Feuer=Mut, Eule=Fokus, Golem=Ausdauer), `DailyCoachSelection` (AppGroup UserDefaults, ein Key pro Tag) |
| `Sources/Models/LocalTask.swift` | SwiftData `@Model` mit `completedAt: Date?`, `rescheduleCount: Int`, `importance: Int?`, `estimatedDuration: Int?`, `manualDiscipline: String?` |
| `Sources/Models/ReviewStatsCalculator.swift` | Bestehendes Stats-Pattern: `computeCategoryMinutes()`, `computePlanningAccuracy()` — nutzt nur TaskCategory, NICHT Discipline |
| `Sources/Views/ReviewComponents.swift` | UI-Bausteine: `CategoryBar` (Fortschrittsbalken), `StatItem`, `AccuracyPill` — wiederverwendbar als Vorbild fuer DisciplineBar |
| `Sources/Views/CoachMeinTagView.swift` | "Mein Tag" im Coach-Modus — hat Heute/Woche-Picker, `weekProgressSection` (nur Gesamtzahl), `weeklyReflectionSection` — HIER wuerde Discipline-Breakdown integriert |
| `Sources/Views/DailyReviewView.swift` | Standard-Review ohne Coach — hat CategoryBar-Breakdown, Planning Accuracy — Pattern-Vorbild |
| `Sources/Services/IntentionEvaluationService.swift` | `completedToday()`, `completedThisWeek()`, `evaluateFulfillment()` — hat KEINE Discipline-Aggregation |
| `Sources/Services/EveningReflectionTextService.swift` | AI-Abendtext per Coach — keine Discipline-Stats |
| `Sources/Views/CoachBacklogView.swift` | Discipline-Override Context Menu (iOS) |
| `FocusBloxMac/MacCoachBacklogView.swift` | Discipline-Override Context Menu (macOS) |

## Bestehendes Discipline-System

### 4 Disziplinen
| Discipline | Farbe | Icon | Coach | Monster |
|-----------|-------|------|-------|---------|
| Konsequenz | Gruen | arrow.trianglehead.counterclockwise | Troll | monsterKonsequenz |
| Ausdauer | Grau | figure.walk | Golem | monsterAusdauer |
| Mut | Rot | flame | Feuer | monsterMut |
| Fokus | Blau | scope | Eule | monsterFokus |

### Klassifikation
- **Offene Tasks** (`classifyOpen`): rescheduleCount>=2 → Konsequenz, importance==3 → Mut, sonst → Ausdauer (Fokus nicht bestimmbar)
- **Erledigte Tasks** (`classify`): rescheduleCount>=2 → Konsequenz, importance==3 → Mut, effectiveDuration<=estimated → Fokus, sonst → Ausdauer
- **Manual Override**: `manualDiscipline` auf LocalTask hat Vorrang

### Was EXISTIERT
- Discipline-Enum mit classify/resolveOpen
- manualDiscipline auf LocalTask (CloudKit-synced)
- completedAt auf jedem Task
- DailyCoachSelection pro Tag in UserDefaults (Key-Schema `dailyCoach_YYYY-MM-DD`)
- CategoryBar als visuelles Pattern
- Heute/Woche Picker in CoachMeinTagView

### Was FEHLT
- **Keine Discipline-Aggregation**: `classify()` wird NIE auf completed Tasks aufgerufen (nur in Tests)
- **Kein DisciplineStatsCalculator**: Kein Pendant zu ReviewStatsCalculator fuer Disziplinen
- **Keine historische Ansicht**: Weder Wochen-Verlauf noch Monats-Trend
- **Kein Swift Charts**: Nirgendwo im Projekt verwendet
- **Keine Coach-History-API**: `DailyCoachSelection.load()` laedt nur heute — keine Enumeration vergangener Tage
- **FulfillmentLevel wird nicht persistiert**: Taegliche Fulfillment-Bewertung ist nur live berechnet, nicht gespeichert

## Existing Patterns (Vorbild fuer Implementation)

### CategoryBar Pattern (ReviewComponents.swift)
```
CategoryStat { config: TaskCategory, minutes: Int }
CategoryBar(stat:totalMinutes:) → Icon + Name + Zeit + Fortschrittsbalken
```
→ Analog: `DisciplineStat { discipline: Discipline, count: Int }` + `DisciplineBar`

### ReviewStatsCalculator Pattern
```
func computeCategoryMinutes(tasks:calendarEvents:) -> [String: Int]
```
→ Analog: `func computeDisciplineBreakdown(tasks: [LocalTask]) -> [Discipline: Int]`

### CoachMeinTagView Woche-Pattern
```
weekProgressSection → "X Tasks diese Woche erledigt" (nur Gesamtzahl)
weeklyReflectionSection → Coach-Fulfillment Badge + Text
```
→ Erweiterung: Discipline-Breakdown unterhalb der Gesamtzahl

## Dependencies
- **Upstream**: `LocalTask` (SwiftData), `Discipline.classify()`, `IntentionEvaluationService.completedThisWeek()`
- **Downstream**: `CoachMeinTagView` (beide Plattformen via shared Code)

## Existing Specs
- `docs/specs/features/discipline-override.md` — Manual Discipline Override (ERLEDIGT)
- `docs/project/stories/monster-coach.md` — Gesamt-User-Story

## Daten-Verfuegbarkeit (WICHTIG)

### Fuer Woche/Monat: Retroaktiv berechenbar
Jeder `LocalTask` mit `completedAt != nil` hat alle Felder fuer `Discipline.classify()`:
- `rescheduleCount`, `importance`, `estimatedDuration`, `manualDiscipline`
- Kein neues Schema noetig — Daten existieren bereits

### Fuer Coach-Wahl-Historie: Teilweise vorhanden
- `dailyCoach_YYYY-MM-DD` Keys in UserDefaults — nicht geloescht, aber keine Enumeration
- Man muesste Tag fuer Tag rueckwaerts iterieren (fragil, unzuverlaessig)

### Fuer Fulfillment-Historie: NICHT vorhanden
- FulfillmentLevel wird live berechnet, nicht persistiert
- Nachtraeglich nicht rekonstruierbar (Focus Blocks von vergangenen Tagen evtl. geloescht)

## Risiken & Einschraenkungen
1. **Completed Tasks ohne Duration**: Tasks die per "Erledigt"-Toggle abgehakt werden (nicht in Sprint) haben evtl. keine effectiveDuration → classify() nutzt Fallback (Ausdauer)
2. **UserDefaults Coach-History**: Nicht zuverlaessig fuer Langzeit-Analyse (werden bei App-Neuinstallation geloescht)
3. **Keine Swift Charts Erfahrung im Projekt**: Erster Einsatz — Lernkurve, aber iOS 17+ Standard
4. **Performance bei grosser Task-History**: classify() pro Task ist O(1), aber Fetch aller completed Tasks koennte bei Hunderten Tasks relevant sein
5. **Cross-Platform**: View muss in `Sources/Views/` (shared) — kein macOS-spezifischer Code noetig

---

## Analysis (Phase 2)

### Type
Feature

### Scope-Problem: User Story vs. Scoping Limits
Die User Story verlangt "Auswertung ueber Wochen/Monate" — das ist ein breites Feature. Um innerhalb der ±250 LoC Grenze zu bleiben, wird in 2 Phasen aufgeteilt:

**Phase 1 (dieses Ticket):** Wochen-Disziplin-Breakdown in CoachMeinTagView
- Zeigt fuer "Diese Woche": Wieviele Tasks pro Disziplin erledigt
- Visuell: 4 farbige Balken (analog CategoryBar) — Konsequenz/Mut/Fokus/Ausdauer
- Nutzt `Discipline.classify()` retroaktiv auf erledigte Tasks
- Zusaetzlich: "Heute" zeigt Tages-Breakdown

**Phase 2 (separates Ticket, Backlog):** Multi-Wochen-Trend mit Swift Charts
- 4-8 Wochen Verlauf als gestapeltes Balkendiagramm
- Trend-Erkennung ("Konsequenz waechst, Fokus stagniert")
- Erfordert Charts Framework + komplexere Aggregation

### Affected Files (Phase 1)

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `Sources/Services/DisciplineStatsService.swift` | CREATE | Neuer Service: `breakdownForTasks([LocalTask]) -> [DisciplineStat]` |
| `Sources/Views/ReviewComponents.swift` | MODIFY | Neuer `DisciplineBar` (analog `CategoryBar`) + `DisciplineStat` struct |
| `Sources/Views/CoachMeinTagView.swift` | MODIFY | Discipline-Breakdown-Section in Heute + Woche einfuegen |
| `FocusBloxTests/DisciplineStatsServiceTests.swift` | CREATE | Unit Tests fuer Aggregation + Klassifikation |
| `FocusBloxUITests/DisciplineHistoryUITests.swift` | CREATE | UI Tests: Balken sichtbar, korrekte Werte |

### Scope Assessment
- **Files:** 5 (2 CREATE, 3 MODIFY)
- **Estimated LoC:** +180/-0 (neuer Code, keine Loeschungen)
- **Risk Level:** LOW
  - Keine Schema-Aenderungen
  - Keine bestehende Logik wird geaendert
  - Daten existieren bereits
  - Rein additive Aenderung in CoachMeinTagView

### Technischer Ansatz (Empfehlung)

1. **DisciplineStatsService** (~40 LoC):
   - `static func breakdownForTasks(_ tasks: [LocalTask]) -> [DisciplineStat]`
   - Pro Task: `manualDiscipline` pruefen, sonst `Discipline.classify()` aufrufen
   - Ergebnis: 4 `DisciplineStat` Eintraege (immer alle 4, auch wenn count=0)

2. **DisciplineBar + DisciplineStat** (~35 LoC in ReviewComponents.swift):
   - `DisciplineStat { discipline: Discipline, count: Int }`
   - `DisciplineBar` analog `CategoryBar`: Monster-Icon + Name + Count + Prozent-Balken

3. **CoachMeinTagView Integration** (~40 LoC):
   - Neue `disciplineBreakdownSection` unterhalb `weekProgressSection`
   - Header "Dein Disziplin-Profil" mit Monster-Icons
   - 4x DisciplineBar sortiert nach Count (absteigend)

4. **Unit Tests** (~50 LoC):
   - Leere Task-Liste → alle Counts 0
   - Gemischte Tasks → korrekte Verteilung
   - Manual Override hat Vorrang
   - Nur completed Tasks zaehlen

5. **UI Tests** (~30 LoC):
   - Discipline-Section sichtbar in Wochenansicht
   - Alle 4 Disziplin-Balken vorhanden

### Dependencies
- **Upstream:** `Discipline.classify()`, `LocalTask` (SwiftData), `IntentionEvaluationService.completedThisWeek()`
- **Downstream:** `CoachMeinTagView` (shared iOS + macOS — ein Codeaenderung fuer beide Plattformen)

### Open Questions
- Keine — Ansatz ist klar, Daten vorhanden, Pattern etabliert
