# macOS Layout Fix - Persistenter Plan

## Problem (Screenshot 2026-02-03)

**Was kaputt ist:**
- Riesiger leerer Bereich OBERHALB des Stunden-Rasters (06:00)
- Timeline beginnt in der MITTE des Fensters statt OBEN
- Betrifft: Planen, Zuweisen, Review Tabs

**Was NICHT das Problem ist:**
- ❌ Events haben normale Breite (KEIN schmaler Streifen)
- ❌ Stunden-Raster selbst ist korrekt (06:00-22:00 sichtbar)

## Bisherige Versuche (alle gescheitert)

1. `git checkout a5fef6c -- FocusBloxMac/` → immer noch kaputt
2. `git checkout 048d9d3 -- FocusBloxMac/` → immer noch kaputt
3. DerivedData löschen + Clean Build → immer noch kaputt

## Schlussfolgerung

Das Problem liegt NICHT in FocusBloxMac/, sondern in:
- `Sources/Views/TimelineView.swift` (shared)
- Oder anderen shared Views

## Nächste Schritte

1. [ ] TimelineView.swift auf a5fef6c zurücksetzen
2. [ ] Alle Sources/Views/ die Timeline betreffen prüfen
3. [ ] Testen

## Screenshot-Referenz

`docs/artifacts/macos-layout-fix/before-empty-space.png`
