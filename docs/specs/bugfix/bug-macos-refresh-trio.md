# Spec: macOS Refresh-Bugs (#189, #190, #191)

## Problem
ContentView (Backlog) nutzt `@State tasks` mit manuellem `refreshTasks()`. Wenn Child-Views (MacFocusView, TaskInspector, MacPlanningView) Task-Daten ändern und `modelContext.save()` aufrufen, wird ContentView nicht benachrichtigt. Zusätzlich fehlen `loadPlanItems()`-Aufrufe in MacPlanningView nach einigen Aktionen.

## Lösung

### 1. Notification definieren (Extension auf Notification.Name)

In einer bestehenden oder neuen Datei eine Notification `taskDataChanged` definieren:
```swift
extension Notification.Name {
    static let taskDataChanged = Notification.Name("taskDataChanged")
}
```

### 2. ContentView: Notification beobachten

`.onReceive(NotificationCenter.default.publisher(for: .taskDataChanged))` hinzufügen, der `refreshTasks()` aufruft.

### 3. MacFocusView: Notification posten

Nach `markTaskComplete()` (Zeile 484, nach loadData) und `returnIncompleteTasksToNextUp()` (Zeile 630, nach save):
```swift
NotificationCenter.default.post(name: .taskDataChanged, object: nil)
```

### 4. TaskInspector: Notification posten

Nach Status-relevanten Änderungen: `isCompleted.toggle()` (Zeile 229) und `isNextUp.toggle()` (Zeile 235), nach dem jeweiligen `modelContext.save()`.

### 5. MacPlanningView: Notification posten + fehlende loadPlanItems()

- `assignTaskToBlockFromSheet()`: Notification posten (nach Zeile 377)
- `removeTaskFromBlockFromSheet()`: Notification posten (nach Zeile 350)
- `createFocusBlock()`: `loadPlanItems()` ergänzen + Notification posten
- `addTaskToBlock()`: `loadPlanItems()` ergänzen + Notification posten

## Betroffene Dateien

1. `FocusBloxMac/ContentView.swift` — onReceive hinzufügen
2. `FocusBloxMac/MacFocusView.swift` — Notification posten (2 Stellen)
3. `FocusBloxMac/TaskInspector.swift` — Notification posten (2 Stellen)
4. `FocusBloxMac/MacPlanningView.swift` — Notification posten (4 Stellen) + loadPlanItems() ergänzen (2 Stellen)

## Acceptance Criteria

- [ ] Nach Task-Completion in MacFocusView: Backlog zeigt Task als erledigt
- [ ] Nach isCompleted-Toggle in TaskInspector: Backlog-Liste aktualisiert sofort
- [ ] Nach isNextUp-Toggle in TaskInspector: "Heute"-Bereich aktualisiert sofort
- [ ] Nach Task-Assignment in MacPlanningView: Planning und Backlog aktualisieren
- [ ] Bestehende Refresh-Trigger (CloudKit, scenePhase) funktionieren weiterhin
- [ ] iOS App nicht betroffen (keine Änderungen)
