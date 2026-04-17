# Bug-Analyse: Crash beim Tagesrückblick (Coach-View)

## Fehlermeldung
```
Swift/NativeDictionary.swift:792: Fatal error: Duplicate values for key: '24F583D9-A313-4ED3-8096-04951EBF57B0'
```

## Root Cause

`ReviewStatsCalculator.swift:56` verwendet `Dictionary(uniqueKeysWithValues:)` — ein Swift-Initialisierer der bei doppelten Keys sofort mit Fatal Error crasht. Die UUID existiert zweimal als `LocalTask` im SwiftData-Store, vermutlich durch CloudKit-Sync-Konflikt.

**Crash-Stelle:**
```swift
// Sources/Models/ReviewStatsCalculator.swift:56
let taskMap = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })
```

**Aufgerufen von:** `CoachView.swift:645` im `eveningPlanningAccuracySection` (Tagesrückblick-Drawer).

## User-Erwartung (User Advocate)
Der Tagesrückblick ist der Moment am Abend wo der User seinen Tag abschließen will. Die App crasht genau in diesem emotional wichtigen Moment — kein Workaround möglich, Feature komplett unbenutzbar.

## Blast Radius — 4 betroffene Stellen

| Datei:Zeile | Screen | Status |
|---|---|---|
| `ReviewStatsCalculator.swift:56` | Coach Tagesrückblick | **CRASHT JETZT** |
| `BacklogView.swift:695` | Backlog | Crash-Kandidat |
| `LocalTask.swift:164` | Blocker-Dialog | Crash-Kandidat |
| `FocusBloxMac/ContentView.swift:1326` | macOS Backlog | Crash-Kandidat |

## Bekanntes Muster
Duplikate durch CloudKit-Sync sind bekannt (BUG_107, BUG_123, Bug 34). Der konkrete Crash in ReviewStatsCalculator ist neu — eingeführt mit Issue #207 (Commit 96aa29d, 12. April).

## Fix-Vorschlag
Alle 4 Stellen: `Dictionary(uniqueKeysWithValues:)` → `Dictionary(..., uniquingKeysWith: { _, last in last })`. Klein, 4 Zeilen in 4 Dateien.
