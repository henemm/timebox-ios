# Bug 85-C: Kontextmenue "Verschieben"-Optionen

## Status: Feature-Add (nicht Bug-Fix)

Kein "Verschieben"-Menue existiert in irgendeinem Kontextmenue. Erste Implementation.

---

## Agenten-Ergebnisse + Challenge-Korrekturen

### Agent 1: Wiederholungs-Check
- **Keine frueheren Versuche** — erste Implementation
- Bug 85-B (Notification Snooze) hat `postponeTask()` als `private` Helper eingefuehrt
- Context-Menu-Pattern existiert (Bug 49: Matrix QuadrantCard)

### Agent 2: Datenfluss-Trace
- `postponeTask()` in NotificationActionDelegate (Zeile 86-95): private, korrekte Logik
- Pattern: dueDate aendern → cancel alte Notifications → schedule neue → modifiedAt → save
- SyncEngine.updateTask() reschedult Notifications NICHT (View-Layer muss das tun)

### Agent 3: Alle dueDate-Schreiber
- 14+ Stellen schreiben dueDate (SyncEngine, Views, Delegates, Enrichment, Import)
- Konsistentes Pattern bei User-Aktionen: cancel → update → schedule → save
- `rescheduleCount` existiert auf LocalTask (Zeile 92), wird bei FocusBlock-Wechsel incrementiert (SyncEngine:214)

### Agent 4: Edge Cases
- **Recurring Tasks:** Nur Instanz verschieben, nie Template (isTemplate-Filter bereits aktiv)
- **Ohne dueDate:** Menue nur zeigen wenn dueDate != nil
- **Completed Tasks:** Architektonisch separiert, kein Handlungsbedarf
- **macOS Multi-Select:** Nur bei selection.count == 1 anbieten (Pattern wie "Serie bearbeiten")
- **Notifications:** PFLICHT — cancel + reschedule bei jeder Verschiebung

### Agent 5: Blast Radius
- 6 von 7 Systemen updaten AUTOMATISCH via SwiftData
- **Einzig manuell:** Notifications (cancel + reschedule)

### Challenge-Verdict: LUECKEN → eingearbeitet

**Korrigierte Punkte:**
1. **NextUpSection.swift ist DEAD CODE auf iOS** — wird nirgends instanziiert. BacklogView rendert Next Up inline via `nextUpListSection` (Zeile 750). Fix geht in BacklogView.swift
2. **rescheduleCount** sollte bei Verschieben incrementiert werden (semantisch: User verschiebt Task = reschedule)
3. **PlanItem vs LocalTask** — BacklogView arbeitet mit PlanItem (Struct). Fuer dueDate-Aenderung muss LocalTask via ModelContext gefetcht werden (SyncEngine.findTask(byID:))
4. **TaskAssignmentView** hat Context Menu (Zeile 595) — aber nur "In Block verschieben". Tasks dort haben kein dueDate-Relevanz (Fokus auf Block-Zuweisung). Verschieben dort nicht noetig.

---

## Fix-Ansatz (korrigiert)

### 1. Shared Helper als Extension auf LocalTask
In `Sources/Extensions/` oder `Sources/Services/`:

```swift
extension LocalTask {
    /// Verschiebt das Faelligkeitsdatum um N Tage und reschedult Notifications
    static func postpone(_ task: LocalTask, byDays days: Int, context: ModelContext) {
        guard let currentDue = task.dueDate else { return }
        let newDue = Calendar.current.date(byAdding: .day, value: days, to: currentDue)!
        task.dueDate = newDue
        task.modifiedAt = Date()
        task.rescheduleCount += 1
        NotificationService.cancelDueDateNotifications(taskID: task.id)
        NotificationService.scheduleDueDateNotifications(
            taskID: task.id, title: task.title, dueDate: newDue
        )
        try? context.save()
    }
}
```

### 2. iOS — BacklogView.swift (BEIDE Stellen)

**a) nextUpListSection (Zeile 770-790):** `.contextMenu` hinzufuegen:
```swift
.contextMenu {
    if item.dueDate != nil {
        Menu { ... } label: { Label("Verschieben", systemImage: "calendar.badge.clock") }
    }
}
```

**b) backlogRowWithSwipe (Zeile 812-850):** `.contextMenu` hinzufuegen (analog)

Zum Fetchen des LocalTask: `SyncEngine(taskSource:modelContext:).findTask(byID: item.id)` oder direkter FetchDescriptor.

### 3. macOS — ContentView.swift
In `.contextMenu(forSelectionType:)` (Zeile 457ff):
```swift
if selection.count == 1,
   let taskId = selection.first,
   let task = tasks.first(where: { $0.uuid == taskId }),
   task.dueDate != nil {
    Menu("Verschieben") {
        Button("Morgen") { postponeTask(task, byDays: 1) }
        Button("Naechste Woche") { postponeTask(task, byDays: 7) }
    }
}
```

### 4. NotificationActionDelegate refactoren
`private postponeTask()` durch `LocalTask.postpone()` ersetzen.

---

## Betroffene Dateien (3-4)

1. `Sources/Models/LocalTask.swift` — Extension mit shared `postpone()` Helper (~12 LoC)
2. `Sources/Views/BacklogView.swift` — Context Menus fuer Next Up + Backlog Rows (~25 LoC)
3. `FocusBloxMac/ContentView.swift` — Context Menu erweitern (~12 LoC)
4. `Sources/Services/NotificationActionDelegate.swift` — Refactor auf shared Helper (~-8 LoC)

**Netto: ~40-50 LoC, 4 Dateien. Kein neues File noetig.**

---

## Blast Radius: Minimal

- Notifications: Shared Helper erzwingt korrektes cancel+reschedule
- Badge/Sorting/Visibility: Automatisch via SwiftData
- rescheduleCount: Priority Score passt sich automatisch an
- Keine neuen Permissions, keine AppStorage-Keys, keine Audio-Files
