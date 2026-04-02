# Analyse: macOS Refresh-Bugs (#189, #190, #191)

## Bug-Beschreibung
Drei macOS Views aktualisieren die UI nicht nach lokalen Task-Mutationen:
- **#189:** MacFocusView — nach Task-Completion bleibt Task im **Backlog** sichtbar
- **#190:** TaskInspector — nach Completion-Toggle aktualisiert sich die **Backlog-Liste** nicht
- **#191:** MacPlanningView — nach Task-Assignment aktualisiert sich die **Planning-UI** nicht vollständig

## Präzisierte Symptom-Analyse (nach Challenge)

### Datenquellen pro View

| View | Datenquelle | Typ | Auto-Refresh nach save()? |
|------|-------------|-----|---------------------------|
| **ContentView (Backlog)** | `@State tasks` + manuelles `refreshTasks()` | Manuell | **NEIN** — nur durch expliziten Aufruf |
| **MacFocusView** | `@Query allTasks` (ungefiltert) | SwiftData | JA (gleicher ModelContext) |
| **MacPlanningView** | `@Query nextUpTasks` (Filter: isNextUp && !isCompleted) | SwiftData | JA (gleicher ModelContext) |
| **MacPlanningView** | `@State allPlanItems` via `loadPlanItems()` | Manuell | **NEIN** — nur durch expliziten Aufruf |
| **TaskInspector** | `@Bindable var task` | Direkte Bindung | JA (sofort) |

### Tatsächliches Problem pro Bug

**#189 (MacFocusView → Backlog):**
- MacFocusView selbst zeigt Completion korrekt (loadData refreshed activeBlock, @Query aktualisiert allTasks)
- **Symptom:** Nach Wechsel zum Backlog-Tab zeigt ContentView.tasks die Task noch als aktiv
- **Ursache:** ContentView.refreshTasks() wird nicht nach markTaskComplete() aufgerufen
- Zusätzlich: `returnIncompleteTasksToNextUp()` ruft weder loadData() noch irgendwas auf

**#190 (TaskInspector → Backlog):**
- TaskInspector selbst zeigt Änderungen sofort korrekt (@Bindable aktualisiert direkt)
- **Symptom:** Die Backlog-Liste in ContentView (die den Inspector-Inhalt umgibt) zeigt veraltete Daten
- **Ursache:** ContentView.tasks (@State) wird nicht aktualisiert wenn TaskInspector save() aufruft
- TaskInspector wird direkt in ContentView eingebettet (Zeile 765) — ohne onChanged-Callback

**#191 (MacPlanningView):**
- `@Query nextUpTasks` SOLLTE nach save() auto-aktualisieren (task.isNextUp = false → fällt aus Filter)
- **Symptom:** Planning UI zeigt veraltete Daten in `allPlanItems` (SyncEngine-basiert, manuell)
- **Ursache 1:** `addTaskToBlock()` (Zeile 434-481) ruft KEIN loadPlanItems() auf → allPlanItems stale
- **Ursache 2:** `createFocusBlock()` (Zeile 390-432) ruft KEIN loadPlanItems() auf → allPlanItems stale
- **Ursache 3:** ContentView.tasks wird nicht aktualisiert nach Assignment

## Kernursache

**ContentView nutzt `@State tasks` statt `@Query` (Bug 90 Legacy).**
Jede Mutation in einer Child-View (MacFocusView, TaskInspector, MacPlanningView) speichert via `modelContext.save()`, aber ContentView's `@State tasks` wird NUR durch explizites `refreshTasks()` aktualisiert.

Es gibt **keinen Callback-Mechanismus** von Child-Views zurück zu ContentView.

Zusätzlich: MacPlanningView hat manuelle State-Objekte (`allPlanItems`) die nach einigen Aktionen nicht refreshed werden.

## Hypothesen

### Hypothese 1: ContentView.tasks (@State) wird nicht nach Child-Mutations refreshed (HOCH)
- **Beweis dafür:** ContentView.refreshTasks() wird nur aufgerufen bei: App-Start, CloudKit-Sync, scenePhase-Wechsel, Task-Erstellung, Task-Löschung. NICHT nach Mutations in Child-Views.
- **Beweis dagegen:** Keiner — der Code ist eindeutig.
- **Betrifft:** Alle 3 Bugs

### Hypothese 2: MacPlanningView.allPlanItems wird nach einigen Aktionen nicht refreshed (HOCH)
- **Beweis dafür:** `addTaskToBlock()` und `createFocusBlock()` rufen KEIN `loadPlanItems()` auf, obwohl sie Task-State ändern.
- **Beweis dagegen:** `assignTaskToBlockFromSheet()` (Zeile 357-386) ruft loadPlanItems() korrekt auf — also ist das Pattern bekannt, nur nicht überall angewendet.
- **Betrifft:** #191

### Hypothese 3: @Query aktualisiert nicht zuverlässig (NIEDRIG)
- **Beweis dafür:** Bug 90 dokumentierte Probleme mit @Query nach CloudKit-Import
- **Beweis dagegen:** Bug 90 betraf CloudKit-Imports, nicht lokale saves. Für lokale `modelContext.save()` im gleichen Context sollte @Query zuverlässig sein.
- **Betrifft:** Nur relevant falls Hypothese 1+2 nicht ausreichen

## Gewählte Ursache

**Hypothese 1 (primär) + Hypothese 2 (zusätzlich für #191):**

1. ContentView's `@State tasks` hat keinen Refresh-Trigger nach Child-View-Mutations → Backlog zeigt veraltete Daten
2. MacPlanningView's `allPlanItems` wird in `addTaskToBlock()` und `createFocusBlock()` nicht aktualisiert

## Fix-Ansatz

**Einfachster Ansatz: Callback-Closures von ContentView an Child-Views**

```
ContentView
├─ MacFocusView(onTaskChanged: { refreshTasks() })
├─ MacPlanningView(onTaskChanged: { refreshTasks() }, ...)
└─ TaskInspector(task: task, onTaskChanged: { refreshTasks() })
```

Jede Child-View ruft `onTaskChanged()` nach save() auf → ContentView.refreshTasks() wird getriggert.

Für MacPlanningView zusätzlich: `loadPlanItems()` in `addTaskToBlock()` und `createFocusBlock()` ergänzen.

## Blast Radius

**Direkt betroffen (3 Dateien + ContentView):**
- ContentView.swift — muss Callback-Parameter an Child-Views übergeben
- MacFocusView.swift — neuer `onTaskChanged` Parameter, Aufruf nach markTaskComplete + returnIncompleteTasksToNextUp
- TaskInspector.swift — neuer `onTaskChanged` Parameter, Aufruf nach isCompleted/isNextUp Toggle
- MacPlanningView.swift — neuer `onTaskChanged` Parameter + fehlende loadPlanItems()-Aufrufe

**Potenziell betroffen (gleicher Pattern, aber nicht in Issues):**
- MenuBarView.swift — task.isNextUp Mutation ohne Refresh (separater Bug)
- QuickCapturePanel.swift — eigener Context, separater Bug

**Nicht betroffen:**
- MacReviewView, MacTimelineView, MacBacklogRow (nur Read)
- iOS Views (eigenes Refresh-Pattern)

**Änderungsumfang:** ~4 Dateien, geschätzt ~40-60 LoC — innerhalb Scoping-Limits
