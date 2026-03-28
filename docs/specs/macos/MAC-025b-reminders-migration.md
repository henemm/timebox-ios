---
entity_id: mac_025b_reminders_migration
type: bugfix
created: 2026-03-28
updated: 2026-03-28
status: draft
version: "1.0"
tags: [macos, reminders, migration, parity]
---

# MAC_025b: Reminders Migration auf macOS

## Approval

- [ ] Approved

## Purpose

Der `migrateRemindersToLocal()` Aufruf fehlt in der macOS Startup-Sequenz. Tasks mit `sourceSystem == "reminders"` werden auf macOS nicht zu `"local"` migriert, obwohl iOS das seit langem macht. Dadurch koennten Reminders-Tasks auf macOS in einem inkonsistenten Zustand verbleiben.

## Source

- **File:** `FocusBloxMac/FocusBloxMacApp.swift`
- **Identifier:** `.onAppear` Startup-Sequenz (Zeile ~283-315)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RemindersImportService` | Service (Shared) | Stellt `migrateRemindersToLocal(in:)` bereit |
| `LocalTask` | Model (Shared) | Tasks mit `sourceSystem == "reminders"` werden migriert |

## Implementation Details

Eine Zeile in `FocusBloxMacApp.swift` einfuegen, nach `cleanupLeakedTestData` und vor `forceCloudKitFieldSync`:

```swift
// Zeile 287 (nach cleanupLeakedTestData, vor forceCloudKitFieldSync):
RemindersImportService.migrateRemindersToLocal(in: container.mainContext)
```

Reihenfolge in der Startup-Sequenz (identisch zu iOS):
1. `cleanupLeakedTestData` (bereits vorhanden)
2. **`migrateRemindersToLocal`** (NEU)
3. `forceCloudKitFieldSync` (bereits vorhanden)
4. `RecurrenceService.migrateToTemplateModel` (bereits vorhanden)

## Expected Behavior

- **Input:** App-Start auf macOS
- **Output:** Tasks mit `sourceSystem == "reminders"` werden auf `"local"` gesetzt, `externalID` auf `nil`
- **Side effects:** Keine — Methode ist idempotent. Bei 0 betroffenen Tasks: sofortiger Return.

## Affected Files

| File | Change | LoC |
|------|--------|-----|
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY: 1 Zeile einfuegen | +1 |

## Test Plan

- **Unit Test:** `RemindersImportServiceTests` deckt die Methode bereits ab (3 Tests existieren)
- **macOS Build:** `./scripts/sim.sh mac-build` muss erfolgreich sein
- **Kein neuer UI Test noetig:** Keine sichtbare UI-Aenderung, reine Daten-Migration

## Known Limitations

- Keine — die Methode existiert und ist getestet

## Changelog

- 2026-03-28: Initial spec created
