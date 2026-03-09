# Bug 85-C: Kontextmenue "Verschieben"-Optionen

## Problem
Kein "Verschieben"-Menue in Kontextmenues. User koennen Fristen nur ueber Edit-Sheet aendern.

## Loesung

### 1. Shared Helper: `LocalTask.postpone(_:byDays:context:)`
- Extension auf LocalTask in `Sources/Models/LocalTask.swift`
- dueDate + N Tage, modifiedAt, rescheduleCount++
- cancel + reschedule Notifications
- context.save()

### 2. iOS BacklogView.swift — 2 Context Menus
- `nextUpListSection` (Zeile ~770): `.contextMenu` mit "Verschieben" Menu
- `backlogRowWithSwipe` (Zeile ~812): `.contextMenu` mit "Verschieben" Menu
- Nur sichtbar wenn `item.dueDate != nil`
- LocalTask via FetchDescriptor holen (PlanItem ist Struct)

### 3. macOS ContentView.swift — Context Menu erweitern
- In `.contextMenu(forSelectionType:)` (Zeile ~457)
- Nur bei `selection.count == 1` und `task.dueDate != nil`
- Pattern wie "Serie bearbeiten"

### 4. NotificationActionDelegate.swift — Refactor
- `private postponeTask()` durch `LocalTask.postpone()` ersetzen

## Dateien
1. `Sources/Models/LocalTask.swift` — Extension (+12 LoC)
2. `Sources/Views/BacklogView.swift` — 2 Context Menus (+25 LoC)
3. `FocusBloxMac/ContentView.swift` — Menu erweitern (+12 LoC)
4. `Sources/Services/NotificationActionDelegate.swift` — Refactor (-8 LoC)

## Edge Cases
- Nur Tasks MIT dueDate (guard)
- Nur Instanzen, nie Templates (architektonisch geloest: Templates nicht sichtbar)
- macOS: Nur Einzelselektion
- rescheduleCount wird incrementiert (Priority Score passt sich an)

## Approved: ja
