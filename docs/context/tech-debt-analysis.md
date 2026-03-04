# Technische Schulden — Gewichtete Analyse

> Erstellt: 2026-03-03
> Workflow: tech-debt-analysis

---

## Gewichtete Gesamtliste

### Bewertungskriterien
- **Impact:** Wie stark beeinflusst es Wartbarkeit/Bugs/Performance?
- **Risiko:** Was passiert wenn wir es NICHT beheben?
- **Aufwand:** Wie viel Arbeit ist es?
- **Score:** Impact (1-5) x Risiko (1-5) / Aufwand (1-5) = gewichteter Score

---

## Tier 1: KRITISCH (Score >= 4.0)

### TD-01: God-Views (BlockPlanningView 1400 LoC, BacklogView 1181 LoC)
- **Was:** Zwei Views haben >1000 LoC mit 14-26 @State-Properties
- **Impact:** 5/5 — Jedes neue Feature macht sie komplexer
- **Risiko:** 5/5 — Bugs durch State-Interaktionen, untestbar
- **Aufwand:** 4/5 (L) — Refactoring in Sub-Views + State-Extraction
- **Score:** 6.25
- **Betroffene Dateien:**
  - Sources/Views/BlockPlanningView.swift (1400 LoC, 14 @State)
  - Sources/Views/BacklogView.swift (1181 LoC, 26 @State)

### TD-02: macOS/iOS View-Duplikation (~9000 LoC doppelt)
- **Was:** 6 Screen-Paare existieren parallel mit duplizierten Business-Logik
- **Impact:** 5/5 — Bugs muessen 2x gefixt werden, Feature-Divergenz
- **Risiko:** 5/5 — Historisch groesste Fehlerquelle (Bug 55, 65, 66 etc.)
- **Aufwand:** 5/5 (XL) — Architektur-Entscheidung noetig
- **Score:** 5.0
- **Betroffene Paare:**
  | iOS | macOS | LoC gesamt |
  |-----|-------|-----------|
  | BacklogView (1181) | ContentView (1044) | 2225 |
  | BlockPlanningView (1400) | MacPlanningView (646) | 2046 |
  | FocusLiveView (751) | MacFocusView (1029) | 1780 |
  | DailyReviewView (625) | MacReviewView (723) | 1348 |
  | TaskAssignmentView (667) | MacAssignView (481) | 1148 |
  | BacklogRow (424) | MacBacklogRow (429) | 853 |

### TD-03: Fehlende Unit Tests fuer 4 kritische Services
- **Was:** NotificationService, FocusBlockActionService, TaskPriorityScoringService, GapFinder haben 0 Unit Tests
- **Impact:** 5/5 — Kern-Business-Logik ungetestet
- **Risiko:** 4/5 — Scoring-Bugs, Notification-Fehler, Completion-Bugs
- **Aufwand:** 3/5 (M) — ~40 neue Tests
- **Score:** 6.67
- **Details:**
  | Service | LoC | Testbare Funktionen | Aufwand |
  |---------|-----|---------------------|---------|
  | NotificationService | 359 | 10 (build-Methoden) | M |
  | TaskPriorityScoringService | 142 | 6 (Score-Algorithmus) | M |
  | FocusBlockActionService | 120 | completeTask, skipTask | S |
  | GapFinder | ~100 | findFreeSlots, suggestSlots | M |

---

## Tier 2: WICHTIG (Score 2.0-3.9)

### TD-04: MacBacklogRow vs BacklogRow (~250 LoC dupliziert)
- **Was:** Badge-Rendering, Animations-Code, recurrenceDisplayName fast identisch
- **Impact:** 4/5 — Badge-Bugs muessen 2x gefixt werden
- **Risiko:** 4/5 — recurrenceDisplayName hat bereits Text-Mismatch ("Zweiwoechentlich" vs "Alle 2 Wochen")
- **Aufwand:** 3/5 (M)
- **Score:** 5.33
- **Aktiver Bug:** recurrenceDisplayName() in MacBacklogRow (Zeile 363) dupliziert RecurrencePattern.displayName mit ABWEICHENDEM Text

### TD-05: PriorityScore-Berechnung divergiert (iOS vs macOS)
- **Was:** iOS nutzt pre-calculated `item.priorityScore`, macOS rechnet live mit `TaskPriorityScoringService.calculateScore()`
- **Impact:** 4/5 — Unterschiedliche Sortierung moeglich
- **Risiko:** 4/5 — Silent Bug (User sieht verschiedene Reihenfolgen)
- **Aufwand:** 2/5 (S)
- **Score:** 8.0
- **Betroffene Dateien:**
  - Sources/Views/BacklogRow.swift (nutzt item.priorityScore)
  - FocusBloxMac/MacBacklogRow.swift (nutzt TaskPriorityScoringService.calculateScore())

### TD-06: SwiftData-Indizes fehlen komplett
- **Was:** LocalTask hat 0 @Index-Deklarationen, Queries scannen immer den ganzen Store
- **Impact:** 3/5 — Performance-Problem bei >500 Tasks
- **Risiko:** 3/5 — Wird schlimmer mit wachsendem Backlog
- **Aufwand:** 1/5 (XS)
- **Score:** 9.0
- **Fehlende Indizes:** isCompleted, isNextUp, dueDate, recurrencePattern, assignedFocusBlockID

### TD-07: AppSettings.shared Singleton statt Dependency Injection
- **Was:** 20+ direkte Aufrufe in Services + Views, nicht testbar
- **Impact:** 3/5 — Erschwert Unit Testing
- **Risiko:** 2/5 — Funktioniert, aber schlecht testbar
- **Aufwand:** 3/5 (M)
- **Score:** 2.0
- **Betroffene Services:** NotificationService, SmartTaskEnrichmentService, TaskTitleEngine, SoundService

### TD-08: Dead Code in BlockPlanningView
- **Was:** ~250 LoC ungenutzter Code (blockPlanningTimeline, smartGapsContent)
- **Impact:** 2/5 — Verwirrung, Wartungslast
- **Risiko:** 2/5 — Harmlos aber Ballast
- **Aufwand:** 1/5 (XS)
- **Score:** 4.0
- **Betroffene Datei:** Sources/Views/BlockPlanningView.swift (Zeilen 125-257)

### TD-09: Debug print() Statements in Production
- **Was:** print("...") in BlockPlanningView .task und .onChange
- **Impact:** 1/5 — Nur Console-Noise
- **Risiko:** 1/5 — Harmlos
- **Aufwand:** 1/5 (XS)
- **Score:** 1.0

---

## Tier 3: NICE-TO-HAVE (Score < 2.0)

### TD-10: Test-Setup Boilerplate (8 LoC x 20+ Dateien)
- **Aufwand:** XS | **Score:** 1.5

### TD-11: UI Tests mit sleep() statt XCTWaiter
- **Aufwand:** M | **Score:** 2.0

### TD-12: Debug-Test-Dateien (3 Dateien)
- **Aufwand:** XS | **Score:** 0.5

### TD-13: #if canImport(FoundationModels) Redundanz
- **Aufwand:** M | **Score:** 0.5

### TD-14: Settings AppStorage-Duplikation (iOS/macOS)
- **Aufwand:** S | **Score:** 1.5

### TD-15: QuickCaptureView Badge-Button Code
- **Aufwand:** S | **Score:** 1.5

### TD-16: Ungenutztes TaskSource-Protokoll
- **Aufwand:** S | **Score:** 1.0

---

## Empfohlene Reihenfolge (Quick Wins zuerst)

| Rang | Item | Score | Aufwand | Warum jetzt? |
|------|------|-------|---------|-------------|
| 1 | **TD-06** SwiftData Indizes | 9.0 | XS | Hoechster ROI, 5 Minuten Arbeit |
| 2 | **TD-05** PriorityScore-Divergenz | 8.0 | S | Aktiver Silent Bug |
| 3 | **TD-04** recurrenceDisplayName Fix | 5.33 | XS | Aktiver Text-Mismatch |
| 4 | **TD-08** Dead Code loeschen | 4.0 | XS | Rauschen reduzieren |
| 5 | **TD-09** Debug prints loeschen | 1.0 | XS | Trivial |
| 6 | **TD-03** Unit Tests schreiben | 6.67 | M | Kritisch aber aufwaendig |
| 7 | **TD-01** God-Views zerlegen | 6.25 | L | Wichtig aber gross |
| 8 | **TD-02** Plattform-Duplikation | 5.0 | XL | Strategische Entscheidung |
