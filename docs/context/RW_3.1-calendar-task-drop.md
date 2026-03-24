# Context: RW_3.1 — Task direkt auf Kalender droppen

## Request Summary
Tasks sollen per Drag&Drop auf die Timeline geschedult werden koennen — OHNE Focus Block. Long-Press bietet Wahl: "Task einplanen" vs. "Focus Block erstellen". Geplante Tasks sind ein eigener visueller Typ auf der Timeline.

## Kernkonzept: Neuer Scheduling-Typ
Aktuell: Task → FocusBlock (via EventKit/CalendarEvent mit Metadaten in Notes).
Neu: Task → scheduledDate/scheduledDuration direkt auf LocalTask (SwiftData-persistent, KEIN EventKit-Event).

## Related Files

### Direkt betroffen (laut Spec)
| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` (306 LoC) | + `scheduledDate: Date?`, + `scheduledDuration: Int?` — SwiftData @Model |
| `Sources/Views/TimelineView.swift` (197 LoC) | QuarterHourDropZone hat bereits PlanItemTransfer Drop-Support — muss scheduled Tasks rendern |
| `Sources/Views/PlanningView.swift` | Wraps TimelineView, hat `scheduleTask()` Callback — muss "nur schedulen" vs "FocusBlock" unterscheiden |
| `Sources/Models/TimelineItem.swift` (179 LoC) | Collision Detection — muss Case fuer scheduled Tasks bekommen |
| `Sources/Models/GapFinder.swift` (154 LoC) | Free-Slot-Analyse — scheduled Tasks als belegte Slots |
| `FocusBloxMac/MacTimelineView.swift` (150+ LoC) | macOS Timeline — gleiche Aenderungen |
| `FocusBloxMac/MacPlanningView.swift` | macOS Planning — gleiche Drop-Logik |

### Neu zu erstellen
| File | Beschreibung |
|------|-----------|
| `Sources/Views/ScheduledTaskBlock.swift` | Timeline-Darstellung eines geplanten Tasks (visuell unterscheidbar von FocusBlock/Event) |

### Bestehende Infrastruktur (unveraendert nutzbar)
| File | Relevance |
|------|-----------|
| `Sources/Models/PlanItemTransfer.swift` (24 LoC) | Transferable fuer Task-Drag — existiert, wird wiederverwendet |
| `Sources/Models/CalendarEventTransfer.swift` (33 LoC) | Transferable fuer Event/Block-Drag |
| `FocusBloxMac/MacTaskTransfer.swift` (32 LoC) | macOS Task Transfer |
| `Sources/Layouts/TimelineLayout.swift` (100+ LoC) | Custom Layout mit place() — korrekte Hit-Testing |
| `Sources/Models/PlanItem.swift` (304 LoC) | View-Projektion von LocalTask — braucht scheduledDate Durchreichung |
| `Sources/Models/FocusBlock.swift` (100+ LoC) | Ephemeres Model aus EventKit — unveraendert |
| `Sources/Models/CalendarEvent.swift` (119 LoC) | EventKit Wrapper — unveraendert |
| `Sources/Services/EventKitRepository.swift` | Kalender-Interface — unveraendert (kein EventKit fuer scheduled Tasks) |
| `Sources/Services/FocusBlockActionService.swift` | FocusBlock CRUD — unveraendert |
| `Sources/Views/MiniBacklogView.swift` | Drag-Source: Tasks sind bereits `.draggable(PlanItemTransfer)` |
| `Sources/Views/BacklogRow.swift` | Task-Row — kein Drag von hier |

## Existing Patterns

### Drag & Drop Flow (aktuell)
1. User draggt Task aus `MiniBacklogView` (PlanItemTransfer)
2. Drop auf `QuarterHourDropZone` in `TimelineView` (15-Min-Raster)
3. Callback `onScheduleTask(item, dropTime)` nach `PlanningView`
4. PlanningView erstellt FocusBlock via EventKit + setzt `LocalTask.assignedFocusBlockID`

### Was sich aendern muss
- Drop-Handler muss Default-Verhalten aendern: Task schedulen (NICHT FocusBlock erstellen)
- Long-Press auf Drop-Zone: Kontext-Menue mit Wahl
- Scheduled Tasks muessen auf Timeline gerendert werden (neuer Block-Typ)
- TimelineItem muss scheduled Tasks in Collision Detection einbeziehen
- GapFinder muss scheduled Tasks als belegt zaehlen

### Constraint aus Spec
- Task kann NICHT gleichzeitig `scheduledDate` haben UND in einem `FocusBlock` sein
- CloudKit-Sync fuer neue Felder
- SmartNotificationEngine: Reconciliation bei Schedule-Aenderung

## Dependencies

### Upstream (was unser Code nutzt)
- SwiftData ModelContext (LocalTask Persistenz)
- EventKit (NUR fuer FocusBlocks/Events, NICHT fuer scheduled Tasks)
- TimelineLayout (Custom Layout)
- PlanItemTransfer (Transferable Protokoll)

### Downstream (was unseren Code nutzt)
- SmartNotificationEngine — muss auf scheduledDate reagieren
- GapFinder — muss scheduled Tasks einbeziehen
- BlockPlanningView — Long-Press Kontext-Menue
- Backlog Views — scheduled Tasks ggf. visuell markieren

## Existing Specs
- `docs/specs/rework/3.1-calendar-task-drop.md` — Haupt-Spec (bereits vorhanden)
- `docs/specs/rework/0.1-smart-notification-engine-impl.md` — Notification Reconciliation

## Existing Tests (Referenz)
- `FocusBloxTests/FocusBlockDragTests.swift` (142 LoC) — Transfer + Move Tests
- `FocusBloxUITests/FocusBlockDragDropUITests.swift` (170 LoC) — Timeline Drop UI Tests
- `FocusBloxUITests/NextUpDragDropUITests.swift` (100+ LoC) — Next Up Drag Tests
- `FocusBloxUITests/FocusBlockDropIndicatorUITests.swift` — Drop Zone Feedback Tests

## Risks & Considerations

1. **Model-Migration:** Neue Felder auf LocalTask (SwiftData) brauchen ggf. Migration — beide Optional, daher lightweight (kein Migration Plan noetig)
2. **Mutual Exclusion:** scheduledDate vs. assignedFocusBlockID — Business Rule an jeder Write-Site durchsetzen (nicht im Model enforcebar wegen CloudKit)
3. **CloudKit Sync:** Neue Optional-Felder syncen automatisch via SwiftData
4. **Notification Reconciliation:** SmartNotificationEngine muss scheduled Tasks kennen
5. **macOS Drop-Architektur:** MacTaskTransfer (eigener Typ) + Rechtsklick statt Long-Press
6. **Bestehende Drop-Logik aendern:** Aktuell erstellt Drop immer FocusBlock — Default wird zu "Task schedulen"

---

## Analysis

### Type
Feature

### Phasen-Split (wegen LoC-Limit 250 pro Change)

#### Phase A — Model Layer (~60 LoC, 3 Dateien)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Models/LocalTask.swift | MODIFY | +scheduledDate: Date?, +scheduledDuration: Int?, +isScheduled computed |
| Sources/Models/PlanItem.swift | MODIFY | Mirror scheduledDate/scheduledDuration, +isScheduled |
| Sources/Models/TimelineItem.swift | MODIFY | +.scheduledTask case, +init(task:) |

#### Phase B — iOS Schedule/Unschedule Logic (~100 LoC, 4 Dateien)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Views/PlanningView.swift | MODIFY | scheduleTask() → SwiftData statt EventKit, load scheduled tasks |
| Sources/Views/TimelineView.swift | MODIFY | +scheduledTasks param, render ScheduledTaskBlock, +onUnschedule |
| Sources/Views/MiniBacklogView.swift | MODIFY | Filter: scheduledDate == nil |
| Sources/Services/SyncEngine.swift | MODIFY | +scheduleTask(id:date:duration:), +unscheduleTask(id:) |

#### Phase C — Visual: ScheduledTaskBlock + Context Menu (~135 LoC, 3 Dateien)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Views/Components/ScheduledTaskBlock.swift | CREATE | Eigener visueller Block-Typ (Teal/Dashed, Drag+Swipe) |
| Sources/Views/TimelineView.swift | MODIFY | Long-Press confirmationDialog auf Drop-Zone |
| Sources/Views/PlanningView.swift | MODIFY | +onCreateFocusBlock Callback fuer Long-Press |

#### Phase D — GapFinder + Notifications + macOS (~110 LoC, 4 Dateien)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Models/GapFinder.swift | MODIFY | +scheduledTasks als belegte Slots |
| Sources/Services/SmartNotificationEngine.swift | MODIFY | +buildScheduledTaskRequests() |
| FocusBloxMac/MacPlanningView.swift | MODIFY | Drop → SyncEngine.scheduleTask() |
| FocusBloxMac/MacTimelineView.swift | MODIFY | +scheduledTasks rendering |

### Scope Assessment (Gesamt)
- Files: 11 (8 MODIFY + 1 CREATE + Tests)
- Estimated LoC: ~405 ueber 4 Phasen
- Risk Level: MEDIUM (SwiftData Schema + Drop-Default aendern)

### Reihenfolge
```
Phase A (Model) → Phase B (iOS Logic) → Phase C (Visual) → Phase D (Gap/Notify/macOS)
```
Jede Phase compiliert und ist testbar.

### Empfehlung
Phase A zuerst allein committen und full Test Suite laufen lassen. Schema-Aenderungen muessen isoliert verifiziert werden bevor Views darauf aufbauen.
