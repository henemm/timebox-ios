# Context: RW_0.1b — Smart Notification Engine Phase B (FocusBlock Migration)

## Request Summary

Alle direkten `NotificationService.schedule/cancel`-Aufrufe in FocusBlock-bezogenen Views durch `SmartNotificationEngine.reconcile()` ersetzen. Nach Phase A (Foundation) ist die Engine bereit, die Views muessen nur noch umgestellt werden.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Services/SmartNotificationEngine.swift` | Engine aus Phase A — `reconcile()` ist der zentrale Entry Point |
| `Sources/Views/FocusLiveView.swift` | **7 direkte NotificationService-Aufrufe:** 3x `cancelTaskNotification` (Z563, Z588, Z624), 1x `cancelFocusBlockNotification` (Z696), 1x `scheduleFocusBlockEndNotification` (Z697), 1x `cancelTaskNotification` (Z737), 1x `scheduleTaskOverdueNotification` (Z754) |
| `Sources/Views/BlockPlanningView.swift` | **6 direkte Aufrufe:** 2x `cancelFocusBlockNotification` (Z440, Z455), 2x `scheduleFocusBlockStartNotification` (Z456, Z564), 2x `scheduleFocusBlockEndNotification` (Z461, Z569) |
| `Sources/Views/TaskAssignmentView.swift` | **3 direkte Aufrufe:** 2x `cancelFocusBlockNotification` (Z295, Z313), 1x `scheduleFocusBlockStartNotification` (Z296) |
| `FocusBloxMac/FocusBloxMacApp.swift` | **macOS:** 1x `rescheduleAllDueDateNotifications` (Z428), 1x `registerDueDateActions` (Z306), 1x `requestPermission` (Z312) — rescheduleDueDateNotifications muss auf Engine umgestellt werden |
| `Sources/Services/NotificationService.swift` | Bestehende schedule/cancel-Methoden — werden nach Migration in Phase B+C obsolet, bleiben aber erhalten (build*-Methoden werden von Engine genutzt) |
| `Sources/FocusBloxApp.swift` | Phase A hat bereits scenePhase-Handler auf Engine umgestellt (Z321, Z334) |

## Existing Patterns

- Phase A: `SmartNotificationEngine.reconcile(reason:container:eventKitRepo:)` berechnet alle Notifications neu
- Views haben Zugriff auf `eventKitRepo` (via `@Environment(\.eventKitRepository)`) und `modelContext` (via `@Environment(\.modelContext)`)
- Views haben KEINEN Zugriff auf `ModelContainer` — nur auf `ModelContext`
- `FocusBloxApp` hat `sharedModelContainer` als Property

## Migration-Strategie

**Problem:** `reconcile()` braucht `ModelContainer`, Views haben nur `ModelContext`.
**Loesung:** Entweder (a) `reconcile()` um `ModelContext`-Overload erweitern, oder (b) Container via Environment durchreichen. Option (a) ist weniger invasiv.

Alternativ: Da die Views nach Aenderung ohnehin `loadData()` aufrufen (was den UI-State aktualisiert), reicht ein einfacher `reconcile()`-Call nach der Daten-Mutation. Die Engine liest dann den aktuellen Zustand.

**Pattern pro View-Methode:**
```
// VORHER:
NotificationService.cancelFocusBlockNotification(blockID: block.id)
NotificationService.scheduleFocusBlockStartNotification(...)

// NACHHER:
// Notification-Calls entfernen, stattdessen nach loadData():
await triggerReconciliation(reason: .blockChanged)
```

## Dependencies

- **Upstream:** SmartNotificationEngine (Phase A), EventKitRepository, ModelContainer/ModelContext
- **Downstream:** Keine — Views sind Endpunkte

## Existing Specs

- `docs/specs/rework/0.1-smart-notification-engine.md` — Haupt-Spec (Akzeptanzkriterien)
- `docs/specs/rework/0.1-smart-notification-engine-impl.md` — Phase A Impl-Spec
- `docs/context/RW_0.1-smart-notification-engine.md` — Gesamt-Context inkl. Phasen-Uebersicht

## Risks & Considerations

1. **ModelContainer vs ModelContext:** `reconcile()` braucht `ModelContainer`. Views haben nur `ModelContext`. Loesung: ModelContext-Overload (Option A).
2. **Task-Overdue-Notifications:** Wird als eigene Engine-Methode `scheduleTaskOverdue()` integriert (kein reconcile, eigener Entry Point). PO-Entscheidung.
3. **Scope:** 5 Files, ~100 LoC delta (Reduktion). Innerhalb Limits.
4. **macOS FocusBloxMacApp:** Hat eigene `rescheduleDueDateNotifications()` die auf Engine umgestellt werden muss.
5. **Performance:** Jede Block-Aktion loest Full-Reconcile aus (alle 64 Slots neu). Phase-A-Tests zeigen <50ms — akzeptabel.

---

## Analysis

### Type
Feature (Infrastruktur-Rework, Phase B von 3)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/SmartNotificationEngine.swift` | MODIFY | +`reconcile(reason:context:eventKitRepo:)` Overload (ModelContext statt Container), +`scheduleTaskOverdue()` Methode, +`buildTaskRequests(context:)` Overload |
| `Sources/Views/FocusLiveView.swift` | MODIFY | 7 NotificationService-Calls entfernen: 3x cancelTask → entfaellt (reconcile raeumt auf), rescheduleEndNotification → reconcile, cancelTask+scheduleOverdue in trackTaskStart → Engine.scheduleTaskOverdue |
| `Sources/Views/BlockPlanningView.swift` | MODIFY | 6 Calls entfernen: createBlock/updateBlock/deleteBlock → jeweils reconcile nach Mutation |
| `Sources/Views/TaskAssignmentView.swift` | MODIFY | 3 Calls entfernen: updateBlock/deleteBlock → reconcile nach Mutation |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | rescheduleDueDateNotifications() → reconcile(reason:context:eventKitRepo:) |

### Scope Assessment
- Files: 5
- Estimated LoC: ~+30 (Engine) / -70 (Views) = net -40
- Risk Level: LOW

### Technical Approach

**ModelContainer-Problem:** Neuer `reconcile()` Overload akzeptiert `ModelContext` direkt. Da Engine `@MainActor` ist und Views ihren `modelContext` auf Main Actor halten, ist das thread-safe.

**Task-Overdue Integration:** Neue dedizierte Methode `SmartNotificationEngine.scheduleTaskOverdue(taskID:taskTitle:durationMinutes:)` als Wrapper um `NotificationService.scheduleTaskOverdueNotification`. Nicht Teil von `reconcile()` (ist Laufzeit-State, kein Gesamt-State). Ebenso `cancelTaskOverdue(taskID:)` fuer die cancel-Calls.

**Migration-Pattern pro View:**
```swift
// VORHER (BlockPlanningView.deleteBlock):
NotificationService.cancelFocusBlockNotification(blockID: block.id)

// NACHHER:
await SmartNotificationEngine.reconcile(
    reason: .blockChanged, context: modelContext, eventKitRepo: eventKitRepo
)
```

### Dependencies
- **Upstream:** SmartNotificationEngine (Phase A), EventKitRepositoryProtocol, ModelContext, NotificationService.build*-Methoden
- **Downstream:** Keine — Views sind Endpunkte
- **Keine zirkulaeren Dependencies**

### Open Questions
- Keine — Analyse vollstaendig, PO-Entscheidung zu Task-Overdue getroffen
