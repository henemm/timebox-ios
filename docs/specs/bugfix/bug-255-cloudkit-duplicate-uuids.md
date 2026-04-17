---
entity_id: bug-255-cloudkit-duplicate-uuids
type: bugfix
created: 2026-04-17
updated: 2026-04-17
status: draft
version: "1.0"
tags: [cloudkit, dedup, startup]
---

# Bug #255 — CloudKit-Sync erzeugt doppelte Task-UUIDs

## Approval

- [ ] Approved

## Problem

CloudKit-Sync kann zwei LocalTask-Objekte mit identischer UUID im Store erzeugen. Der Crash ist gefixt (7eb4495), aber Duplikate sammeln sich im Hintergrund an.

## Fix

Neue Startup-Cleanup-Funktion `cleanupUUIDDuplicates(in:)` in `FocusBloxApp.swift`, analog zu `cleanupRemindersDuplicates(in:)`:

```swift
@discardableResult
static func cleanupUUIDDuplicates(in context: ModelContext) -> Int {
    // 1. Alle Tasks fetchen
    // 2. Nach UUID gruppieren
    // 3. Bei Duplikaten: höchsten attributeScore behalten, Rest löschen
    // 4. context.save()
}
```

Aufruf beim App-Start nach `cleanupRemindersDuplicates`.

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/FocusBloxApp.swift` | Neue Funktion + Aufruf beim Startup |
| `FocusBloxTests/DedupCleanupTests.swift` | Tests für UUID-Dedup |

## Test Plan

1. **test_cleanupUUIDDuplicates_removesExactDuplicate**: 2 Tasks mit gleicher UUID → 1 bleibt
2. **test_cleanupUUIDDuplicates_keepsHigherScore**: Task mit mehr Attributen bleibt
3. **test_cleanupUUIDDuplicates_noFalsePositives**: 2 Tasks mit verschiedener UUID → beide bleiben
4. **test_cleanupUUIDDuplicates_returnsCount**: Return-Wert = Anzahl gelöschter Tasks
