---
entity_id: bug-cross-platform-sync
type: bugfix
created: 2026-04-01
updated: 2026-04-01
status: approved
version: "1.0"
tags: [cloudkit, sync, macos]
---

# Bug: Cross-Platform Sync — macOS zeigt iOS-Completions nicht

## Approval

- [x] Approved

## Purpose

macOS ContentView refresht die Task-Liste nicht wenn die App aus dem Hintergrund zurückkehrt. Tasks die auf iOS als erledigt markiert wurden bleiben auf macOS als aktiv sichtbar, obwohl die Daten im lokalen Persistent Store bereits aktualisiert sind.

## Source

- **File:** `FocusBloxMac/ContentView.swift`
- **Root Cause:** Kein `scenePhase`-Observer in ContentView → kein `refreshTasks()` bei App-Aktivierung

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| CloudKitSyncMonitor | Service | Empfängt Remote-Change-Notifications |
| FocusBloxMacApp | App | Hat scenePhase-Observer, ruft nur triggerSync() auf |

## Fix

ContentView bekommt einen eigenen `scenePhase`-Observer der bei `.active` → `refreshTasks()` aufruft.

**Änderung in `FocusBloxMac/ContentView.swift`:**
1. `@Environment(\.scenePhase)` Property hinzufügen
2. `.onChange(of: scenePhase)` Modifier hinzufügen der bei `.active` → `refreshTasks()` aufruft

## Expected Behavior

- **Vorher:** macOS zeigt stale Task-Daten nach Rückkehr aus Background
- **Nachher:** macOS refresht Task-Liste automatisch bei App-Aktivierung
- **Side effects:** Keine — `refreshTasks()` ist idempotent (save + fetch)

## Known Limitations

- Löst nicht das grundsätzliche Problem dass CloudKit-Transport langsam sein kann
- Löst nicht die fehlenden `refreshTasks()`-Calls in MacFocusView/TaskInspector (separate Bugs)

## Changelog

- 2026-04-01: Initial spec created
