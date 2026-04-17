---
entity_id: bug-duplicate-key-crash
type: bugfix
created: 2026-04-17
updated: 2026-04-17
status: draft
version: "1.0"
tags: [crash, dictionary, cloudkit-sync, duplicate]
---

# Bug: Crash bei doppelten Task-UUIDs (Tagesrückblick)

## Approval

- [ ] Approved

## Purpose

Alle `Dictionary(uniqueKeysWithValues:)` Aufrufe durch crash-sichere Varianten ersetzen, damit doppelte Task-UUIDs (durch CloudKit-Sync) keinen Fatal Error mehr auslösen.

## Source

- **Crash-Stelle:** `Sources/Models/ReviewStatsCalculator.swift:56`
- **Aufgerufen von:** `Sources/Views/CoachView.swift:645` (Tagesrückblick-Drawer)

## Betroffene Stellen

| Datei | Zeile | Screen |
|-------|-------|--------|
| `Sources/Models/ReviewStatsCalculator.swift` | 56 | Coach Tagesrückblick |
| `Sources/Views/BacklogView.swift` | 695 | Backlog-Sortierung |
| `Sources/Models/LocalTask.swift` | 164 | Blocker-Zyklen-Check |
| `FocusBloxMac/ContentView.swift` | 1326 | macOS Backlog-Sortierung |

## Fix

Jede Stelle: `Dictionary(uniqueKeysWithValues:)` ersetzen durch `Dictionary(..., uniquingKeysWith: { _, last in last })`.

Bei Duplikaten wird das letzte Element behalten statt zu crashen. Das ist sicher, weil:
- Task-Duplikate durch CloudKit-Sync sind identisch (selbe Daten)
- Die Wahl "first vs last" ist daher irrelevant
- Der Crash ist das eigentliche Problem, nicht die Duplikate selbst

## Expected Behavior

- **Vorher:** App crasht sofort wenn ein Task-UUID doppelt im Store vorkommt
- **Nachher:** App funktioniert normal, Duplikate werden still ignoriert
- **Side effects:** Keine

## Tests

1. Unit Test: `computePlanningAccuracy` mit doppelten Task-IDs aufrufen — kein Crash
2. Unit Test: `wouldCreateCycle` (LocalTask) mit doppelten Task-IDs — kein Crash
3. Unit Test: BacklogView-Sortierung mit doppelten IDs — kein Crash

## Known Limitations

- Fix behandelt das Symptom (Crash), nicht die Root Cause (Duplikate im Store)
- Duplikat-Bereinigung im SwiftData-Store ist ein separates Thema (CloudKit-Sync)

## Changelog

- 2026-04-17: Initial spec created
