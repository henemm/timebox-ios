# Bug-Analyse: macOS Coach Backlog zeigt keine Tasks im Monster-Mode

## Symptom
macOS Backlog-Tab zeigt KEINE Tasks wenn Coach-Mode (Monster-Mode) aktiviert ist.

## ROOT CAUSE (verifiziert nach 2 Challenge-Runden)

**`.task { refreshTasks() }` ist an `backlogView` gebunden — nicht an ContentView.body.**

### Beweis-Kette:

1. `ContentView.swift:357` — `private var backlogView: some View { VStack { ... } }`
2. `ContentView.swift:566` — `.task { refreshTasks(); cloudKitMonitor.triggerSync() }` → Modifier auf `backlogView`
3. `ContentView.swift:570` — `.onChange(of: cloudKitMonitor.remoteChangeCount) { ... refreshTasks() ... }` → Modifier auf `backlogView`
4. `ContentView.swift:252-257`:
   ```swift
   case .backlog:
       if coachModeEnabled {
           MacCoachBacklogView(tasks: visibleTasks, ...)  // backlogView wird NIE instanziiert!
       } else {
           backlogView  // .task haengt hier
       }
   ```

### Was passiert bei coachModeEnabled == true:
- `backlogView` wird NICHT gerendert → `.task` laeuft NICHT
- `refreshTasks()` wird NICHT aufgerufen
- `@State tasks: [LocalTask] = []` bleibt LEER (Initialisierung)
- `visibleTasks` = leeres Array
- `MacCoachBacklogView` bekommt leeres `tasks`-Array
- **KEINE Tasks werden angezeigt**

### Warum nur im Coach-Mode:
- Normal-Mode rendert `backlogView` → `.task` laeuft → `refreshTasks()` fuellt `tasks`
- Coach-Mode rendert `MacCoachBacklogView` statt `backlogView` → `.task` laeuft NIE

### Warum Tasks nach Interaktion erscheinen koennten:
- Andere `refreshTasks()`-Aufrufe existieren (Add Task, Delete, Complete) — aber NUR nach User-Aktion
- Auch `.onChange(of: cloudKitMonitor.remoteChangeCount)` ist an `backlogView` → CloudKit-Sync triggert auch keinen Refresh im Coach-Mode

## Challenge-Historie

- **Runde 1:** Verdict LUECKEN — H3 (Section-Rendering) widerspricht sich selbst, NavigationSplitView nicht untersucht
- **Runde 2:** Verdict SCHWACH — Challenger fand die ROOT CAUSE: `.task` an `backlogView` statt ContentView.body

## Fix-Vorschlag

`.task` und `.onChange` von `backlogView` auf die NavigationSplitView-Ebene verschieben:

```swift
// ContentView.swift — .task und .onChange auf NavigationSplitView statt backlogView
NavigationSplitView(columnVisibility: $columnVisibility) { ... }
    .task {
        refreshTasks()
        cloudKitMonitor.triggerSync()
    }
    .onChange(of: cloudKitMonitor.remoteChangeCount) { _, _ in
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            refreshTasks()
            let enrichment = SmartTaskEnrichmentService(modelContext: modelContext)
            let enriched = await enrichment.enrichAllTbdTasks()
            if enriched > 0 { refreshTasks() }
        }
    }
```

**Dateien:**
- `FocusBloxMac/ContentView.swift` (1 Datei, ~20 Zeilen verschieben)

**Call-Site:** `.task` wird von SwiftUI aufgerufen wenn ContentView.body erstmals rendert → IMMER, unabhaengig von coachModeEnabled.

## Blast Radius

- **iOS** — NICHT betroffen. iOS `CoachBacklogView` laedt eigene Daten via `SyncEngine.sync()`.
- **Normal macOS Backlog** — Profitiert ebenfalls, da `.task` jetzt auch bei Sektion-Wechsel laeuft.
- **Andere macOS Sections** (Planning, Focus, Review) — haben eigene Datenquellen, nicht betroffen.
- **Sidebar-Badges** (overdueCount etc.) — werden AUCH von `visibleTasks` gespeist → auch diese sind im Coach-Mode leer!
