# BUG_109: Backlog Relevanz-Sortierung invertiert — Analyse v2

## Symptom (Original-Report)

Backlog zeigt Tasks: 18 -> 43 -> 40 -> 71 -> 75 (aufsteigend).
Erwartet: 75 -> 71 -> 43 -> 40 -> 18 (absteigend, wichtigste oben).
Plattform: iOS (macOS pruefen).

## Visual Inspection (Mock-Daten)

Screenshot mit Mock-Daten zeigt:
- **Next Up** (4 Tasks): Scores 85, 18, 29, 58 — NICHT nach Score sortiert
- **Sofort erledigen** (doNow Tier): Score 80 — korrekt im richtigen Tier

Fresh-Eyes-Inspector: "Sortierung in Next Up ist inkonsistent. 85 -> 18 -> 29 -> 58."

---

## Root Cause Synthese (nach Challenge-Runde)

### Fakt 1: Tier-Section-Comparatoren sind KORREKT
Alle 5 Agenten + Code-Review bestaetigen: `effectivePriorityScore($0) > effectivePriorityScore($1)` → absteigend.
Tier-Enum `.allCases` iteriert in Declaration-Order: [doNow, planSoon, eventually, someday] ✓

### Fakt 2: Next Up Section hat KEINE Score-Sortierung

```swift
// BacklogView.swift:107-109
private var nextUpTasks: [PlanItem] {
    planItems.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && !$0.isBlocked && matchesSearch($0) }
    // KEIN .sorted() — Reihenfolge = planItems-Order
}
```

### Fakt 3: planItems kommt aus SyncEngine sortiert nach `rank` (= sortOrder)

```swift
// SyncEngine.swift:16-20
func sync() async throws -> [PlanItem] {
    let tasks = try await taskSource.fetchIncompleteTasks()
    return tasks.map { PlanItem(localTask: $0) }
                .sorted { $0.rank > $1.rank }  // rank = LocalTask.sortOrder (default: 0)
}
```

Wenn alle Tasks `sortOrder = 0` haben (Default), ist die Reihenfolge = SwiftData-Abfrage-Order
(typisch: Einfuege-Reihenfolge). Next Up Tasks erscheinen in dieser Reihenfolge.

### Fakt 4: Die priorityView-Reihenfolge von oben nach unten

```
1. Next Up Section (KEINE Score-Sortierung, nur rank/DB-Order)
2. Coach-Boosted Section (wenn Coach aktiv)
3. Ueberfaellig Section (nach dueDate aufsteigend)
4. Tier Sections: doNow → planSoon → eventually → someday (korrekt!)
```

---

## Hypothesen (nach Challenge-Korrektur)

### Hypothese 1: Next Up Section unsortiert + visuelle Taueschung (HOCH)

**Beschreibung:** Wenn der User Tasks mit NIEDRIGEN Scores als "Next Up" markiert hat,
erscheinen diese oben im Backlog (weil Next Up zuerst kommt). Die Tier-Sections darunter
zeigen Tasks mit HOHEN Scores (doNow mit 60-100 zuerst). Visuell ergibt sich von oben
nach unten: niedrige Scores → hohe Scores = "invertiert".

**Original-Report rekonstruiert:**
- Next Up Tasks (unsortiert, zufaellig DB-Order): 18, 43, 40
- Sofort erledigen (doNow Tier, korrekt sortiert): 75, 71 — ODER 71, 75 wenn wenige Tasks
- Gesamt sichtbar: 18, 43, 40, 71, 75 → EXAKT der Original-Report!

**Beweis DAFUER:**
- Mock-Screenshot zeigt Next Up mit gemischten Scores (85, 18, 29, 58)
- `nextUpTasks` Property hat KEINEN `.sorted()` Aufruf
- 43→40 im Report (absteigend innerhalb planSoon-Bereich) waere Zufall in DB-Order
- Die Tier-Sections kommen NACH Next Up und zeigen hohe Scores

**Beweis DAGEGEN:**
- Wir wissen nicht sicher ob die 5 Tasks im Report in Next Up oder Tier-Sections waren
- 43→40 ist eine merkwuerdige Koinzidenz fuer "zufaellige" DB-Order

**Wahrscheinlichkeit:** HOCH

### Hypothese 2: Alle 5 Tasks waren in Next Up (MITTEL)

**Beschreibung:** Der User hat 5 Tasks als "Next Up" markiert. Diese haben Scores
18, 43, 40, 71, 75 und erscheinen in Einfuege-Reihenfolge (unsortiert).

**Beweis DAFUER:**
- Next Up hat keine Begrenzung (beliebig viele Tasks moeglich)
- Alle 5 Tasks koennten isNextUp=true haben
- DB-Order erklaert die "fast aufsteigende" Reihenfolge

**Beweis DAGEGEN:**
- Scores von 18 bis 75 spannen 3 Tiers — ungewoehnlich fuer Next Up
- Users markieren typischerweise nur wichtige Tasks als Next Up

**Wahrscheinlichkeit:** MITTEL

### Hypothese 3: PriorityScoreBadge zeigt live Score, Sort nutzt frozen Score (NIEDRIG)

**Beschreibung:** `PriorityScoreBadge` in BacklogRow.swift:193 zeigt `item.priorityScore`
(live), waehrend die Tier-Sortierung `effectivePriorityScore` (moeglicherweise frozen)
nutzt. Bei aktivem Freeze koennten angezeigte und sortierte Werte divergieren.

**Beweis DAFUER:**
- Zwei verschiedene Score-Quellen: BacklogRow zeigt `priorityScore`, Sort nutzt `effectivePriorityScore`
- DeferredSortController hat Freeze-Mechanismus

**Beweis DAGEGEN:**
- Freeze dauert nur 3 Sekunden
- Bug ist persistent, nicht nur waehrend Freeze

**Wahrscheinlichkeit:** NIEDRIG

---

## Wahrscheinlichste Ursache

**Hypothese 1 (+ evtl. 2):** Die "Next Up" Section hat KEINE Score-basierte Sortierung.
Combined mit der Tatsache dass Next Up OBEN im Backlog erscheint, sieht es so aus als
waere die gesamte Sortierung invertiert — obwohl die Tier-Sections darunter korrekt
sortiert sind.

**FIX:** `nextUpTasks` nach `priorityScore` absteigend sortieren:

```swift
private var nextUpTasks: [PlanItem] {
    planItems.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && !$0.isBlocked && matchesSearch($0) }
        .sorted { $0.priorityScore > $1.priorityScore }
}
```

---

## Debugging-Plan (falls Beweis noetig)

1. **Logging in nextUpTasks:** Print jedes Task-Title + Score → beweist unsortierte Order
2. **Logging in priorityView ForEach:** Print Tier-Label-Reihenfolge → beweist korrekte Tier-Order
3. **Plattform:** iOS Simulator mit echten/Mock-Daten

---

## Blast Radius

| View | Plattform | Problem? |
|------|-----------|----------|
| BacklogView Next Up | iOS | **JA — unsortiert** |
| BacklogView Tier-Sections | iOS | Nein — korrekt sortiert |
| ContentView Next Up | macOS | Pruefen — moeglicherweise gleich |
| ContentView Tier-Sections | macOS | Nein — korrekt sortiert |
| FocusBlockTasksSheet | iOS | Nein |

### Dead Code gefunden (Challenger)
`CoachBacklogViewModel.tierTasks()` (Zeile 79-83) wird von KEINER View aufgerufen.
BacklogView.swift:1140 berechnet tierTasks INLINE. Die ViewModel-Funktion ist Dead Code.

---

## Challenge-Verdict: LUECKEN → korrigiert in v2

Offene Punkte aus Challenge-Runde eingearbeitet:
- [x] Dead Code identifiziert (CoachBacklogViewModel.tierTasks)
- [x] planItems-Quelle geprueft (SyncEngine.sync() → rank-basiert)
- [x] Plattform-Unterschied notiert (macOS Next Up moeglicherweise anders)
- [x] Hypothese "SwiftData Query-Order" eingearbeitet
