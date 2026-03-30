---
entity_id: mac_029_menubar_icon
type: module
created: 2026-03-29
updated: 2026-03-30
status: draft
version: "1.1"
tags: [macos, menubar, icon]
---

# MAC_029 — Menubar Status Icon (Programmatic Concentric Circles)

## Approval

- [ ] Approved

## Purpose

Ersetzt das bisherige Menüzeilen-Icon (CIColorMonochrome-Filter auf dem App-Icon) durch programmatisch gezeichnete konzentrische Kreise. Das aktuelle Vorgehen erzeugt ein matschiges 18x18-Icon; die neue Methode zeichnet die Kreise direkt als scharfes Template-Image.

## Source

- **File:** `FocusBloxMac/FocusBloxMacApp.swift`
- **Identifier:** `MenuBarController.makeMenuBarIcon(size:) -> NSImage` (static)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| AppKit (NSImage, NSBezierPath) | framework | Programmatisches Zeichnen der Kreise — bereits importiert, keine neuen Dependencies |
| `FocusBloxMac/MenuBarView.swift` | module | Header-Icon wird entkoppelt: nutzt direkt `NSApp.applicationIconImage` statt `makeMenuBarIcon` |
| `FocusBloxMac/QuickCapturePanel.swift` | module | Header-Icon wird entkoppelt: nutzt direkt `NSApp.applicationIconImage` statt `makeMenuBarIcon` |
| `FocusBloxMacTests/MenuBarIdleIconTests.swift` | test | Tests werden auf neue Signatur und Template-Eigenschaften angepasst |

## Implementation Details

### Geänderte Dateien

| File | Change Type | Beschreibung |
|------|-------------|-------------|
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | `makeMenuBarIcon` komplett neu: programmatische Kreise statt Bitmap-Filter. Signatur ändert sich von `makeMenuBarIcon(from:size:)` zu `makeMenuBarIcon(size:)` — kein Bitmap-Input mehr nötig. `setup()` anpassen: `idleImage` ohne `NSApp.applicationIconImage`. (-33/+20 LoC) |
| `FocusBloxMac/MenuBarView.swift` | MODIFY | Header-Icon (L240): Direkt `NSApp.applicationIconImage` skaliert nutzen statt `makeMenuBarIcon` (~3 LoC) |
| `FocusBloxMac/QuickCapturePanel.swift` | MODIFY | Header-Icon (L145): Direkt `NSApp.applicationIconImage` skaliert nutzen statt `makeMenuBarIcon` (~3 LoC) |
| `FocusBloxMacTests/MenuBarIdleIconTests.swift` | MODIFY | Tests anpassen: neue Signatur ohne `from:`, `isTemplate = true` prüfen, Alpha-Kanal-Test hinzufügen (~15 LoC) |

### Zeichenlogik (`makeMenuBarIcon(size:)`)

Technik: Drei gestrokte Ringe mit transparenten Lücken dazwischen.
Im Gegensatz zu gefüllten Scheiben (die ineinander verschmelzen) erzeugt `stroke()` scharfe Ringe mit sichtbarer Trennung — wie im App-Icon.

```swift
static func makeMenuBarIcon(size: NSSize) -> NSImage {
    let image = NSImage(size: size, flipped: false) { rect in
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        let outerRingWidth = maxRadius * 0.28
        let midRingWidth = maxRadius * 0.22

        // Äußerer Ring (gestrokt, hellster Ring — wie im App-Icon)
        NSColor.black.withAlphaComponent(1.0).setStroke()
        let outerPath = NSBezierPath()
        outerPath.appendOval(in: rect.insetBy(dx: outerRingWidth / 2, dy: outerRingWidth / 2))
        outerPath.lineWidth = outerRingWidth
        outerPath.stroke()

        // Mittlerer Ring (dunkler als äußerer)
        NSColor.black.withAlphaComponent(0.75).setStroke()
        let midRadius = maxRadius * 0.54
        let midRect = NSRect(
            x: center.x - midRadius, y: center.y - midRadius,
            width: midRadius * 2, height: midRadius * 2
        )
        let midPath = NSBezierPath()
        midPath.appendOval(in: midRect.insetBy(dx: midRingWidth / 2, dy: midRingWidth / 2))
        midPath.lineWidth = midRingWidth
        midPath.stroke()

        // Innerer Kern (gefüllt, dunkelster — wie im App-Icon)
        NSColor.black.withAlphaComponent(0.60).setFill()
        let coreRadius = maxRadius * 0.13
        let coreRect = NSRect(
            x: center.x - coreRadius, y: center.y - coreRadius,
            width: coreRadius * 2, height: coreRadius * 2
        )
        NSBezierPath(ovalIn: coreRect).fill()

        return true
    }
    image.isTemplate = true
    return image
}
```

In `setup()` ändert sich der Aufruf:

```swift
// Vorher: idleImage = Self.makeMenuBarIcon(from: appIcon, size: NSSize(width: 18, height: 18))
// Nachher:
idleImage = Self.makeMenuBarIcon(size: NSSize(width: 18, height: 18))
```

### Entkopplung MenuBarView & QuickCapturePanel

Header-Icons in beiden Views ersetzen den `makeMenuBarIcon`-Aufruf durch:

```
NSApp.applicationIconImage  // skaliert auf 20x20 bzw. 24x24 per .resizingMode
```

## Expected Behavior

- **Input:** Gewünschte Größe (NSSize), typischerweise 18x18pt
- **Output:** NSImage mit drei konzentrischen Kreisen als Template-Image (`isTemplate = true`)
- **Side effects:** Das Icon passt sich automatisch an Systemfarben an — dunkel auf hellem Hintergrund, hell auf dunklem Hintergrund. MenuBarView und QuickCapturePanel nutzen ab sofort direkt `NSApp.applicationIconImage` für ihre Header-Icons.

Bei 18x18pt @2x (36px) sind die Kreise scharf und als konzentrische Ringe erkennbar, analog zum App-Icon-Motiv (3 Ringe: äußerer Ring, mittlerer Ring, innerer Punkt).

## Known Limitations

- Template-Images können nur einfarbig sein (keine Farbverläufe) — bewusste Design-Entscheidung, da macOS Template-Images für Menüzeilen-Icons erwartet.
- Die Proportionen (0.28 / 0.22 / 0.54 / 0.13) und Alpha-Werte (1.0 / 0.75 / 0.60) wurden durch iterativen visuellen Vergleich mit dem App-Icon optimiert. Alpha-Gradient: außen hell → innen dunkel (wie im App-Icon).

## Changelog

- 2026-03-29: Initial spec created
- 2026-03-30: v1.1 — Proportionen und Alpha-Gradient aus Pixel-Analyse des App-Icons korrigiert
- 2026-03-30: v1.2 — Proportionen durch iterativen A/B-Vergleich in der Menüleiste finalisiert (outer 0.28, mid 0.22@0.54r, core 0.13, alpha 1.0/0.75/0.60)
