# Bug 78: macOS Crash bei Swipe-Aktionen (SwiftData Fault)

## Fehlermeldung
```
Fatal error: This backing data was detached from a context without resolving attribute faults:
PersistentIdentifier(...) - \LocalTask.tags
```

## Plattform
macOS (ContentView.swift)

## Trigger
User swiped auf Task-Row — sowohl bei **Editieren** als auch **Loeschen**

---

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- **Keine direkt verwandten Bugs.** Bug 25 (SwiftDataError) und Bug 24 (CloudKit-Error) waren andere Ursachen.
- Kein vorheriger Fix fuer detached-context-Faults vorhanden.
- Memory dokumentiert SwiftData+CloudKit Timing-Probleme (Bug 38), aber nicht Detach-Faults.

### Agent 2: Datenfluss-Trace
- `LocalTask.tags` ist `var tags: [String] = []` (Zeile 15) — **stored property**, kein @Relationship
- macOS nutzt `@Query var tasks: [LocalTask]` (Zeile 40) — **direkte Referenzen** auf SwiftData-Objekte
- iOS nutzt `PlanItem` (value-type struct) — **Kopie** der Tags, kein Referenz-Problem
- Swipe-Delete-Chain: `taskRowWithSwipe` → `deleteTasksByIds` → `modelContext.delete(task)` → `modelContext.save()`
- Swipe-Edit-Chain: `taskRowWithSwipe` → `selectedTasks = [task.uuid]` → `selectedTask` computed property → `TaskInspector(task:)` mit `@Bindable`

### Agent 3: Alle Schreiber
- `.tags` wird an 6 Stellen geschrieben (SyncEngine, LocalTaskSource, RecurrenceService, ContentView)
- Deletion: 7 Stellen mit `modelContext.delete()` — davon 4 in ContentView.swift (Zeilen 684, 800, 808, 820)
- **Kein @Relationship** — tags ist reiner `[String]`-Wert

### Agent 4: Szenarien
- **Szenario 1:** Swipe-Delete loescht Task, SwiftUI rendert View mit stale Referenz
- **Szenario 2:** Swipe-Edit setzt Selection, `matchesSearch()` re-evaluiert alle Tasks (inkl. ggf. detached)
- **Verschaerft durch Search:** `matchesSearch()` (Zeile 86) greift auf `.tags` zu
- **CloudKit-Race:** Remote-Delete koennte Objekt detachen waehrend UI noch rendert

### Agent 5: Blast Radius
- **iOS: SICHER** — BacklogView nutzt `PlanItem` (value-type Kopie)
- **macOS: BETROFFEN** — ContentView nutzt `@Query` (direkte Referenzen)
- `TaskInspector` (Zeile 683) nutzt `@Bindable var task: LocalTask` — ebenfalls gefaehrdet

### Devil's Advocate (Challenge)
- **Verdict: LUECKEN** — Edit-Pfad war nicht analysiert
- Crash passiert bei Edit UND Delete — Hypothese A (nur Delete) erklaert nicht den Edit-Fall
- `matchesSearch()` wird bei JEDEM State-Change re-evaluiert — auch bei Edit-Swipe
- TaskInspector mit `@Bindable` + `$task.tags` (Zeile 138) ist zusaetzlicher Fault-Punkt

---

## Hypothesen (aktualisiert nach Challenge)

### Hypothese A: Swipe-Delete + View-Re-render Race (HOCH fuer Delete-Fall)
- `deleteTasksByIds()` ruft `modelContext.delete(task)` + `save()` auf
- SwiftUI re-rendert → `MacBacklogRow(task: task)` — task detached
- Zeile 115: `task.tags.isEmpty` → CRASH
- **Erklaert:** Delete-Swipe-Crash
- **Erklaert NICHT:** Edit-Swipe-Crash

### Hypothese B: CloudKit-Sync detached Objekt BEVOR Swipe (HOCH fuer beide Faelle)
- **Beschreibung:** Task wurde auf anderem Geraet geloescht oder CloudKit hat das Objekt detached (z.B. waehrend Merge). `@Query` haelt stale Referenz. Beim naechsten State-Change (egal ob Edit oder Delete Swipe) wird `matchesSearch()` oder `MacBacklogRow.body` re-evaluiert → `.tags`-Zugriff auf bereits-detachtes Objekt → Crash.
- **Beweis DAFUER:**
  - CloudKit ist aktiv, `.onChange(of: cloudKitMonitor.remoteChangeCount)` existiert
  - `@Query` kann kurzzeitig stale Referenzen halten nach CloudKit-Merge
  - Erklaert BEIDE Trigger (Edit und Delete) — der Swipe ist nicht die Ursache, sondern nur der Ausloeser eines Re-renders
  - Memory (Bug 38): `eventChangedNotification` feuert BEVOR Daten verfuegbar
- **Beweis DAGEGEN:** Crash waere dann nicht deterministic sondern timing-abhaengig
- **Wahrscheinlichkeit: HOCH**

### Hypothese C: matchesSearch() computed-property Re-evaluation (MITTEL)
- Jeder State-Change (auch `selectedTasks = [uuid]` beim Edit-Swipe) triggert Re-evaluation
- `nextUpTasks` und `regularFilteredTasks` sind computed properties die `matchesSearch()` aufrufen
- `matchesSearch()` Zeile 86: `task.tags.contains(...)` — direkter `.tags`-Zugriff auf JEDEM Task
- Wenn EIN Task in der `@Query`-Liste bereits detached ist → Crash bei naechstem State-Change
- **Erklaert:** Beide Trigger (Edit + Delete Swipe loesen State-Change aus)
- **Wahrscheinlichkeit: MITTEL-HOCH** (kann Kombinationsursache mit B sein)

### Hypothese D: TaskInspector @Bindable Fault (NIEDRIG)
- Edit-Swipe → `selectedTasks = [uuid]` → `TaskInspector(task:)` mit `@Bindable`
- `@Bindable` resolved alle Properties eager — inkl. `.tags` (Zeile 138)
- Wenn Task zu diesem Zeitpunkt detached → Crash
- **Erklaert:** Nur Edit-Swipe-Crash, nicht Delete
- **Wahrscheinlichkeit: NIEDRIG** (waere nur bei bereits-detachtem Objekt)

---

## Wahrscheinlichste Ursache

**Kombination aus B + C:** Ein Task-Objekt wird irgendwann detached (durch CloudKit-Sync, delete auf anderem Geraet, oder vorherigen Delete). Die `@Query`-Liste haelt noch eine stale Referenz. Beim naechsten State-Change — egal ob Edit-Swipe, Delete-Swipe, oder sogar Scrollen — werden computed properties (`nextUpTasks`, `regularFilteredTasks`) re-evaluiert, `matchesSearch()` greift auf `.tags` zu → Crash.

**Kernproblem:** macOS nutzt `@Query` mit **direkten SwiftData-Referenzen** statt value-type Kopien. Jeder Property-Zugriff auf ein detached Objekt crasht — `.tags` ist nur das erste das fehlschlaegt.

---

## Debugging-Plan

**Zum Bestaetigen:**
1. Logging in `matchesSearch()` VOR tags-Zugriff: `print("SEARCH: task \(task.uuid), isDeleted: \(task.isDeleted), modelContext: \(task.modelContext != nil)")`
2. Logging in `MacBacklogRow.body` am Anfang: `print("ROW: task \(task.uuid), context: \(task.modelContext != nil)")`
3. Wenn `modelContext == nil` VOR dem Crash → Task war schon detached BEVOR der Swipe passierte

**Zum Widerlegen:**
- Wenn `modelContext != nil` bei allen Tasks bis zum Delete-Moment → Hypothese B ist falsch, nur A gilt

---

## Fix-Ansatz

### Quick-Fix: Defensiver Guard an ALLEN kritischen Stellen

**1. `matchesSearch()` in ContentView.swift (Zeile 82-90):**
```swift
private func matchesSearch(_ task: LocalTask) -> Bool {
    guard task.modelContext != nil else { return false }  // Skip detached objects
    guard !searchText.isEmpty else { return true }
    // ... rest bleibt gleich
}
```

**2. `MacBacklogRow.swift` body (Zeile 115):**
```swift
// Defensiver Guard am Anfang von body
if task.modelContext == nil { return EmptyView() }
```

**3. `scoreFor()` und andere computed properties die auf Task-Properties zugreifen**

### Langfristig: PlanItem-Pattern (wie iOS)
- macOS auf value-type Kopien umstellen
- Eliminiert alle Detach-Faults strukturell
- Separates Ticket (BACKLOG)

**Empfehlung:** Quick-Fix mit `task.modelContext != nil` Guard an den 3 kritischsten Stellen. Das deckt Edit- UND Delete-Swipe ab.

---

## Blast Radius
- **iOS:** NICHT betroffen (PlanItem value-type)
- **macOS ContentView:** Alle computed properties die `matchesSearch()` nutzen
- **macOS MacBacklogRow:** Tags-Zugriff (Zeile 115-116)
- **macOS TaskInspector:** `@Bindable` auf potentiell detachtem Objekt
- **Langfristig:** JEDER Property-Zugriff auf direkte @Query-Referenzen ist theoretisch gefaehrdet
