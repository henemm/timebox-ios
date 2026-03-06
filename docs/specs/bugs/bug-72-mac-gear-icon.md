# Bug 72: macOS — FocusBlock Gear-Icon fehlt

## Problem
Auf macOS gibt es keinen Weg, die Eigenschaften eines FocusBlocks (Start/End-Zeit, Löschen) zu bearbeiten. Das Gear-Icon fehlt in der `FocusBlockView`.

## Root Cause
`FocusBlockView` in `MacTimelineView.swift` (Zeile 401-492) hat den `onTapEdit`-Callback definiert und korrekt verdrahtet, aber **kein UI-Element** das ihn auslöst. Der `isHovered`-State existiert, wird aber nie genutzt.

## Fix
Gear-Icon Button in `FocusBlockView` hinzufügen, sichtbar bei Hover (macOS-Pattern). Analog zum iOS `TimelineFocusBlockRow` (BlockPlanningView.swift:979-988).

## Betroffene Dateien
- `FocusBloxMac/MacTimelineView.swift` — Gear-Icon Button in FocusBlockView

## Acceptance Criteria
1. Gear-Icon ("gearshape") erscheint bei Hover über einem FocusBlock
2. Tap auf Gear-Icon öffnet EditFocusBlockSheet
3. Sheet erlaubt Start/End-Zeit ändern und Block löschen
4. accessibilityIdentifier: `focusBlockEditButton_{blockID}`

## Aufwand
XS — 1 Button + Hover-Logik, ~15 LoC
