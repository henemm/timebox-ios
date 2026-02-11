---
entity_id: bug-34-dedup-cleanup
type: bugfix
created: 2026-02-11
status: draft
workflow: bug-34-cloudkit-duplicates
---

# Bug 34: Dedup-Bereinigung bestehender Reminders-Duplikate

## Approval

- [ ] Approved for implementation

## Purpose

Nach Aktivierung von CloudKit (Bug 33 Fix) existieren doppelte Tasks: vollstaendige Versionen via CloudKit und abgespeckte Kopien via Reminders-Import. Die bestehenden Duplikate muessen einmalig beim App-Start automatisch bereinigt werden.

## Root Cause

Zwei parallele Sync-Pfade erzeugten identische Tasks:
1. **CloudKit** synct vollstaendige Tasks von macOS (`sourceSystem="local"`, alle Attribute)
2. **Reminders-Import** importierte die gleichen Tasks nochmal (`sourceSystem="reminders"`, nur title/dueDate/priority)

`RemindersSyncService.findTask(byExternalID:)` (Zeile 91-96) filtert auf `sourceSystem=="reminders"` und erkennt CloudKit-Versionen nicht als Duplikate.

Bug 34 Fix (Commit `144aa0f`) verhindert neue Duplikate. Dieser Fix bereinigt bestehende.

## Scope

- **Files:** `Sources/FocusBloxApp.swift` (1 Datei)
- **Estimated:** +40/-0 LoC

## Implementation Details

Neue private Funktion `cleanupRemindersDuplicates()` in `FocusBloxApp`:

1. Skip bei UI-Testing
2. Skip wenn UserDefaults-Flag `dedupCleanupBug34Done` bereits gesetzt
3. Alle Tasks mit `sourceSystem == "reminders"` fetchen
4. Alle Tasks mit `sourceSystem != "reminders"` fetchen
5. Set der Titel der non-reminders Tasks bilden
6. Reminders-Tasks loeschen, deren Titel im Set vorkommt
7. `context.save()` und Flag setzen

Aufruf in `.onAppear` vor anderen Initialisierungen.

## Test Plan

### Automated Tests (TDD RED)

Unit Tests in `FocusBloxTests/DedupCleanupTests.swift`:

- [ ] Test 1: GIVEN reminders-Task "Einkaufen" AND local-Task "Einkaufen" WHEN dedup runs THEN reminders-Task deleted, local-Task kept
- [ ] Test 2: GIVEN reminders-Task "Nur in Reminders" AND no matching local-Task WHEN dedup runs THEN reminders-Task kept (kein Duplikat)
- [ ] Test 3: GIVEN no reminders-Tasks WHEN dedup runs THEN nothing deleted, flag set
- [ ] Test 4: GIVEN flag already set WHEN dedup runs THEN function returns immediately (no DB access)

## Acceptance Criteria

- [ ] Bestehende Reminders-Duplikate werden beim ersten App-Start automatisch geloescht
- [ ] Tasks ohne CloudKit-Gegenstueck bleiben erhalten
- [ ] Bereinigung laeuft nur einmal (UserDefaults-Flag)
- [ ] Kein Effekt bei UI-Testing
- [ ] Build kompiliert ohne Errors
- [ ] Alle Unit Tests gruen

## Changelog

- 2026-02-11: Initial spec created
