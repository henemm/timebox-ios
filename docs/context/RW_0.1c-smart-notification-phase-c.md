# Context: RW_0.1c — Smart Notification Engine Phase C (DueDate Migration)

## Request Summary

Migration aller verbleibenden direkten `NotificationService.schedule/cancelDueDateNotifications`-Aufrufe auf `SmartNotificationEngine.reconcile()`. Nach Phase C gibt es keinen direkten Notification-Zugriff mehr in Views/Delegates.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/BacklogView.swift` | **5 direkte Calls** — editTask, deleteTask, postponeTask |
| `Sources/Views/TaskFormSheet.swift` | **1 direkter Call** — saveTask create mode |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | **1 direkter Call** — saveTask |
| `FocusBloxMac/ContentView.swift` | **2 direkte Calls** — postponeTask |
| `Sources/Services/NotificationActionDelegate.swift` | **5 direkte Calls** — postpone×2, complete |
| `Sources/FocusBloxApp.swift` | **Minor** — NotificationActionDelegate init anpassen (+eventKitRepo) |
| `FocusBloxMac/FocusBloxMacApp.swift` | **Minor** — NotificationActionDelegate init anpassen (+eventKitRepo) |

## Existing Patterns (Phase A+B)

### Reconcile-Pattern in Views (Phase B Referenz)
```swift
await SmartNotificationEngine.reconcile(
    reason: .taskChanged,
    context: modelContext,
    eventKitRepo: eventKitRepo
)
```

### Engine-Overloads
- `reconcile(reason:container:eventKitRepo:)` — fuer App-Entries + NotificationActionDelegate
- `reconcile(reason:context:eventKitRepo:)` — fuer Views mit `@Environment(\.modelContext)`

## Analysis

### Type
Feature (Infrastruktur-Rework, Phase C von 3)

### Architektur-Befunde

**1. Fehlende @Environment in 2 Views:**
- `TaskFormSheet.swift` hat KEIN `@Environment(\.eventKitRepository)` — muss ergaenzt werden
- `CreateTaskView.swift` hat KEIN `@Environment(\.eventKitRepository)` — muss ergaenzt werden
- BacklogView und FocusBloxMac/ContentView haben beides bereits

**2. NotificationActionDelegate ist NSObject (kein SwiftUI View):**
- Kann `@Environment` nicht nutzen
- Hat nur `ModelContainer` via init
- Loesung: `EventKitRepositoryProtocol` als zweiten init-Parameter hinzufuegen
- Beide App-Entry-Points (iOS + macOS) muessen den Delegate-Init aktualisieren
- Concurrency: `@MainActor` + `@unchecked Sendable` auf EventKitRepository — sicher

**3. Scope-Splitting (PO-Entscheidung noetig):**
Die strategische Bewertung empfiehlt Split in zwei Teile:
- **RW_0.1c:** DueDate-Migration (14 Calls ersetzen) — 5 primaere Dateien + 2 App-Entry-Points
- **RW_0.1d:** Review/Nudge-Implementation + Settings UI Profil-Picker — 3 Dateien

### Affected Files

**RW_0.1c (DueDate Migration):**
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/BacklogView.swift` | MODIFY | 5 NotificationService-Calls → reconcile |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | 1 Call → reconcile + @Environment hinzufuegen |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | MODIFY | 1 Call → reconcile + @Environment hinzufuegen |
| `FocusBloxMac/ContentView.swift` | MODIFY | 2 Calls → reconcile |
| `Sources/Services/NotificationActionDelegate.swift` | MODIFY | 5 Calls → reconcile + init-Signatur erweitern |
| `Sources/FocusBloxApp.swift` | MODIFY | Delegate-Init: +eventKitRepository (~3 LoC) |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | Delegate-Init: +eventKitRepository (~3 LoC) |

**RW_0.1d (separates Ticket, danach):**
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/SmartNotificationEngine.swift` | MODIFY | buildReviewRequests + buildNudgeRequests befuellen |
| `Sources/Models/AppSettings.swift` | MODIFY | Morning/Evening-Zeiten, Nudge-Toggles |
| `Sources/Views/SettingsView.swift` | MODIFY | Profil-Picker + Review/Nudge-Settings UI |

### Scope Assessment (RW_0.1c)
- Files: 5 primaer + 2 minor (App-Entry-Points)
- Estimated LoC: +60 (reconcile-Calls) / -40 (alte Calls) = ~100 LoC delta
- Risk Level: LOW — gleiches Pattern wie Phase B

### Dependencies
- **Upstream:** SmartNotificationEngine (Phase A+B komplett), EventKitRepositoryProtocol (existiert)
- **Downstream:** RW_0.1d (Review/Nudge) baut darauf auf

### Implementierungs-Reihenfolge
1. NotificationActionDelegate.swift — init erweitern + Calls ersetzen
2. FocusBloxApp.swift + FocusBloxMacApp.swift — Delegate-Init anpassen
3. BacklogView.swift — 5 Calls ersetzen (groesste Datei)
4. FocusBloxMac/ContentView.swift — 2 Calls ersetzen
5. TaskFormSheet.swift + CreateTaskView.swift — je 1 Call + @Environment ergaenzen

### Open Questions
- Scope-Split: Soll Review/Nudge + Settings UI in separates Ticket RW_0.1d?
