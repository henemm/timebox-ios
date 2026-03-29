# Context: MAC_029 — Menubar Icon optimieren

## Request Summary
Das aktuelle Menüzeilen-Icon (Grayscale-Filter auf App-Icon) sieht matschig aus. Stattdessen sollen konzentrische Kreise programmatisch als Template-Image gezeichnet werden mit Alpha-Abstufungen wie iOS-Monochrome-Rendering.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxMac/FocusBloxMacApp.swift` (L40-72) | `makeMenuBarIcon(from:size:)` — aktuelle Implementation (crop + CIColorMonochrome) |
| `FocusBloxMac/FocusBloxMacApp.swift` (L36, L82-84, L96-97) | `idleImage` Property + Verwendung in `setup()` und `updateIcon()` |
| `FocusBloxMac/MenuBarView.swift` (L240) | Header verwendet ebenfalls `makeMenuBarIcon` für Popover-Header |
| `FocusBloxMacTests/MenuBarIdleIconTests.swift` | 2 existierende Tests: Größe + isTemplate-Check |
| `FocusBloxMac/Assets.xcassets/AppIcon.appiconset/` | App-Icon: Konzentrische Kreise (blau/weiß) auf hellblauem Hintergrund |

## Aktueller Ansatz (Problem)
1. `NSApp.applicationIconImage` wird geladen (512x512 oder ähnlich)
2. Innere 60% gecroppt (um Rounded-Rect-Hintergrund zu entfernen)
3. Kreisförmige Maske angewendet
4. `CIColorMonochrome`-Filter mit grauer Farbe → ergibt matschiges Grau

## Gewünschter Ansatz (Lösung)
- Konzentrische Kreise **programmatisch zeichnen** (kein Bitmap-Filter)
- Als **Template-Image** (`isTemplate = true`) → passt sich an Dark/Light Mode an
- Alpha-Abstufungen für Tiefeneffekt (wie iOS Monochrome-Rendering)
- Kreise: Äußerer Ring, mittlerer Ring, innerer Punkt — entsprechend dem App-Icon-Design

## Existing Patterns
- `makeMenuBarIcon` ist `static` → wird auch von `MenuBarView` Header aufgerufen
- `idleImage` wird einmal in `setup()` erstellt und gecacht
- Bestehende Tests prüfen `size` und `isTemplate` — **ACHTUNG:** Test `test_makeMenuBarIcon_isNotTemplate` muss invertiert werden, da neues Icon Template sein soll

## Dependencies
- **Upstream:** `NSApp.applicationIconImage` (wird aktuell als Quelle genutzt, nach Fix nicht mehr nötig)
- **Downstream:** `MenuBarView.header` (L240) nutzt `makeMenuBarIcon` für Popover-Anzeige — dort soll es weiterhin sichtbar bleiben (evtl. separater Aufruf mit Farbe?)

## Risks & Considerations
1. **MenuBarView Header (L240) + QuickCapturePanel (L145):** Beide nutzen `makeMenuBarIcon` — Template-Image erscheint dort als Silhouette. Lösung: Separate Funktion oder direkt App-Icon verwenden.
2. **Test-Anpassung:** `test_makeMenuBarIcon_isNotTemplate` muss invertiert werden (`isTemplate = true`)
3. **Alpha-Abstufungen:** Template-Images verwenden den Alpha-Kanal — Design muss bei 18x18px gut aussehen
4. **Retina:** Bei 18pt werden 36px @2x gerendert — Kreise müssen bei beiden Auflösungen scharf sein

## Analysis

### Type
Feature (visuelle Verbesserung)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | `makeMenuBarIcon` komplett neu: programmatische Kreise statt Bitmap-Filter (-33/+20 LoC) |
| `FocusBloxMac/MenuBarView.swift` | MODIFY | Header-Icon: App-Icon direkt nutzen statt `makeMenuBarIcon` (~3 LoC) |
| `FocusBloxMac/QuickCapturePanel.swift` | MODIFY | Header-Icon: App-Icon direkt nutzen statt `makeMenuBarIcon` (~3 LoC) |
| `FocusBloxMacTests/MenuBarIdleIconTests.swift` | MODIFY | Tests anpassen: neue Signatur, `isTemplate = true` (~15 LoC) |

### Scope Assessment
- Files: 4
- Estimated LoC: ~+40/-35
- Risk Level: LOW

### Technical Approach
1. **`makeMenuBarIcon(size:)`** — neue Signatur ohne `from:` Parameter (kein Bitmap-Input mehr nötig)
2. **Gestrokte Ringe** mit `NSBezierPath.stroke()` statt gefüllte Scheiben — erzeugt sichtbare Lücken zwischen Ringen wie im App-Icon
3. Drei Elemente: Äußerer Ring (Alpha 0.55, stroke), Mittlerer Ring (Alpha 0.75, stroke), Innerer Kern (Alpha 1.0, fill)
4. `ringWidth = maxRadius * 0.18` für proportionale Ringbreite
5. `isTemplate = true` setzen → System passt an Dark/Light Mode an
6. **MenuBarView + QuickCapturePanel:** Header-Icons auf `NSApp.applicationIconImage` umstellen (farbiges App-Icon, kein Template)

### Iteration 2: Ringe statt Scheiben
Erste Implementation nutzte gefüllte Scheiben (`fill()`) mit Alpha-Overlay → Ringe verschmolzen ohne sichtbare Trennung. Henning-Feedback: "Da fehlt die markante schwarze Linie zwischen den Ringen."
Fix: `stroke()` statt `fill()` → transparente Lücken zwischen Ringen.

### Dependencies
- Upstream: AppKit (NSImage, NSBezierPath) — bereits importiert
- Downstream: MenuBarView Header, QuickCapturePanel Header — werden entkoppelt

### Open Questions
- [x] Sollen Header-Icons in Popover/QuickCapture auch das neue Icon zeigen? → Nein, dort direkt App-Icon (farbig) verwenden
