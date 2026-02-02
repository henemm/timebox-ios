# Learnings & Gotchas

Gesammelte Erkenntnisse aus der Entwicklung.

## SwiftUI UI Testing

- `Picker` Labels sind NICHT als `StaticText` zugänglich in XCTest
- Teste Picker-Existenz (`app.buttons["pickerName"]`), nicht einzelne Optionen
- Für Picker-Optionen: Teste indirekt über Ergebnis (z.B. Task erstellen, prüfen ob gespeichert)

## Workflow State

- `.claude/workflow_state.json` wird von ALLEN Claude-Sessions geteilt
- **NIEMALS** fremde Workflows ändern - nur den eigenen aktiven Workflow
- Bei Unsicherheit: Workflow State in Ruhe lassen, nur Roadmap aktualisieren

## macOS App Icons

**Problem:** SwiftUI Icon-Code (`FocusBloxIcon`) existiert, aber App zeigt altes Icon.

**Root Cause:**
- `scripts/render-icon.swift` generierte nur `foreground.png` für iOS Icon Composer
- Die PNG-Dateien in `FocusBloxMac/Assets.xcassets/AppIcon.appiconset/` wurden **nie aktualisiert**
- macOS braucht 10 separate PNG-Dateien (16x16 @1x/@2x bis 512x512 @1x/@2x)

**Lösung:**
1. `render-icon.swift` muss ALLE macOS-Größen generieren
2. Nach Änderungen am Icon-Code: `swift scripts/render-icon.swift` ausführen
3. DerivedData löschen: `rm -rf ~/Library/Developer/Xcode/DerivedData/FocusBlox-*`
4. Icon-Cache löschen: `rm -rf ~/Library/Caches/com.apple.iconservices.store && killall Finder`
5. Clean Build durchführen

**Checkliste bei Icon-Änderungen:**
- [ ] SwiftUI-Code in `FocusBloxIconLayers.swift` ändern
- [ ] AUCH den Code in `scripts/render-icon.swift` synchronisieren (Duplikat!)
- [ ] Script ausführen: `swift scripts/render-icon.swift`
- [ ] Caches löschen + Clean Build

---

Erstellt: 2026-01-23
Aktualisiert: 2026-02-02 (macOS App Icons)
