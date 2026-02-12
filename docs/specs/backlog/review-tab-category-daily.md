# Ticket A: Kategorie-Breakdown in Tagesansicht + Bugfixes

## Problem

1. iOS DailyReviewView Zeile 468 benutzt `syncEngine.sync()` - filtert erledigte Tasks raus (Bug 43 nicht in Review Tab gefixt)
2. macOS filtert nach `createdAt` statt `completedAt` - falsche Zuordnung
3. Kategorie-Zeitverteilung nur im Wochen-View, fehlt komplett im Tages-View
4. Kalenderevents fehlen im Tages-View

## Scope

- iOS: `categoryStatsSection` auch in Heute-View einbauen
- macOS: `DayReviewContent` um Kategorie-Balken erweitern
- Bug 43 fix in `DailyReviewView.swift` (syncEngine -> FetchDescriptor)
- macOS `createdAt` -> `completedAt` fixen
- ~4 Dateien, ~150 LoC

## Betroffene Dateien

- `Sources/Views/DailyReviewView.swift`
- `FocusBloxMac/MacReviewView.swift`
- Evtl. `Sources/Models/ReviewStatsCalculator.swift`

## Prioritaet

Hoch - Bugfix + Feature-Erweiterung

## Status

Backlog
