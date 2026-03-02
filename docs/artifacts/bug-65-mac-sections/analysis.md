# Bug 65: macOS Listendarstellung — fehlende Sektionen

## Symptom
iOS zeigt in der Priority-Ansicht bis zu 6 Sektionen: "Next Up", "Ueberfaellig", "Sofort erledigen", "Bald einplanen", "Bei Gelegenheit", "Irgendwann".
macOS zeigt nur 2: "Next Up" und "Backlog" (alles in einem Topf).

## Agenten-Ergebnisse (5 parallele Investigations)

### 1. Wiederholungs-Check
- Kein bisheriger Fix fuer dieses Problem — war nie implementiert
- BACKLOG-004 dokumentiert die BacklogView/BacklogRow Duplikation (~400 LoC)
- iOS Priority-Sektionen kamen mit ITB-B (Smart Priority, Commit 7990fb6)
- macOS bekam nur Next Up Section (Commit b1a8b03)

### 2. Datenfluss-Trace
- **iOS:** `SyncEngine.sync()` → `[PlanItem]` → `PlanItem.priorityTier` → `ForEach(PriorityTier.allCases)` → Sektionen
- **macOS:** `@Query` → `[LocalTask]` → `regularFilteredTasks` (flat sorted) → EINE "Backlog" Section
- Scoring-Logik ist identisch (`TaskPriorityScoringService.calculateScore()`) — shared Code
- Aber macOS ruft sie nur zum Sortieren auf, nicht zum Gruppieren

### 3. Section-Definitionen
- **iOS:** `BacklogView.swift:829-854` — `ForEach(PriorityTier.allCases)` mit tier-gefiltertem Content
- **macOS:** `ContentView.swift:367-409` — EINE Section "Backlog" fuer alle Tasks
- `PriorityTier` Enum existiert im shared Code (`TaskPriorityScoringService.swift:10-33`)
- `priorityTier` Property existiert NUR auf `PlanItem` (Zeile 77), NICHT auf `LocalTask`

### 4. Szenarien-Analyse
- NICHT intentional weniger Sektionen — Architecture-Refactoring war unvollstaendig
- macOS nutzt `LocalTask` direkt statt `PlanItem` Wrapper
- Gleiche `SidebarFilter` Enum (priority/recent/overdue/recurring/completed) existiert
- Section-UI-Code wurde nie auf macOS uebertragen

### 5. Blast Radius
- Primaer: `FocusBloxMac/ContentView.swift` (~100-150 LoC Aenderung)
- `MacBacklogRow.swift` braucht KEINE Aenderung (zeigt bereits Priority-Score-Badge)
- `SidebarView.swift` braucht KEINE Aenderung (Filter schon korrekt)
- Search, Swipe-Actions, Context-Menu funktionieren pro-Section (kein Impact)
- **Drag & Drop: RISIKO** — `moveRegularTasks()` arbeitet mit flacher Liste + IndexSet

## Hypothesen

### Hypothese 1: Sektionen wurden nie auf macOS implementiert (HOECHSTE Wahrscheinlichkeit)
- **Beweis DAFUER:** ContentView.swift:367-409 hat exakt EINE "Backlog" Section ohne Tier-Unterteilung. Kein `ForEach(PriorityTier.allCases)`. Kein Overdue-Section.
- **Beweis DAGEGEN:** Keine — es gibt kein Commit das Sektionen entfernt haette
- **Wahrscheinlichkeit:** SEHR HOCH (99%)

### Hypothese 2: macOS nutzt bewusst eine flachere Darstellung
- **Beweis DAFUER:** macOS-Desktop hat mehr Platz, flache Liste koennte gewollt sein
- **Beweis DAGEGEN:** Bug 65 wurde explizit als "divergiert" dokumentiert. Keine Design-Entscheidung.
- **Wahrscheinlichkeit:** NIEDRIG (5%)

### Hypothese 3: PlanItem-Abstraktionsschicht fehlt auf macOS
- **Beweis DAFUER:** `LocalTask` hat kein `priorityTier` Property. macOS nutzt `LocalTask` direkt.
- **Beweis DAGEGEN:** `TaskPriorityScoringService.calculateScore()` wird bereits direkt aufgerufen (ContentView:256-266). Tier kann inline berechnet werden.
- **Wahrscheinlichkeit:** MITTEL als Erklaerung WARUM es fehlte, aber kein Blocker

## Root Cause

**Sektionen wurden nie auf macOS implementiert.** iOS bekam die Priority-Tier-Sektionen mit ITB-B (Smart Priority), aber macOS ContentView.swift wurde nicht aktualisiert. Bekanntes Pattern der Plattform-Divergenz (BACKLOG-004).

## Challenge-Ergebnisse (Devil's Advocate)

**Verdict: LUECKEN → adressiert**

Offene Punkte aus dem Challenge, die im Fix beruecksichtigt werden muessen:

1. **Drag & Drop bricht:** `moveRegularTasks()` nutzt flache `regularFilteredTasks`-Liste + IndexSet. Mit Tier-Sections wuerden IndexSets section-lokal sein → falsches Reordering. **Loesung:** In Priority-Tier-Sections kein `.onMove` anbieten (Sortierung ist score-basiert, nicht manuell).

2. **Overdue-Dedup:** iOS filtert Overdue-Tasks aus Tier-Sections (`!overdueTasks.contains`). macOS braucht eine `overdueTasks`-Variable fuer die Priority-View. **Loesung:** Neue computed property `overdueTasks` in ContentView.

3. **Einfachere Loesung:** `LocalTask`-Extension NICHT noetig — `TaskPriorityScoringService` wird bereits direkt auf `LocalTask`-Properties aufgerufen (ContentView:256). Tier-Berechnung kann inline passieren.

4. **Separate priorityView:** Statt die bestehende `backlogView` mit bedingten Section-Switches aufzublaehen, besser eine eigene `priorityBacklogView` Property erstellen (analog iOS `priorityView`). Cleanere Architektur.

## Fix-Ansatz (ueberarbeitet nach Challenge)

### Nur 1 Datei: `FocusBloxMac/ContentView.swift`

1. **Neue computed property `overdueTasks`:** Filtert Tasks mit dueDate < heute aus `visibleTasks`
2. **Neue property `priorityBacklogView`:** Analog zu iOS `priorityView` — Overdue-Section + ForEach(PriorityTier.allCases) mit inline Tier-Berechnung. Kein `.onMove` (score-basierte Sortierung).
3. **`backlogView` anpassen:** Bei `selectedFilter == .priority` die neue `priorityBacklogView` nutzen statt der flachen Section. Alle anderen Filter bleiben unveraendert.

### Call-Sites
- `priorityBacklogView` wird in `backlogView` aufgerufen (conditional auf `.priority` Filter)
- `overdueTasks` wird in `priorityBacklogView` aufgerufen
- `TaskPriorityScoringService.PriorityTier.from(score:)` wird inline aufgerufen

### Kein Shared-Code-Impact
- KEIN `LocalTask`-Extension noetig
- Alle Aenderungen nur in `FocusBloxMac/ContentView.swift`
- Scoring-Service wird bereits korrekt verwendet

### Blast Radius
- `MacBacklogRow` — keine Aenderung
- `SidebarView` — keine Aenderung
- Search — funktioniert weiter (matchesSearch pro Task in jeder Section)
- Swipe Actions — funktionieren weiter (pro Task, identischer Code)
- **Drag & Drop:** Deaktiviert fuer Priority-Tier-Sections (score-basierte Sortierung)

### Geschaetzte Groesse
- 1 Datei, ~100-120 LoC (neue Properties + Section-UI)
- Innerhalb Scoping Limits
