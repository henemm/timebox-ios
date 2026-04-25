# Bug #289 Intake — MenuBar Popover Filter Mismatch

**Issue:** https://github.com/henning-gmbh/focus-blox/issues/289

**Reported:** 2026-04-25  
**Status:** Investigating  
**Severity:** High (UX-breaking: Tasks invisible in main window visible in popover; checkbox behavior broken)

---

## Symptom (User-reported)

Henning beobachtet zwei Verhaltensweisen im macOS MenuBar-Popover der FocusBlox App:

1. **Tasks in Popover sichtbar, aber nicht im Hauptfenster:** Ein Beispiel-Task "Zehnagel behandelt" mit `dueDate=2026-06-07` wird im Backlog-Tab des Hauptfensters nicht angezeigt, aber im MenuBar-Popover unter der "Backlog"-Sektion taucht er auf.

2. **Checkbox-Verhalten ist kaputt:** Wenn Henning versucht, einen dieser Tasks im Popover durch Klick auf die Checkbox zu erledigen, werden die Tasks nur umsortiert, statt zu verschwinden. Das ist völlig falsch — der Task sollte als `isCompleted=true` markiert werden und aus der Liste verschwinden.

---

## Reproduction Steps

1. App öffnen (macOS)
2. Ein Task mit dueDate in der Zukunft (z.B. 2026-06-07) und `isNextUp=false` erstellen
3. Ins Hauptfenster (iOS oder macOS) wechseln → Backlog-Tab → Task ist nicht sichtbar
4. MenuBar-Popover öffnen → Task unter "Backlog"-Section sichtbar
5. Checkbox im Popover klicken → Task verschwindet NICHT, sondern sortiert nur um

---

## Erwartetes vs. Tatsächliches Verhalten

| Szenario | Erwartet | Tatsächlich |
|----------|----------|-----------|
| Task mit `dueDate=2026-06-07` (Zukunft), `isNextUp=false`, `isCompleted=false` | Im Hauptfenster sichtbar, im Popover sichtbar (Parität) | Im Hauptfenster unsichtbar, im Popover sichtbar (DIVERGENZ) |
| Checkbox im Popover klicken | Task als `isCompleted=true`, entfernt | Task sortiert nur um, bleibt sichtbar |
| Filter-Ergebnis | Hauptfenster + Popover zeigen GLEICH | Popover zeigt MEHR Tasks |

---

## Betroffene Komponenten (Code-Analyse)

### MenuBarView.swift (macOS-spezifisch)
- **Datei:** `/Users/hem/Developer/my-daily-sprints/FocusBloxMac/MenuBarView.swift`
- **@Query für Backlog (Zeile 29-31):**
  ```swift
  @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isNextUp },
         sort: \LocalTask.createdAt, order: .reverse)
  private var backlogTasks: [LocalTask]
  ```
  **Filter: 2 Bedingungen** → `!isCompleted && !isNextUp`

- **Checkbox-Handler (Zeile 415-425):**
  ```swift
  private func toggleComplete(_ task: LocalTask) {
      if !task.isCompleted {
          let taskSource = LocalTaskSource(modelContext: modelContext)
          let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
          try? syncEngine.completeTask(itemID: task.id)
      } else {
          // uncomplete logic
      }
  }
  ```

### ContentView + MainTabView + BacklogView (iOS/macOS Shared)
- **Datei:** `/Users/hem/Developer/my-daily-sprints/Sources/Views/MainTabView.swift` (Zeile 16-17)
  ```swift
  @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isParked && !$0.isTemplate })
  private var backlogTasks: [LocalTask]
  ```
  **ABER:** Diese @Query wird nur für Badge-Counting verwendet.

- **Datei:** `/Users/hem/Developer/my-daily-sprints/Sources/Views/BacklogView.swift` (Zeile 405-422)
  ```swift
  private func loadTasks() async {
      // ...
      planItems = try await syncEngine.sync()
  }
  ```
  
  **`allBacklogTasks` (Zeile 106-108):**
  ```swift
  private var allBacklogTasks: [PlanItem] {
      planItems.filter { !$0.isCompleted && !$0.isNextUp && $0.assignedFocusBlockID == nil && matchesSearch($0) }
  }
  ```
  
  **`backlogTasks` (Zeile 110-113):**
  ```swift
  private var backlogTasks: [PlanItem] {
      allBacklogTasks.topLevelTasks  // excludes blocked tasks
  }
  ```

- **Datei:** `/Users/hem/Developer/my-daily-sprints/Sources/Services/TaskSources/LocalTaskSource.swift` (Zeile 45)
  ```swift
  return allIncomplete.filter { $0.isVisibleInBacklog && $0.lifecycleStatus != "raw" }
  ```

### LocalTask.swift (Model)
- **Datei:** `/Users/hem/Developer/my-daily-sprints/Sources/Models/LocalTask.swift` (Zeile 85-93)
  ```swift
  var isVisibleInBacklog: Bool {
      if isTemplate { return false }
      guard recurrencePattern != "none" else { return true }
      guard let dueDate = dueDate else { return true }
      let startOfTomorrow = Calendar.current.startOfDay(
          for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      )
      return dueDate < startOfTomorrow
  }
  ```

---

## Filter-Divergenz (Root Cause Candidates)

### MenuBarView @Query Filter (Zeile 29-31)
```swift
!$0.isCompleted && !$0.isNextUp
```
**Filter:** 2 Bedingungen
- `!isCompleted`
- `!isNextUp`

**MISSING:** Kein `isVisibleInBacklog` Check!

### BacklogView Filter (via SyncEngine.sync())
```swift
isVisibleInBacklog && lifecycleStatus != "raw"
```
**Filter:** (2+ Bedingungen nach Transformation)
- `!isTemplate` (indirekt via `isVisibleInBacklog`)
- `dueDate < startOfTomorrow` ODER `recurrencePattern == "none"` (via `isVisibleInBacklog`)
- `lifecycleStatus != "raw"`

**DIESEN CHECK HAT MenuBarView NICHT!**

---

## Daten-Befund aus GitHub Issue

**"Zehnagel behandelt" — 12 DB-Instanzen:**
- 1x Template (`isTemplate=true`) → `isVisibleInBacklog=false` ✓
- 10x Erledigt (`isCompleted=true`) → Nicht sichtbar ✓
- 1x Aktiv: `dueDate=2026-06-07`, `isCompleted=false`, `isNextUp=false`, `recurrencePattern=weekly`, `isTemplate=false`

**Analyse der aktiven Instanz:**
```
isVisibleInBacklog für diesen Task:
  ✓ isTemplate == false
  ✓ recurrencePattern == "weekly" (nicht "none")
  ✗ dueDate = 2026-06-07 (Zukunft)
  ✗ startOfTomorrow = 2026-04-26
  ✗ 2026-06-07 < 2026-04-26 = FALSE
  → isVisibleInBacklog RETURNS FALSE
```

**Warum ist er aber im Popover sichtbar?**
→ MenuBarView @Query: `!$0.isCompleted && !$0.isNextUp`
→ Diese Task erfüllt BEIDE Bedingungen (isCompleted=false, isNextUp=false)
→ Der `isVisibleInBacklog=false` Check wird NICHT durchgeführt
→ Task erscheint im Popover, aber nicht im Hauptfenster (FALSCH!)

---

## Erste Hypothesen (Mind. 3)

### Hypothese 1: MenuBarView Filter ist unvollständig
**Wahrscheinlichkeit:** HOCH (Smoking Gun)

MenuBarView's @Query bei Zeile 29-31 nutzt nur:
```swift
!$0.isCompleted && !$0.isNextUp
```

Sollte aber auch `isVisibleInBacklog` checken:
```swift
!$0.isCompleted && !$0.isNextUp && $0.isVisibleInBacklog
```

**Impact:** Tasks mit `dueDate` in der Zukunft werden von MenuBarView angezeigt, obwohl sie im Hauptfenster unsichtbar sind (wegen `isVisibleInBacklog=false`).

---

### Hypothese 2: toggleComplete Handler nutzt falschen Service
**Wahrscheinlichkeit:** MITTEL

`toggleComplete` (Zeile 415-425) ruft direkt `syncEngine.completeTask()` auf, **ohne die Task zu refreshen**.

```swift
private func toggleComplete(_ task: LocalTask) {
    if !task.isCompleted {
        let taskSource = LocalTaskSource(modelContext: modelContext)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
        try? syncEngine.completeTask(itemID: task.id)  // ← Feuer und vergessen!
    }
}
```

**Problem:** Keine `await`, kein `refreshLocalTasks()` danach. Die SwiftUI @Query wird möglicherweise nicht getriggert, oder die Mutation wird nicht ins UI reflektiert.

**Vergleich mit BacklogView.completeTask (Zeile 892-918):**
```swift
private func completeTask(_ item: PlanItem) {
    completeFeedback.toggle()
    deferredCompletion.scheduleCompletion(id: item.id) { [modelContext] in
        // ... completion logic
        await loadTasks()  // ← PROPER REFRESH!
    }
}
```

**Impact:** UI Update findet nicht statt; Tasks werden nur umsortiert, statt zu verschwinden.

---

### Hypothese 3: `isVisibleInBacklog` Bug bei Recurring Tasks
**Wahrscheinlichkeit:** MITTEL

Die Berechnung von `isVisibleInBacklog` (Zeile 85-93) hat eine Spezial-Logik für Recurring Tasks:

```swift
guard recurrencePattern != "none" else { return true }  // ← FALLTHROUGH FÜR RECURRING
guard let dueDate = dueDate else { return true }
let startOfTomorrow = ...
return dueDate < startOfTomorrow
```

**Für "Zehnagel" (weekly recurring, dueDate=2026-06-07):**
- `recurrencePattern == "weekly"` → Guard NOT triggered (passthrough)
- `dueDate == 2026-06-07` → Not nil (passthrough)
- `startOfTomorrow == 2026-04-26`
- `2026-06-07 < 2026-04-26` = **FALSE**

**Aber:** Der Task sollte trotzdem heute sichtbar sein, wenn es eine Instanz für heute gibt. Die Logik prüft nur, ob die **nächste** Instanz sichtbar ist, nicht ob es eine **heute fällige** Instanz gibt.

**Impact:** Wenn eine Recurring-Series eine Instanz für heute hat und eine für morgen, wird die Today-Instanz falsch als unsichtbar markiert.

---

### Hypothese 4: `isNextUp` wird unerwartet auf true gesetzt
**Wahrscheinlichkeit:** LOW

Der GitHub-Issue erwähnt: Task hat `isNextUp=0` in DB, aber MenuBar @Query filtert auf `!isNextUp`.

**Frage:** Gibt es einen Code-Pfad, der `isNextUp` automatisch setzt oder nicht zurückgesetzt wird nach Completion?

Suche nach `isNextUp` Assignment:
- `MenuBarView.addTask()` (Zeile 406-412): Setzt `task.isNextUp = true` nur wenn `shouldMarkNextUp=true`
- `BacklogView.updateNextUp()` (Zeile 577-588): Setzt `isNextUp` via SyncEngine
- `MenuBarTaskRow`: nur UI, keine Mutation

**Candidate Code Path:** Nach `completeTask()` wird `isNextUp` nicht explizit auf false gesetzt. Falls die Mutation incomplete ist, könnte der Task mit `isNextUp=true` steckenbleiben.

**Impact:** LOW — eher ein Detail-Bug, nicht der Hauptproblem.

---

## Offene Fragen aus Issue

### 1. Warum zeigt @Query mit `isNextUp=true` einen Task mit `isNextUp=0` in DB?

**Mögliche Erklärung:** SwiftData/CloudKit Sync-Verzögerung. Die @Query wird von der lokalen `ModelContext` gefüttert, nicht direkt von der DB. Falls der CloudKit-Import den `isNextUp` zurückgesetzt hat, ist die lokale View noch nicht refreshed.

**Zu prüfen:**
- Wird `loadFocusBlock()` nur manuell aufgerufen?
- Gibt es einen Listener für CloudKit-Sync-Events?
- Wird `modelContext.save()` nach Completion aufgerufen?

---

### 2. Wo wird `isNextUp` gesetzt? Wer ändert das?

**Setter Locations:**
- `BacklogView.updateNextUp()` (Line 577-588): Explizit via SyncEngine
- `MenuBarView.addTask()` (Line 406-412): Explizit beim Quick-Add
- **FEHLEND:** Nach `completeTask()` wird `isNextUp` nicht auf false zurückgesetzt!

**Hypothesis:** Nach Completion bleibt `isNextUp=true`, und die nextUpTasks @Query filtert weiterhin on diesen Task.

---

### 3. Wie ist die Sortierung in Popover vs Hauptfenster?

**MenuBarView Backlog (Zeile 29-31):**
```swift
sort: \LocalTask.createdAt, order: .reverse
```
→ Neueste zuerst

**BacklogView allBacklogTasks (Zeile 106-108):**
Keine direkte @Query, sondern:
```swift
planItems.filter { !$0.isCompleted && !$0.isNextUp && $0.assignedFocusBlockID == nil }
```
Dann nach Tier/Score sortiert via `tasksForTierGroup()` (Zeile 137-142)

**DIVERGENZ:** MenuBar sortiert nach `createdAt`, Backlog nach Priority-Score. Task kann an unterschiedlichen Positionen erscheinen, falls beide sichtbar wären.

---

## Summary — Warum der Bug so hartnäckig ist

1. **MenuBarView hat keinen `isVisibleInBacklog` Check** → Tasks mit Zukunft-Dates erscheinen im Popover, obwohl sie im Hauptfenster unsichtbar sind.

2. **toggleComplete Handler nutzt falsche Mutation Pattern** → Keine `await`/`refreshLocalTasks()` nach `completeTask()`, daher keine UI-Aktualisierung.

3. **Keine Test-Abdeckung für MenuBarView Filtering** → Bug wurde nicht beim Schreiben von Code oder Tests entdeckt.

4. **3 gescheiterte Fix-Versuche zeigen systematisches Problem:**
   - Session 1: ArraySlice→Array Hypothese (Ablenkung)
   - Session 2: Filter-Parität in MenuBarView geschrieben, aber Toggle-Handler nicht gefixt
   - Session 3: Debug-Logging eingebaut, aber nie analyzed

---

## Nächste Schritte (für Developer)

1. **HALT:** Nicht spekulieren. Code-Analyse durchführen:
   - Exakte Datenbank-Dumps von "Zehnagel behandelt" Task
   - `isVisibleInBacklog` Berechnung für diesen Task durchspielen
   - MenuBarView @Query Output vs BacklogView Output vergleichen
   - `toggleComplete()` Handler mit Breakpoints debuggen

2. **Test-schreiben (TDD RED):**
   - UI Test: Recurring Task mit dueDate=Zukunft, isNextUp=false → sichtbar im Popover?
   - UI Test: Task im Popover abhaken → verschwindet?
   - Unit Test: `isVisibleInBacklog` für verschiedene dueDate Szenarien

3. **Fix implementieren:**
   - MenuBarView @Query + `isVisibleInBacklog` Check
   - toggleComplete Handler + proper `await`/refresh
   - Ggf. `isNextUp` Reset nach Completion

---

**Intake Status:** READY FOR ANALYSIS  
Alle betroffenen Code-Pfade identifiziert. Datenbank-Schema verstanden. Hypothesen dokumentiert.
