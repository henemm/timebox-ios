# BUG_110: Doppelte Controls im macOS Coach-Backlog

## Problem
Coach-Modus auf macOS zeigt ViewMode-Switcher + Sync/Import-Buttons direkt über der Task-Liste,
obwohl dieselben Funktionen bereits in der Sidebar (Filter-Auswahl) und App-Toolbar (Sync) vorhanden sind.

## Root Cause
Commit e7b5655 (BUG_109) hat MacCoachBacklogView.swift gelöscht und Coach-Features in ContentView.backlogView gemergt.
Dabei wurde die Coach-Toolbar (die in der alten separaten View nötig war, weil keine Sidebar vorhanden) 1:1 übernommen —
obwohl BUG_109 gleichzeitig die Sidebar für den Coach-Modus sichtbar gemacht hat.

## Fix
- Coach-Toolbar HStack (ContentView:386-423) entfernt
- Helper-Views entfernt: coachViewModeSwitcher, coachSyncStatusIndicator, coachFilterLabel
- ~100 LoC Dead Code beseitigt
- Alte Tests (5, 8, 9, 10) die Existenz der Controls prüften entfernt
- 4 neue Tests die Nicht-Existenz prüfen hinzugefügt

## Geänderte Dateien
- FocusBloxMac/ContentView.swift (-100 LoC)
- FocusBloxMacUITests/MacCoachBacklogUITests.swift (4 Tests entfernt, 4 neue hinzugefügt)
- docs/ACTIVE-todos.md (BUG_110 als erledigt markiert)
