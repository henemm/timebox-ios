# Bug: Kategorie-Icon auf Kalender-Events zu klein

## Problem
Das Kategorie-Icon (CategoryIconBadge) auf Kalender-Events ist so klein (9pt Icon, 18x18 Kreis), dass man es kaum erkennen kann.

## Root Cause
`Sources/Views/CategoryIconBadge.swift:11-13` — zu kleine Werte:
- Icon-Font: 9pt
- Kreis: 18x18pt

## Fix
CategoryIconBadge von einzeilig (nur Icon im Kreis) auf zweizeilig umbauen:
- Icon oben + localizedName unten
- Capsule-Form statt Kreis
- Groessere, besser lesbare Darstellung

## Betroffene Stellen (Shared Component — 1 Aenderung, 4 Nutzer)
1. `Sources/Views/EventBlock.swift:46` — iOS Timeline
2. `Sources/Views/BlockPlanningView.swift:1050 + 1341` — iOS Planung
3. `FocusBloxMac/MacTimelineView.swift:423` — macOS Timeline

## Dateien die geaendert werden
- `Sources/Views/CategoryIconBadge.swift` — einzige Code-Aenderung
