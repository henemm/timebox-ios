---
entity_id: bug-mac-duplicate-tasks
type: bug
created: 2026-05-04
updated: 2026-05-04
status: draft
version: "1.0"
tags: [macos, cloudkit, swiftdata, cleanup, parity]
---

# Bug: macOS zeigt alle Tasks doppelt

## Approval

- [ ] Approved

## Purpose

Behebt eine Asymmetrie zwischen iOS- und macOS-App-Start: iOS ruft `cleanupUUIDDuplicates()` auf, macOS nicht. Dadurch sammeln sich auf macOS CloudKit-Sync-Duplikate (Tasks mit identischer UUID, mehrfach im SwiftData-Store) und werden in der Backlog-Liste mehrfach angezeigt.

## Source (geänderte Dateien)

**Architektur-Korrektur (2026-05-04):** `FocusBloxApp` ist iOS-only (`@UIApplicationDelegateAdaptor`). Cleanup-Funktionen sind als static-Methods auf diesem struct nicht vom macOS-Target erreichbar. Daher wird die Logik in einen plattformübergreifenden Shared-Service ausgelagert.

- **Neu:** `Sources/Services/TaskDeduplicationService.swift` — Enthält `cleanupUUIDDuplicates(in:)` und `cleanupRemindersDuplicates(in:)` als static-Methods auf einem `enum TaskDeduplicationService` (cross-platform, beide Targets nutzen ihn)
- **Modify:** `Sources/FocusBloxApp.swift` — Bestehende `cleanupUUIDDuplicates`/`cleanupRemindersDuplicates` werden zu Wrappers, die `TaskDeduplicationService` aufrufen (bestehende iOS-Tests bleiben unverändert kompatibel)
- **Modify:** `FocusBloxMac/FocusBloxMacApp.swift` — Aufrufe von `TaskDeduplicationService.cleanupRemindersDuplicates(in:)` und `TaskDeduplicationService.cleanupUUIDDuplicates(in:)` im Startup-Block ergänzen
- **Test (neu, bereits geschrieben):** `FocusBloxTests/Services/MacStartupCleanupTests.swift` — Strukturtests prüfen Strings `cleanupUUIDDuplicates` / `cleanupRemindersDuplicates` in `FocusBloxMacApp.swift`. Diese Strings bleiben durch das Refactoring vorhanden — Tests bleiben gültig.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBloxApp.cleanupUUIDDuplicates(in:)` | static func | Bereits implementierte Cleanup-Funktion |
| `FocusBloxApp.cleanupRemindersDuplicates(in:)` | static func | Bereits implementierte Cleanup-Funktion |
| `LocalTask` | SwiftData-Model | Hat **keinen** `#Unique`-Constraint auf `uuid` — Grund warum CloudKit Duplikate zulässt |

## Erwartetes Verhalten (User-Sicht)

**Vorher (Bug):**
- macOS-App öffnen → Tasks erscheinen 2× oder 3× untereinander
- Sidebar-Counts (Today, Recurring, Completed) verdoppelt
- iCloud-Sync trägt Duplikate zum iPhone (dort durch iOS-Cleanup beim nächsten Start aufgeräumt)

**Nachher (Fix):**
- macOS-App öffnen → jede Task erscheint **genau einmal**
- Beim ersten Start nach Fix: vorhandene Duplikate werden aufgeräumt (in der Test-DB des Users: 147 → 116 Tasks erwartet)
- Cleanup wird über iCloud zu allen Geräten synchronisiert
- Bei späteren Starts: Cleanup ist idempotent (löscht nichts wenn keine Duplikate da sind)

## Implementation Details

### Änderung in `FocusBloxMac/FocusBloxMacApp.swift`

In der `if !isUITesting` Sequenz (aktuell Zeile 370-382), **nach** `cleanupLeakedTestData` und **vor** der Recurrence-Migration die zwei fehlenden Cleanups ergänzen:

```swift
if !isUITesting {
    syncMonitor.startRemoteChangeMonitoring(container: container)
    Self.cleanupLeakedTestData(in: container.mainContext)

    // Bug bug-mac-duplicate-tasks: Parität zu iOS — UUID- und Reminders-Duplikate aufräumen
    FocusBloxApp.cleanupRemindersDuplicates(in: container.mainContext)
    FocusBloxApp.cleanupUUIDDuplicates(in: container.mainContext)

    RemindersImportService.migrateRemindersToLocal(in: container.mainContext)
    // … rest unverändert
}
```

**Reihenfolge-Begründung:**
- Cleanups laufen **vor** `RemindersImportService.migrateRemindersToLocal` und **vor** `migrateToTemplateModel`, damit alle nachfolgenden Schritte auf einem sauberen Datenbestand arbeiten.
- Genau dieselbe Reihenfolge wie in `Sources/FocusBloxApp.swift:360-361`.

### Unit-Test (`FocusBloxTests/Services/MacStartupCleanupTests.swift`)

Der Test simuliert den Bug-Zustand und beweist, dass der Fix wirkt:

**Test 1 — `testStartup_removesUUIDDuplicates`:**
- Setup: In-Memory-Container, 2 `LocalTask` mit identischer UUID, einer "reichhaltiger" (mit Tags, Importance, Duration)
- Action: `cleanupUUIDDuplicates(in: context)` aufrufen
- Assert: Genau 1 Task übrig, der reichhaltige bleibt, `try XCTUnwrap` für gefundenen Task

**Test 2 — `testStartup_idempotent_noDuplicatesNoOp`:**
- Setup: 3 unterschiedliche Tasks (verschiedene UUIDs)
- Action: `cleanupUUIDDuplicates(in: context)` zweimal aufrufen
- Assert: Beide Aufrufe geben 0 zurück (`XCTAssertEqual(deleted, 0)`), alle 3 Tasks bleiben erhalten

**Test 3 — `testStartup_handlesTripleDuplicates`:**
- Setup: 3 Tasks mit identischer UUID (genau das Szenario aus dem Bug-Report — DB-Daten zeigten 3× pro Task)
- Action: `cleanupUUIDDuplicates(in: context)` aufrufen
- Assert: Genau 1 Task übrig, return-Value = 2 (zwei gelöscht)

**Anti-Silent-Pass-Schutz:**
- Alle `try?` durch `try XCTUnwrap` ersetzen
- Nach jeder Cleanup-Operation: Fetch der verbleibenden Tasks und konkrete Count-Assertion
- Test scheitert nachweislich ohne Fix (siehe Phase 4 RED).

## Acceptance Criteria

1. **Daten-Integrität:** Nach App-Start auf macOS gibt `SELECT COUNT(*) FROM ZLOCALTASK GROUP BY ZUUID HAVING COUNT(*)>1` **0 Zeilen** zurück.
2. **Anzeige:** Backlog-Liste auf macOS zeigt jede Task genau einmal (visuell verifiziert via Screenshot vorher/nachher).
3. **Sidebar-Counts:** Today/Recurring/Completed-Zähler entsprechen der tatsächlichen unique-Task-Anzahl.
4. **Idempotenz:** Wiederholtes Starten der App ändert die Task-Anzahl nicht.
5. **iOS unverändert:** Auf iOS ändert sich nichts (Code dort schon vorhanden, nicht angefasst).
6. **Tests grün:** 3 neue Unit-Tests in `MacStartupCleanupTests.swift` PASS, schlagen ohne Fix nachweisbar fehl.

## Side Effects (vollständig)

- **Geänderte Dateien:** 4
  - `Sources/Services/TaskDeduplicationService.swift` (NEU, ~85 LoC — Logik aus `FocusBloxApp` übernommen)
  - `Sources/FocusBloxApp.swift` (modify, ~10 LoC — Wrapper-Umstellung)
  - `FocusBloxMac/FocusBloxMacApp.swift` (modify, +3 LoC)
  - `FocusBloxTests/Services/MacStartupCleanupTests.swift` (NEU, schon geschrieben in Phase 4)
- **LoC:** ~+150 gesamt → unter 250-Limit
- **Persistente Datenänderung:** **Ja** — beim ersten Start nach Fix werden in Hennings Store 31 Duplikate gelöscht (147 → 116 Tasks).
- **iCloud-Sync:** Die Deletes werden via CloudKit zum iPhone propagiert. iPhone hat schon iOS-Cleanup, also doppelt sicher.
- **Reminders.app:** Keine Auswirkung — `RemindersImportService` ist Einbahn (Reminders → FocusBlox).
- **AppStorage-Keys:** Keine.
- **Audio/Permissions:** Keine.

## Known Limitations

- **Root-Cause des CloudKit-Sync-Bugs nicht gefixt.** Das Fehlen von `#Unique` auf `LocalTask.uuid` bleibt — neue Duplikate können theoretisch wieder entstehen, der Cleanup räumt sie aber beim nächsten Start auf. Ein `#Unique`-Constraint nachträglich hinzuzufügen ist eine Schema-Migration und ist **nicht Teil dieses Bugs** (separates Backlog-Item).
- **Nicht-UUID-Duplikate** (gleicher Titel, unterschiedliche UUIDs — z.B. Recurring-Race aus Investigator-Hypothese H4) sind durch diesen Fix **nicht** abgedeckt. Falls solche Fälle auftreten: separater Bug.

## Test Plan (TDD RED → GREEN)

**Phase 4 (RED):** Tests schreiben → ausführen → erwartete Fehlschläge dokumentieren.
**Phase 5 (GREEN):** Fix einbauen → Tests grün → SQL-Re-Check (`sqlite3 ... HAVING COUNT(*)>1` muss leer sein nach App-Start).

## Changelog

- 2026-05-04: Initial spec created (Bug-Analyse + Fix-Vorschlag)
