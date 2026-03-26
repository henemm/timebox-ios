# Context: RW_4.1 — Soft Evening Reset

## Request Summary
Automatischer Tageswechsel-Service: Unerledigte Next-Up-Tasks zurueck ins Backlog (isNextUp=false, rescheduleCount++), vergangene scheduledDate loeschen. Morgens Clean Slate. Kein UI — reine Service-Logik.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Models/AppSettings.swift` | + `lastResetDate: Date?`, + `resetHour: Int` (neue Properties) |
| `Sources/Models/LocalTask.swift` | `isNextUp`, `rescheduleCount`, `scheduledDate`, `modifiedAt` — die Felder die zurueckgesetzt werden |
| `Sources/Models/PlanItem.swift` | Presentation-Layer-Mapping von LocalTask (read-only, keine Aenderung noetig) |
| `Sources/Services/SyncEngine.swift` | Bulk-Update-Pattern (Predicate → Loop → Save), wird als Vorlage genutzt |
| `Sources/Services/LocalTaskSource.swift` | Task-Fetch und Update-Patterns |
| `Sources/Services/SmartNotificationEngine.swift` | `reconcile(reason:container:eventKitRepo:)` — nach Reset aufrufen |
| `Sources/FocusBloxApp.swift` | iOS App-Start — Trigger-Ort (onAppear, nach Cleanup ~Line 316) |
| `FocusBloxMac/FocusBloxMacApp.swift` | macOS App-Start — Trigger-Ort (onAppear, nach Cleanup ~Line 301) |

## Existing Patterns
- **Cleanup-on-Launch:** App fuehrt bereits mehrere Cleanup-Operationen in onAppear aus (Reminders-Dedup, Orphaned-Blocks, CloudKit-Sync, Recurrence-Repair)
- **Bulk-Update:** SyncEngine nutzt Predicate-based FetchDescriptor → Loop → Single Save Pattern
- **Idempotenz:** AppSettings mit @AppStorage fuer lastResetDate-Tracking
- **Background Tasks:** SmartNotificationEngine hat bereits BGAppRefreshTask-Registrierung (iOS)
- **Reconcile-Trigger:** Wird bereits bei App-Foreground und App-Background aufgerufen

## Dependencies
- **Upstream:** LocalTask (SwiftData Model), AppSettings (@AppStorage), ModelContext
- **Downstream:** SmartNotificationEngine (Reconcile nach Reset), DayView Morning Mode (zeigt dann leeres Next-Up)

## Existing Specs
- `docs/specs/rework/4.1-soft-evening-reset.md` — Feature-Spec (Akzeptanzkriterien + technische Vorgaben)

## Risks & Considerations
- **Timezone-Wechsel:** Tagesgrenze mit Calendar.current.startOfDay vergleichen, nicht absolute Dates
- **CloudKit-Sync:** modifiedAt auf allen geaenderten Tasks aktualisieren, sonst kein Sync
- **Idempotenz:** Doppelter Aufruf am selben Tag darf keine Aenderungen machen (lastResetDate-Check)
- **nextUpSortOrder:** Muss zusammen mit isNextUp gecleared werden (Pattern aus SyncEngine.updateNextUp)
- **assignedFocusBlockID:** Muss bei isNextUp=false ebenfalls gecleared werden (Bug 52 Pattern)
- **Kein Datenverlust:** Nur Status-Felder aendern, keine Tasks loeschen

---

## Analysis

### Type
Feature (reine Service-Logik, kein UI)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/EveningResetService.swift` | CREATE | Reset-Logik: isNextUp-Clear, rescheduleCount++, scheduledDate-Clear, Idempotenz |
| `Sources/Models/AppSettings.swift` | MODIFY | + `lastResetDate: String` (ISO-Datum), + `resetHour: Int` (~5 LoC) |
| `Sources/FocusBloxApp.swift` | MODIFY | Reset-Aufruf in onAppear nach Cleanup (~5 LoC) |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | Reset-Aufruf in onAppear nach Cleanup (~5 LoC) |
| `FocusBloxTests/EveningResetServiceTests.swift` | CREATE | Unit Tests: Idempotenz, Field-Clearing, Edge Cases |
| `FocusBloxUITests/EveningResetUITests.swift` | CREATE | UI Tests: App-Start-Reset, Morning Empty State |

### Scope Assessment
- Files: 6 (3 MODIFY, 3 CREATE)
- Estimated LoC: ~200 production + ~200 tests = ~400 total
- Risk Level: LOW — folgt bestehenden Cleanup-on-Launch Patterns, keine UI-Aenderungen

### Technical Approach
1. `EveningResetService` als `@MainActor enum` mit statischer `performResetIfNeeded(context:)` Methode
2. Idempotenz via `AppSettings.shared.lastResetDate` (ISO-String-Vergleich, Pattern von nudgeLastDate)
3. Zwei Predicate-Fetches: (a) isNextUp && !isCompleted, (b) scheduledDate < startOfDay
4. Single `modelContext.save()` nach allen Aenderungen
5. Reconcile-Aufruf nach Reset via bestehende Notification-Engine
6. BGAppRefreshTask als Best-Effort (optional, App-Start ist der zuverlaessige Pfad)

### Dependencies
- **Upstream:** SwiftData (LocalTask), AppSettings (@AppStorage Singleton)
- **Downstream:** SmartNotificationEngine.reconcile(), DayView Morning (leeres Next-Up)
- **Related Specs:** RW_0.1 (Notification Engine, bereits implementiert), RW_2.1d (Evening UI, bereits implementiert)

### Open Questions
Keine — Spec ist klar, alle Patterns existieren im Codebase.
