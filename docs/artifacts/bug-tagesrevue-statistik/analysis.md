# Bug #207: Keine Statistik im Tagesrückblick mehr

## Bug-Report
> "Im Coach 'Tagesrückblick' gibt es keine Statistik mehr! Es gab Tag und Woche (besser letzte 7 Tage). Und das dann auch nach Kategorien und allem was verfügbar ist (mehr ist besser)"

**Plattform:** Beide (iOS + macOS)
**Layout:** Coach (4 Tabs)

---

## 1. Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check)
- **DailyReviewView** hat seit Sprint 5 (Commit `1798ad2`) volle Statistiken
- **CoachView** hatte NIEMALS Statistik-Sections — sie wurden beim Coach-Tab-Redesign nicht übernommen
- GitHub Issue #205 ("Coach Evening — Wochen-Statistiken") war CLOSED, aber die Statistik wurde nicht fertig integriert
- Keine früheren Fix-Versuche gefunden

### Agent 2 (Datenfluss-Trace)
- `ReviewStatsCalculator` berechnet Category-Minutes und Planning Accuracy
- `CategoryStat` + `CategoryBar` (ReviewComponents.swift) sind die UI-Bausteine
- **CoachView hat bereits ALLE benötigten Daten** (completedTasks, calendarEvents, todayBlocks)
- Es fehlen nur: Computed Properties + UI-Sections

### Agent 3 (Alle Schreiber)
- `ReviewStatsCalculator` wird nur in DailyReviewView (iOS) und MacReviewView (macOS) genutzt
- `CategoryStatsService` und `DisciplineStatsService` nur in Tests und BehavioralProfileService
- CoachView nutzt KEINEN dieser Services

### Agent 4 (Alle Szenarien)
- Feature-Flag `useCoachTabLayout` (AppStorage, default false) bestimmt Layout
- Im Coach-Layout (4 Tabs) fehlt der Review-Tab komplett
- Evening-Drawer in CoachView zeigt nur: Reflexionstext, Completion Ring, Task-Listen
- Settings-Toggle existiert unter "Entwickler-Tools"

### Agent 5 (Blast Radius)
- Blast Radius ist **begrenzt** — nur CoachView betroffen
- macOS hat kein Coach-Layout aktiv (nutzt Classic mit Review-Tab)
- SprintReviewSheet (Block-Review bei Sprint-Ende) ist unabhängig und funktioniert

---

## 2. Hypothesen

### Hypothese A: Statistik-Sections wurden nie in CoachView integriert (HOCH)
- **Beweis DAFÜR:** 
  - Git-History zeigt: CoachView wurde in Commit `46cd830` erstellt, OHNE Statistik-Sections
  - Kein Commit enthält "coach" + "category" oder "statistik" 
  - CoachView:298-366 (eveningContent) hat keine CategoryBar/CategoryStat Referenzen
  - Issue #205 wurde geschlossen OHNE die Stats einzubauen
- **Beweis DAGEGEN:** Keiner — sehr eindeutig
- **Wahrscheinlichkeit: HOCH (95%)**

### Hypothese B: Statistik wurde eingebaut und später entfernt (NIEDRIG)
- **Beweis DAFÜR:** Keiner in Git-History
- **Beweis DAGEGEN:** `git log -p -- Sources/Views/CoachView.swift` zeigt nie CategoryBar/CategoryStat
- **Wahrscheinlichkeit: NIEDRIG (2%)**

### Hypothese C: Feature-Flag-Problem — falsches Layout aktiv (NIEDRIG)
- **Beweis DAFÜR:** Default ist `false` (Classic), Henning nutzt Coach
- **Beweis DAGEGEN:** Henning bestätigt Coach-Layout, das Problem ist dort die fehlende Integration
- **Wahrscheinlichkeit: NIEDRIG (3%)**

---

## 3. Wahrscheinlichste Ursache

**Hypothese A: Die Statistik-Sections wurden beim Coach-Redesign nie in CoachView integriert.**

Beim Wechsel von 5 Tabs (mit separatem Review-Tab) auf 4 Tabs (Coach ersetzt Day+Review) wurden die Kategorie-Statistiken, Wochen-Ansicht und Planungsgenauigkeit nicht in den Evening-Drawer der CoachView übernommen.

Die Daten sind bereits vorhanden (completedTasks, calendarEvents, todayBlocks werden geladen), es fehlen nur die Computed Properties und UI-Sections.

---

## 4. Debugging-Plan

Da die Hypothese zu 95% sicher ist (Code-Evidenz, kein spekulativer Fix):
- **Bestätigung:** CoachView eveningContent hat keine `CategoryBar`/`CategoryStat` Referenzen → bestätigt
- **Widerlegung:** Falls `CategoryBar` in CoachView vorkommt → Hypothese falsch (kommt nicht vor)

**Kein Logging nötig** — die Ursache ist ein fehlender Code-Block, kein Laufzeitproblem.

---

## 5. Blast Radius

- **CoachView** (Evening-Drawer) auf iOS UND macOS betroffen
- macOS: IST betroffen — `FocusBloxMac/ContentView.swift` nutzt denselben `useCoachTabLayout` AppStorage-Key, synchronisiert via iCloud
- SprintReviewSheet: Unabhängig, funktioniert
- Alle Stats-Services und UI-Komponenten existieren und funktionieren korrekt in DailyReviewView

---

## 6. Fix-Vorschlag (High-Level)

Statistik-Sections aus DailyReviewView in CoachView.eveningContent integrieren:

### Datenladelogik erweitern (loadAllData)
1. Wochen-Daten laden: Loop über 7 Tage (wie DailyReviewView Zeile 640-662)
2. Neue State-Properties: `weekBlocks: [FocusBlock]`, `weekCalendarEvents: [CalendarEvent]`, `weekCompletedTasks: [PlanItem]`

### Computed Properties hinzufügen
3. `ReviewStatsCalculator` instanziieren
4. `todayCalendarEvents` — CalendarEvents auf heute gefiltert
5. `dailyCategoryStats` + `dailyTotalMinutes` — Tages-Kategorien
6. `weekCategoryStats` + `weekTotalMinutes` — Wochen-Kategorien (letzte 7 Tage)

### UI-Sections im Evening-Drawer
7. Kategorie-Stats-Section für heute (nach Completion Ring)
8. Kategorie-Stats-Section für Woche (nach Tages-Stats)

**Betroffene Dateien:** `Sources/Views/CoachView.swift` (~80-100 LoC Additions)
**Wiederverwendbare Komponenten:** `CategoryBar`, `CategoryStat`, `StatItem` aus ReviewComponents.swift

### Challenge-Ergebnis
- **Verdict:** LÜCKEN (eingearbeitet)
- Korrektur 1: macOS IST betroffen (gleicher Feature-Flag)
- Korrektur 2: Wochen-Daten-Ladelogik fehlt komplett (nicht nur UI)
- Korrektur 3: Fix-Aufwand korrigiert auf ~80-100 LoC

### Offene Fragen an PO
- Letzte 7 Tage (Rolling Window) oder Kalenderwoche (Mo-So)?
- Planungsgenauigkeit auch im Evening-Drawer, oder nur Kategorie-Minuten?
