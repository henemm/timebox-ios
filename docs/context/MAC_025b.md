# Context: MAC_025b — Reminders Migration auf macOS

## Request Summary
Der `migrateRemindersToLocal()` Aufruf fehlt in der macOS App-Startup-Sequenz. iOS macht das bereits, macOS nicht.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxMac/FocusBloxMacApp.swift:283-315` | Startup-Sequenz in `.onAppear` — hier fehlt der Aufruf |
| `Sources/FocusBloxApp.swift:301` | iOS-Referenz: ruft `migrateRemindersToLocal()` auf |
| `Sources/Services/RemindersImportService.swift:143` | Die Methode selbst — static, idempotent |

## Existing Patterns
- iOS ruft in `.onAppear` zuerst `cleanupLeakedTestData`, dann `migrateRemindersToLocal`, dann `cleanupRemindersDuplicates` auf
- macOS hat `cleanupLeakedTestData` bereits, aber NICHT `migrateRemindersToLocal`
- macOS hat KEINE `cleanupRemindersDuplicates` — iOS hat das aber auch nur auf iOS-Seite

## Dependencies
- Upstream: `RemindersImportService.migrateRemindersToLocal(in:)` — existiert in Shared `Sources/`
- Downstream: Keine — Migration ist fire-and-forget

## Existing Specs
- `docs/specs/macos/MAC-025-reminders-sync.md` — beschreibt den vollen Reminders-Sync (Spec ist breiter als MAC_025b)

## Risks & Considerations
- Extrem kleiner Scope: 1 Zeile Code an der richtigen Stelle
- Methode ist idempotent und static — kein Risiko bei mehrfachem Aufruf
- Muss VOR `RecurrenceService.migrateToTemplateModel` aufgerufen werden (gleiche Reihenfolge wie iOS)
- Guard `!isUITesting` existiert bereits im macOS-Code (Zeile 283)

## Analysis

### Type
Feature (fehlender Plattform-Aufruf)

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| FocusBloxMac/FocusBloxMacApp.swift | MODIFY | 1 Zeile: migrateRemindersToLocal() Aufruf in Startup-Sequenz |

### Scope Assessment
- Files: 1
- Estimated LoC: +1
- Risk Level: LOW

### Technical Approach
Einfuegen von `RemindersImportService.migrateRemindersToLocal(in: container.mainContext)` nach `cleanupLeakedTestData`, vor `forceCloudKitFieldSync` — identische Reihenfolge wie iOS.

### Dependencies
- Upstream: `RemindersImportService` (shared, Sources/)
- Downstream: Keine
