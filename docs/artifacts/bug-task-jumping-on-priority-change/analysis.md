# Bug-Analyse: Tasks springen bei Wichtigkeit/Dringlichkeit-Änderung

## Symptom
Wenn in der BacklogView (iOS, Priority-Modus) die Wichtigkeit oder Dringlichkeit eines Tasks geändert wird, springt der Task sofort an eine andere Position — trotz "Deferred Sort" Mechanik (3-Sekunden-Verzögerung).

## Bisherige Fix-Versuche (3x gescheitert)

| # | Commit | Was gemacht | Warum gescheitert |
|---|--------|------------|-------------------|
| 1 | 2d63eed | Deferred Sort mit 3s Timer + orangener Rand | onChange-Guard fehlte, SyncEngine ignorierte nil, falsche Farbe |
| 2 | 240b82c | Guard hinzugefügt + direkte Mutation + pulsierender Rand | Tests grün, aber fundamentaler Design-Fehler nicht behoben |
| 3 | (Teil von 2) | Urgency-Cycle nil-fähig + immediate PlanItem-Update | Gleicher fundamentaler Fehler |

**Gemeinsamer Fehler aller 3 Versuche:** Alle haben Nebenprobleme gefixt, aber den ECHTEN Grund ignoriert.

## Root Cause (BEWIESEN)

### Der fundamentale Design-Fehler

Die Deferred-Sort-Mechanik verzögert nur den **Refresh aus der Datenbank** (Zeile 573). Aber der Task springt VORHER — bei Zeile 522.

**Ablauf:**

```
1. User tippt auf Wichtigkeit-Badge
2. updateImportance() wird aufgerufen (Zeile 512)
3. task.importance = neuerWert (Zeile 517)
4. modelContext.save() (Zeile 519)
5. planItems[index] = PlanItem(localTask: task)  ← HIER PASSIERT ES (Zeile 522)
   → Neuer PlanItem hat neuen priorityScore (computed property)
6. scheduleDeferredResort() (Zeile 524) — zu spät, Schaden schon passiert
7. SwiftUI re-rendert die Priority-View
8. Zeile 872: .sorted { $0.priorityScore > $1.priorityScore }
   → Task ist jetzt an anderer Position weil sein Score sich geändert hat
9. Task SPRINGT sofort
```

**Warum `pendingResortIDs` nicht hilft:** Das Set wird NUR für den orangenen Rand-Indikator verwendet (BacklogRow.swift:49-58). Die Sortierung in Zeile 872 prüft NICHT ob ein Item in `pendingResortIDs` ist.

### Beweis: Code-Analyse

**BacklogView.swift Zeile 869-872:**
```swift
ForEach(TaskPriorityScoringService.PriorityTier.allCases, id: \.self) { tier in
    let tierTasks = backlogTasks
        .filter { task in task.priorityTier == tier && ... }
        .sorted { $0.priorityScore > $1.priorityScore }  // ← SORTIERT BEI JEDEM RENDER
```

**PlanItem.swift Zeile 62-74:**
```swift
var priorityScore: Int {
    TaskPriorityScoringService.calculateScore(
        importance: importance,  // ← Ändert sich sofort bei Zeile 522
        urgency: urgency,       // ← Ändert sich sofort bei Zeile 522
        ...
    )
}
```

`priorityScore` ist ein **computed property** — nicht gespeichert, bei jedem Zugriff neu berechnet. Wenn `importance` sich ändert, ändert sich der Score sofort.

## Hypothesen

### H1: Immediate PlanItem-Update triggert Neusortierung (BESTÄTIGT - Root Cause)
- **Dafür:** Zeile 522 erstellt neuen PlanItem mit neuem importance → neuer priorityScore → Sortierung ändert sich
- **Dagegen:** Nichts — der Code beweist es eindeutig
- **Wahrscheinlichkeit:** 100%

### H2: CloudKit-Sync unterbricht Deferred Sort
- **Dafür:** onChange-Guard existiert (Zeile 329), aber Race Conditions möglich
- **Dagegen:** Guard prüft `pendingResortIDs.isEmpty` — sollte während der 3s blockieren
- **Wahrscheinlichkeit:** 10% (sekundäres Problem, nicht Root Cause)

### H3: Tier-Wechsel verursacht Section-Sprung
- **Dafür:** Wenn Score von 34→35 geht, wechselt Task von "eventually" zu "planSoon"
- **Dagegen:** Ist Konsequenz von H1, nicht eigenständige Ursache
- **Wahrscheinlichkeit:** Konsequenz, nicht Ursache

## Fix-Richtung

Der Fix muss sicherstellen, dass bei Zeile 522 der PlanItem **den alten priorityScore/Tier behält** bis die 3-Sekunden-Verzögerung abgelaufen ist. Mögliche Ansätze:

1. **Snapshot-Approach:** Beim Badge-Tap den alten Score/Tier separat speichern und in der Sort-Logik verwenden, solange Item in `pendingResortIDs` ist
2. **Nur Badge updaten:** Zeile 522 nicht den ganzen PlanItem ersetzen, sondern nur die Badge-Darstellung aktualisieren (erfordert mutable importance/urgency für Display)
3. **Sort-Freeze:** In Zeile 872 Items in `pendingResortIDs` an ihrer aktuellen Position halten

## macOS vs iOS: Entscheidende Divergenz

**macOS HAT BEREITS einen funktionierenden Fix:**
- `displaySnapshot: [LocalTask]?` (ContentView.swift:81)
- `displayedRegularTasks` gibt `displaySnapshot ?? regularFilteredTasks` zurück (Zeile 85-87)
- Bei Badge-Tap: `displaySnapshot = regularFilteredTasks` friert aktuelle Sortierung ein (Zeile 1021-1022)
- Nach 3s: `displaySnapshot = nil` gibt Live-Sortierung frei (Zeile 1035)

**iOS hat diesen Mechanismus NICHT:**
- Kein Snapshot, kein Freeze
- `planItems[index]` wird direkt mutiert → sofortige Neusortierung

**→ Der Fix für iOS ist: Den macOS-Snapshot-Ansatz auf iOS portieren.**

## Zusätzliche Lücke: Inkonsistentes Verhalten

- `updateCategory()` (Zeile 548) macht KEINEN PlanItem-Replace → springt NICHT sofort
- `updateImportance()` (Zeile 522) macht PlanItem-Replace → springt SOFORT
- `updateUrgency()` (Zeile 540) macht PlanItem-Replace → springt SOFORT

Kategorie-Änderungen verhalten sich korrekt (kein Sprung), Wichtigkeit/Dringlichkeit nicht.

## Blast Radius
- macOS hat `displaySnapshot`-Lösung (muss verifiziert werden ob sie funktioniert)
- iOS ist das einzige Problem
- Keine anderen Views betroffen
