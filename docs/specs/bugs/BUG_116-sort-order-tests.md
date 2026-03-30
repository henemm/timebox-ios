---
entity_id: BUG_116
type: bugfix
created: 2026-03-30
updated: 2026-03-30
status: draft
version: "1.0"
tags: [tests, sorting, unit-tests]
---

# BUG_116: Sort-Order Unit Tests an Implementierung anpassen

## Approval

- [ ] Approved

## Purpose

Zwei Unit Tests erwarten veraltete Sortierung (sortOrder aufsteigend / rank aufsteigend), obwohl die Implementierung seit Commit 4d61fef (Bug 51 Fix) bewusst auf `createdAt` absteigend bzw. `rank` absteigend umgestellt wurde. Die Tests werden an die korrekte Implementierung angepasst.

## Source

- **File 1:** `FocusBloxTests/LocalTaskSourceTests.swift` — `test_fetchIncompleteTasks_sortsBySortOrder` (Zeile 65)
- **File 2:** `FocusBloxTests/SyncEngineTests.swift` — `test_sync_sortsByRank` (Zeile 45)

## Root Cause

| Commit | Datum | Änderung | Tests aktualisiert? |
|--------|-------|----------|---------------------|
| 4d61fef | 2026-02-16 | `fetchIncompleteTasks()`: Sort von `sortOrder` asc → `createdAt` desc | Nein |
| 4d61fef | 2026-02-16 | `sync()`: Sort von `rank` asc → `rank` desc | Nein |

Die Implementierung ist korrekt und intentional (Bug 51: "iOS Backlog sortiert neueste Tasks oben wie macOS").

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTaskSource.fetchIncompleteTasks()` | Service | Sortiert nach `createdAt` desc (korrekt) |
| `SyncEngine.sync()` | Service | Sortiert nach `rank` desc (korrekt) |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxTests/LocalTaskSourceTests.swift` | MODIFY | Test-Erwartung umkehren: createdAt desc |
| `FocusBloxTests/SyncEngineTests.swift` | MODIFY | Test-Erwartung umkehren: rank desc |

## Implementation Details

### Test 1: `test_fetchIncompleteTasks_sortsByCreatedAtDescending`

**Vorher:** Erwartet sortOrder aufsteigend (First→Second→Third)
**Nachher:** Erwartet createdAt absteigend (zuletzt eingefügt = zuerst)

- Test-Name umbenennen: `sortsBySortOrder` → `sortsByCreatedAtDescending`
- Erwartete Reihenfolge umkehren
- Hinweis: In-Memory SwiftData vergibt createdAt in Einfüge-Reihenfolge, daher ist "Third" (zuletzt eingefügt) der erste Eintrag

### Test 2: `test_sync_sortsByRankDescending`

**Vorher:** Erwartet rank aufsteigend (First→Second→Third)
**Nachher:** Erwartet rank absteigend (Third→Second→First)

- Test-Name umbenennen: `sortsByRank` → `sortsByRankDescending`
- Erwartete Reihenfolge umkehren

## Expected Behavior

- **Input:** Tasks mit sortOrder 0, 1, 2 und unterschiedlichen createdAt-Zeitpunkten
- **Output Test 1:** Tasks sortiert nach createdAt absteigend (neueste zuerst)
- **Output Test 2:** PlanItems sortiert nach rank absteigend (höchster Rang zuerst)
- **Side effects:** Keine — nur Test-Dateien betroffen

## Scope

- **Files:** 2
- **Estimated LoC:** ~±10
- **Risk Level:** LOW (nur Tests, keine Produktionsänderungen)

## Test Plan

| Test | Typ | Prüft |
|------|-----|-------|
| `test_fetchIncompleteTasks_sortsByCreatedAtDescending` | Unit | fetchIncompleteTasks sortiert nach createdAt desc |
| `test_sync_sortsByRankDescending` | Unit | sync() sortiert nach rank desc |

Validierung: Beide Tests müssen grün sein nach der Anpassung.

## Known Limitations

- Die Sortierung aus `sync()` wird von allen Aufrufern (BacklogView, DayView etc.) ohnehin überschrieben — die Tests dokumentieren aber trotzdem das korrekte Verhalten der Methode

## Changelog

- 2026-03-30: Initial spec created
