---
entity_id: bug-38-cross-platform-sync
type: bugfix
created: 2026-02-12
status: draft
workflow: bug-38-cross-platform-sync
---

# Bug 38: Cross-Platform Sync (iOS ↔ macOS)

## Approval

- [ ] Approved by PO

## Problem

FocusBlox auf macOS erstellt mit zugewiesenen Tasks werden auf iOS nicht angezeigt.
Einstellungen (Kalender-Auswahl, Sound, Warnungen etc.) synchronisieren nicht zwischen Geraeten.

## Root Cause

1. `fetchFocusBlocks()` filtert nach `visibleCalendars()` aus lokalen UserDefaults.
   iOS hat andere/keine sichtbaren Kalender konfiguriert → FocusBlox unsichtbar.
2. Alle App-Einstellungen in `@AppStorage` (= `UserDefaults.standard`) sind geraete-lokal.
3. Kalender-IDs sind geraete-spezifisch - gleicher iCloud-Kalender hat verschiedene IDs.

## Scope

- **Files:** 4 Dateien
- **Estimated:** ~80 LoC

## Implementation Details

### Teil 1: FocusBlox immer sichtbar (Sofort-Fix)

`EventKitRepository.swift`: `fetchFocusBlocks()` laedt aus ALLEN Kalendern (nil-Filter),
unabhaengig von `visibleCalendars()`. FocusBlox sind App-eigene Daten.

### Teil 2: Settings-Sync via NSUbiquitousKeyValueStore

Neue Klasse `SyncedSettings` die alle Einstellungen ueber `NSUbiquitousKeyValueStore`
synchronisiert. Bei Kalender-IDs: Matching nach Kalender-NAME statt ID.

Synchronisierte Keys:
- `selectedCalendarName` (Name statt ID, aufgeloest per Geraet)
- `visibleCalendarNames` (Namen statt IDs)
- `visibleReminderListNames` (Namen statt IDs)
- `remindersSyncEnabled`
- `soundEnabled`
- `warningEnabled`
- `warningTimingRaw`

Ablauf:
1. App schreibt Einstellungen in `NSUbiquitousKeyValueStore`
2. Anderes Geraet empfaengt Aenderung via `NSUbiquitousKeyValueStoreDidChangeExternallyNotification`
3. App loest Kalender-Namen in lokale IDs auf
4. Lokale `UserDefaults` werden aktualisiert

### Betroffene Dateien

1. `Sources/Services/EventKitRepository.swift` - fetchFocusBlocks nil-Filter
2. `Sources/Models/SyncedSettings.swift` - NEU: iCloud KV Store Sync-Logik
3. `Sources/FocusBloxApp.swift` - SyncedSettings initialisieren
4. `FocusBloxMac/FocusBloxMacApp.swift` - SyncedSettings initialisieren

## Test Plan

### Unit Tests

- [ ] Test 1: fetchFocusBlocks laedt aus allen Kalendern (nicht nur sichtbare)
- [ ] Test 2: SyncedSettings schreibt in NSUbiquitousKeyValueStore
- [ ] Test 3: Kalender-Name-Matching findet richtigen Kalender
- [ ] Test 4: Ungueltige Kalender-Namen werden ignoriert

## Acceptance Criteria

- [ ] FocusBlox von macOS sind auf iOS sichtbar (und umgekehrt)
- [ ] Einstellungen synchronisieren zwischen Geraeten
- [ ] Kalender-Auswahl funktioniert trotz unterschiedlicher IDs
- [ ] Build kompiliert ohne Errors (beide Plattformen)
- [ ] Alle Unit Tests gruen
