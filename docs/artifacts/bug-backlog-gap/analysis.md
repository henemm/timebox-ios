# Bug-Analyse: Schwarzer Leerraum im iOS Backlog

## Symptom
Großer schwarzer Bereich zwischen dem Header ("Tasks durchsuchen") und der "Next Up" Section im iOS Backlog Screen. Tritt laut User "immer" auf.

## Visual Inspection
Screenshot zeigt: Next Up Section mit 4 Tasks am UNTEREN Rand der Liste, darüber ~60% schwarzer Leerraum. Backlog ist auf "Priorität"-Modus.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- **Bug 52** dokumentiert: Verwaiste `assignedFocusBlockID` macht Tasks unsichtbar im Backlog (Filter: `assignedFocusBlockID == nil`)
- Cleanup-Funktion existiert (FocusBloxApp.swift:455-470)
- Wiederholtes Muster: iOS Backlog Tasks werden durch Filter unsichtbar

### Agent 2 (Datenfluss)
- `priorityView` Layout: `List { nextUpListSection → overdue → priority tiers }`
- `nextUpListSection` ist ERSTE Section in der List
- Alle anderen Sections haben `if !tasks.isEmpty` Guard → werden bei leerer Liste nicht gerendert
- `.scrollContentBackground(.hidden)` → leerer Bereich wird schwarz
- `.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 120) }` → 120pt unsichtbarer Bottom-Spacer

### Agent 3 (Filter-Analyse)
- `allBacklogTasks` Filter (Zeile 97): `!isCompleted && !isNextUp && assignedFocusBlockID == nil && matchesSearch`
- `backlogTasks` (Zeile 100-102): zusätzlich `topLevelTasks` (filtert blocked Tasks)
- 5 Filter-Ebenen: Database → Sync → NextUp-Split → Backlog-Filter → Section-Gruppierung

### Agent 4 (Szenarien)
- Mock-Daten: 4 NextUp Tasks + mehrere Backlog Tasks vorhanden
- Backlog Tasks SOLLTEN sichtbar sein (isNextUp=false, kein assignedFocusBlockID)
- `.scrollContentBackground(.hidden)` macht leeren List-Bereich schwarz

### Agent 5 (Blast Radius)
- Nur iOS BacklogView + macOS ContentView betroffen
- Gleiches Pattern: List + Sections + .scrollContentBackground(.hidden)

## Layout-Analyse (Hauptkontext)

Die `priorityView` (BacklogView.swift:1027-1091):
```
List {
    nextUpListSection          ← ERSTE Section (Zeile 1029)
    overdue section            ← nur wenn !overdueTasks.isEmpty (Zeile 1032)
    ForEach(PriorityTier) {    ← nur wenn !tierTasks.isEmpty (Zeile 1059)
        Section { ... }
    }
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 120) }
```

**Kritische Beobachtung:** Next Up ist die ERSTE Section. In einem `.plain` List sollte sie am OBEREN Rand erscheinen. Aber der Screenshot zeigt sie am UNTEREN Rand. Das bedeutet: Entweder wird Content über Next Up gerendert der unsichtbar ist, oder ein Layout-Modifier verschiebt den Inhalt nach unten.

`.safeAreaInset(edge: .top) { EmptyView() }` auf dem Group (Zeile 168) könnte Platz reservieren.

## Hypothesen

### Hypothese 1: Layout-Bug — `.safeAreaInset(edge: .top)` oder List-Verhalten schiebt Content nach unten
- **Beweis DAFÜR:** `.safeAreaInset(edge: .top) { EmptyView() }` auf dem Group (Zeile 168) könnte Safe-Area-Berechnung beeinflussen. Combined mit `.scrollContentBackground(.hidden)` → schwarzer leerer Bereich.
- **Beweis DAGEGEN:** `EmptyView()` sollte keine Größe haben. Dieses Pattern existiert vermutlich seit längerem ohne das Problem zu verursachen.
- **Wahrscheinlichkeit:** Mittel

### Hypothese 2: Alle Backlog-Tasks werden ausgefiltert — List-Sections sind alle leer
- **Beweis DAFÜR:** 5 Filter-Ebenen (isCompleted, isNextUp, assignedFocusBlockID, blockerTaskID, isVisibleInBacklog). Bug 52 zeigt dass `assignedFocusBlockID`-Orphans Tasks unsichtbar machen. Auf echtem Device mit CloudKit-Sync könnten verwaiste Zuweisungen entstehen.
- **Beweis DAGEGEN:** Mock-Daten haben Backlog-Tasks OHNE assignedFocusBlockID. Cleanup läuft beim App-Start. Auf Mock-Daten sollte es funktionieren.
- **Wahrscheinlichkeit:** Hoch (für echtes Device), Niedrig (für Mock)

### Hypothese 3: List rendert korrekt, Gap ist UNTERHALB von Next Up (Fehlinterpretation)
- **Beweis DAFÜR:** In `.plain` List mit wenig Content startet der Inhalt oben. Next Up am oberen Rand, darunter leerer Bereich. `.safeAreaInset(edge: .bottom, height: 120)` + leere Sections = viel Platz unten.
- **Beweis DAGEGEN:** Screenshot zeigt klar: Gap ist OBERHALB von Next Up, nicht darunter. Der schwarze Bereich ist zwischen Suchfeld und Next Up Header.
- **Wahrscheinlichkeit:** Niedrig

### Hypothese 4: ForEach über PriorityTier.allCases rendert unsichtbare Spacer
- **Beweis DAFÜR:** `ForEach(PriorityTier.allCases)` iteriert über alle Tier-Varianten. Auch wenn `if !tierTasks.isEmpty` greift, könnte SwiftUI Section-Header-Platz reservieren.
- **Beweis DAGEGEN:** `nextUpListSection` ist VOR den Tiers → Tiers würden Platz UNTER Next Up erzeugen, nicht darüber.
- **Wahrscheinlichkeit:** Niedrig (erklärt nicht die Position)

## Wahrscheinlichste Ursache

**Hypothese 2 + Layout-Effekt:** Die Backlog-Tasks werden auf dem echten Device durch Filter unsichtbar gemacht (vermutlich `assignedFocusBlockID` oder anderer Filter). Die List enthält dann NUR die `nextUpListSection`. In einer `.plain` List sollte diese oben stehen — ABER die Kombination aus `.safeAreaInset`, `.scrollContentBackground(.hidden)`, und ggf. iOS 26 List-Verhalten könnte den Content nach unten verschieben.

## Debugging-Plan

Um die Hypothese zu BEWEISEN:

1. **Logging in `loadTasks()`:** Nach `planItems = try await syncEngine.sync()` loggen:
   - `planItems.count` (gesamt)
   - `nextUpTasks.count`
   - `backlogTasks.count`
   - `overdueTasks.count`
   - Für jeden planItem: `id, isNextUp, assignedFocusBlockID, isCompleted, isBlocked`

2. **Logging in `priorityView`:** Vor/nach dem ForEach loggen wie viele Tier-Tasks gerendert werden.

3. **Test:** `.safeAreaInset(edge: .top) { EmptyView() }` temporär entfernen und sehen ob der Gap verschwindet.

## Blast Radius
- iOS BacklogView: Alle 5 ViewModes (priority, recent, overdue, recurring, completed) nutzen dasselbe Pattern
- macOS ContentView.backlogView: Gleiches Pattern, könnte gleichen Bug haben
