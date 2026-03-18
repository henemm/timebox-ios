# BUG_107 Refix-Analyse: Coach-Backlog Tasks doppelt (macOS + iOS)

**Datum:** 2026-03-18
**Status:** Root Cause gefunden — Cross-Section Overlap
**Challenge-Runde:** 2 (nach SCHWACH-Verdict in Runde 1)

---

## 1. Root Cause

**Die Sections `coachBoostedTasks` und `overdueTasks` schließen sich NICHT gegenseitig aus.**

Ein Task der SOWOHL überfällig als auch coach-relevant ist, erscheint in BEIDEN Sections.
`taskRowWithSwipe` rendert dabei jeweils den Task UND seine `blockedDependents` → doppelte Anzeige.

### Beweis-Kette (macOS ContentView.swift)

```
Section-Rendering-Reihenfolge:
1. NextUp Section (L430-461)          → nextUpTasks
2. Coach-Boost Section (L464-486)     → coachBoostedTasks
3. Overdue Section (L490-511)         → overdueTasks        ← OVERLAP mit 2!
4. Tier Sections (L514-542)           → tierFilteredTasks
```

**Cross-Exclusion Matrix:**

| Section | Excludes NextUp? | Excludes Coach-Boost? | Excludes Overdue? |
|---------|:---:|:---:|:---:|
| NextUp | N/A | N/A | N/A |
| Coach-Boost | ✅ L371 | N/A | ❌ NEIN |
| Overdue | ✅ L347 | ❌ NEIN | N/A |
| Tier | ✅ via L291 | ✅ via L377 | ✅ via L517 |

**Die Lücke:** Coach-Boost ↔ Overdue haben KEINE gegenseitige Exklusion.

### Konkretes Szenario (Feuer-Coach)

1. Task A: `importance == 3`, `dueDate = gestern`, `blockerTaskID == nil`
2. Task B: `blockerTaskID = A.id` (blocked by A)

**Rendering:**
- Coach-Boost Section: Task A → `taskRowWithSwipe(A)` → zeigt A + B (als blocked dependent)
- Overdue Section: Task A → `taskRowWithSwipe(A)` → zeigt A + B (als blocked dependent)
- **Ergebnis:** Task A erscheint 2x, Task B erscheint 2x (eingerückt)

---

## 2. Datenfluss-Trace

### macOS: coachBoostedTasks (L368-372)

```swift
private var coachBoostedTasks: [LocalTask] {
    guard coachModeEnabled else { return [] }
    let boostIDs = Set(CoachBacklogViewModel.coachBoostedTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
    return visibleTasks.filter { boostIDs.contains($0.id) && !$0.isNextUp && $0.blockerTaskID == nil }
}
```

Kette: `CoachType.filterTasks()` → `relevantTasks()` → `coachBoostedTasks()` → finale View-Filter.
- `CoachType.filterTasks()` (CoachType.swift L94-106): Filtert NUR `!isCompleted && !isTemplate` — ❌ KEIN blockerTaskID-Filter
- `relevantTasks()` (CoachBacklogViewModel.swift L26-31): Excludes NextUp — ❌ KEIN blockerTaskID-Filter
- ContentView L371: `$0.blockerTaskID == nil` — ✅ Letzte Verteidigung

### macOS: overdueTasks (L344-349)

```swift
private var overdueTasks: [LocalTask] {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return visibleTasks.filter { task in
        guard !task.isNextUp, task.blockerTaskID == nil, let dueDate = task.dueDate else { return false }
        return dueDate < startOfToday && matchesSearch(task)
    }
}
```

Filtert: `!isNextUp`, `blockerTaskID == nil`, `dueDate < today` — ❌ KEIN Coach-Boost-Exclusion

### macOS: taskRowWithSwipe (L1101-1140)

```swift
private func taskRowWithSwipe(task: LocalTask) -> some View {
    makeBacklogRow(task: task)
        // ... swipe actions ...

    // Blocked dependents rendered inline
    ForEach(blockedDependents(of: task.id), id: \.uuid) { blockedTask in
        makeBacklogRow(task: blockedTask, isBlocked: true)
    }
}
```

Jeder Task der in einer Section erscheint, rendert AUTOMATISCH seine blocked dependents.
Wenn der gleiche Task in 2 Sections erscheint → dependents 2x gerendert.

---

## 3. iOS Blast Radius

**iOS BacklogView.swift hat das GLEICHE Problem + ein zusätzliches:**

### Gleicher Overlap:
- `coachBoostedTasks` (L130-134): Keine Overdue-Exclusion
- `overdueTasks` (L149-155): Keine Coach-Boost-Exclusion
- `backlogRowWithSwipe` (L940+): Rendert blocked dependents (L1005-1007)

### Zusätzliches Problem (nur iOS):
```swift
// iOS coachBoostedTasks (L130-134):
private var coachBoostedTasks: [PlanItem] {
    guard coachModeEnabled else { return [] }
    let searchFiltered = planItems.filter { matchesSearch($0) }
    return CoachBacklogViewModel.coachBoostedTasks(from: searchFiltered, selectedCoach: selectedCoach)
}
```

iOS hat KEINEN finalen `blockerTaskID == nil` Guard (macOS hat ihn bei L371).
→ Blocked Tasks können auf iOS als standalone in der Coach-Boost Section erscheinen!

---

## 4. Hypothesen

### Hypothese A: Cross-Section Overlap (HOCH) ← ROOT CAUSE
- **Dafür:** Code-Beweis: overdueTasks und coachBoostedTasks schließen sich nicht aus. taskRowWithSwipe rendert dependents in jeder Section. Feuer-Coach selektiert overdue Tasks (filterTroll verwendet sogar `dueDate < now` als Kriterium).
- **Dagegen:** Nichts — der Code ist eindeutig.
- **Beweis:** Jeder überfällige Task mit `importance == 3` erscheint in beiden Sections.

### Hypothese B: iOS coachBoostedTasks ohne blockerTaskID-Filter (HOCH)
- **Dafür:** `CoachBacklogViewModel.coachBoostedTasks()` filtert nicht auf blockerTaskID. iOS hat keinen View-Level-Guard.
- **Dagegen:** Auf iOS nutzt `backlogTasks` (Basis für Tier/Overdue) `topLevelTasks` → blocked Tasks erscheinen dort nicht standalone.
- **Beweis:** Ein blocked Task mit `importance == 3` erscheint auf iOS in Coach-Boost als standalone UND unter seinem Blocker in Tier-Section.

### Hypothese C: Bisheriger Fix war Dead Code (MITTEL)
- **Dafür:** BUG_107 Fix (fa0ab48) fügte Filter zu `CoachBacklogViewModel`-Instanzmethoden hinzu, aber nach dem View-Merge (BUG_109) werden nur STATIC-Methoden aufgerufen.
- **Dagegen:** Die Views haben eigene `blockerTaskID == nil` Filter (macOS L291, L347, L371).
- **Beweis:** Der Fix adressierte nicht die Cross-Section-Overlap-Ursache.

---

## 5. Fix-Vorschlag

### macOS ContentView.swift — overdueTasks erweitern:

```swift
private var overdueTasks: [LocalTask] {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    let boostIDs = Set(coachBoostedTasks.map(\.id))  // NEU
    return visibleTasks.filter { task in
        guard !task.isNextUp, task.blockerTaskID == nil, let dueDate = task.dueDate else { return false }
        return dueDate < startOfToday && matchesSearch(task) && !boostIDs.contains(task.id)  // NEU
    }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
}
```

### iOS BacklogView.swift — overdueTasks erweitern + coachBoostedTasks absichern:

```swift
// overdueTasks: Coach-Boost excluden
private var overdueTasks: [PlanItem] {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    let boostIDs = Set(coachBoostedTasks.map(\.id))  // NEU
    return backlogTasks.filter { item in
        guard let due = item.dueDate else { return false }
        return due < startOfToday && !boostIDs.contains(item.id)  // NEU
    }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
}
```

### Call-Sites:
- macOS: `overdueTasks` wird bei L491 (`if !overdueTasks.isEmpty`) und L493 (`ForEach(overdueTasks)`) aufgerufen
- iOS: `overdueTasks` wird bei L1114 (`if !overdueTasks.isEmpty`) und L1116 (`ForEach(overdueTasks)`) aufgerufen
- **KEIN Dead Code** — beide Properties werden aktiv in der View genutzt

### Betroffene Dateien:
1. `FocusBloxMac/ContentView.swift` — overdueTasks (2 Zeilen Änderung)
2. `Sources/Views/BacklogView.swift` — overdueTasks (2 Zeilen Änderung)

---

## 6. Warum der bisherige Fix nicht wirkte

Der BUG_107 Fix (Commit fa0ab48) fügte `blockerTaskID`-Filter zu `CoachBacklogViewModel`-Instanzmethoden hinzu:
- `nextUpTasks()`, `remainingTasks()`, `overdueTasks()`, `recentTasks()`

Diese Filter sind korrekt, aber **die eigentliche Ursache war nie blockerTaskID-Leaking**.
Die Ursache war immer der **Cross-Section Overlap** — ein Task erscheint in 2 Sections weil die Sections sich nicht gegenseitig ausschließen.

Die bisherige Analyse hat nur INNERHALB jeder Section geprüft ("kommt ein blocked Task durch den Filter?") aber nie ZWISCHEN Sections geprüft ("kann derselbe Task in 2 Sections erscheinen?").

---

## 7. Debugging-Beweis (falls gewünscht)

```swift
// Temporäres Logging in ContentView.swift body:
let overlap = Set(coachBoostedTasks.map(\.id)).intersection(Set(overdueTasks.map(\.id)))
if !overlap.isEmpty {
    print("[BUG_107] OVERLAP: \(overlap.count) tasks in BOTH Coach-Boost AND Overdue!")
    for id in overlap {
        if let task = visibleTasks.first(where: { $0.id == id }) {
            print("  - \(task.title)")
        }
    }
}
```
