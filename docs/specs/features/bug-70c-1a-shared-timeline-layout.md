# Spec: Bug 70c-1a — Shared Timeline Layout + Collision Detection

## Ziel

TimelineLayout und Collision-Detection-Logik aus `FocusBloxMac/` nach `Sources/` extrahieren, damit iOS und macOS dieselbe Canvas-Engine nutzen koennen.

## Status: ENTWURF

## Kontext

- macOS hat eine canvas-basierte Timeline (`TimelineLayout` + `groupOverlappingItems`)
- iOS hat eine listenbasierte Timeline (kein Canvas, keine Overlap-Detection)
- Fuer Bug 70c-1b (iOS Canvas-Umbau) und 70c-2 (Resize-Drag) muss die Layout-Engine shared sein
- Aktuell sind alle relevanten Typen `private` in `MacTimelineView.swift`

## Aenderungen

### 1. Neuer File: `Sources/Models/TimelineItem.swift`

Aus `MacTimelineView.swift` extrahieren (Zeilen 13-53):
- `TimelineItem` (struct + enum ItemType) — von `private` auf `public`
- `PositionedItem` — von `private` auf `public`
- `PositionedEvent` — von `private` auf `public`
- `PositionedFocusBlock` — NICHT hier (bleibt vorerst macOS-intern, da iOS eine eigene Version brauchen wird)
- `groupOverlappingItems()` — als freie Funktion oder static Method auf `TimelineItem`

### 2. File verschieben: `FocusBloxMac/TimelineLayout.swift` → `Sources/Layouts/TimelineLayout.swift`

- Datei 1:1 verschieben (kein Code-Change noetig)
- Neues Verzeichnis `Sources/Layouts/` erstellen
- Header-Kommentar anpassen (FocusBloxMac → Shared)

### 3. File aendern: `FocusBloxMac/MacTimelineView.swift`

- `private struct TimelineItem` entfernen (kommt aus Sources/)
- `private struct PositionedItem` entfernen (kommt aus Sources/)
- `private struct PositionedEvent` entfernen (kommt aus Sources/)
- `private func groupOverlappingItems()` entfernen (kommt aus Sources/)
- `PositionedFocusBlock` bleibt vorerst `private` (nur macOS)
- `positionedItems` computed property passt Aufrufe an shared `groupOverlappingItems()` an

### 4. Xcode Projekt

- `TimelineLayout.swift` aus FocusBloxMac-Target entfernen, zu Shared-Sources hinzufuegen
- `TimelineItem.swift` zu Shared-Sources hinzufuegen
- Beide Targets (iOS + macOS) muessen die neuen Files importieren koennen

## Nicht im Scope

- iOS-Timeline-Umbau (das ist 70c-1b)
- Resize-Feature (das ist 70c-2)
- macOS View-Logik aendern (nur Imports anpassen)
- `PositionedFocusBlock` nach Sources/ verschieben (erst in 70c-1b noetig)

## Betroffene Dateien (3)

1. `Sources/Models/TimelineItem.swift` — NEU
2. `Sources/Layouts/TimelineLayout.swift` — VERSCHOBEN aus FocusBloxMac/
3. `FocusBloxMac/MacTimelineView.swift` — private Typen entfernen, shared nutzen

## Risiken

- Xcode-Projekt-Referenzen muessen korrekt aktualisiert werden
- `private` → `public` Visibility-Change koennte Namenskollisionen erzeugen (unwahrscheinlich)
- Build-Validierung auf BEIDEN Plattformen noetig

## Acceptance Criteria

- [x] `TimelineLayout` liegt in `Sources/Layouts/`
- [x] `TimelineItem`, `PositionedItem`, `PositionedEvent`, `groupOverlappingItems` liegen in `Sources/Models/`
- [x] macOS-Build kompiliert ohne Fehler
- [x] iOS-Build kompiliert ohne Fehler
- [x] Bestehende macOS UI Tests laufen weiterhin GRUEN
- [x] Keine Verhaltensaenderung auf macOS
