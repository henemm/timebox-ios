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
- [ ] Verifizieren dass ALLE Icons generiert wurden:
  - `AppIcon.icon/Assets/foreground.png` (iOS Icon Composer)
  - `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (iOS Fallback)
  - `FocusBloxMac/Assets.xcassets/AppIcon.appiconset/icon_*.png` (macOS)
- [ ] Caches löschen + Clean Build

## Xcode Schemes verschwinden

**Problem:** Nach DerivedData-Löschung fehlen Xcode Schemes (z.B. FocusBlox iOS).

**Root Cause:**
- Xcode generiert Schemas automatisch, speichert sie aber NICHT als Dateien
- `xcschememanagement.plist` referenziert `FocusBlox.xcscheme_^#shared#^_`
- Aber der Ordner `xcshareddata/xcschemes/` ist **leer**
- Nach DerivedData-Löschung findet Xcode die Schemas nicht mehr

**Lösung:**
1. Schemas müssen als **Dateien** in `FocusBlox.xcodeproj/xcshareddata/xcschemes/` existieren
2. Nach Erstellung: **Sofort committen** (`git add *.xcscheme && git commit`)

**NIEMALS MACHEN:**
- `rm -rf ~/Library/Developer/Xcode/DerivedData/` ohne vorher Schemas zu sichern
- Davon ausgehen, dass Schemas als Dateien existieren - **immer prüfen!**

**Prüf-Befehl:**
```bash
ls FocusBlox.xcodeproj/xcshareddata/xcschemes/
# Sollte FocusBlox.xcscheme, FocusBloxMac.xcscheme etc. zeigen
```

**Schema manuell erstellen:**
1. Target-ID finden: `grep -E "^\t+[A-F0-9]+ /\* FocusBlox \*/ = \{$" *.pbxproj`
2. Schema-XML erstellen mit korrekter BlueprintIdentifier
3. In `xcshareddata/xcschemes/` speichern

---

## SwiftUI Path in ViewBuilder

**Problem:** `Path` Views in einem `ZStack` mit `.offset()` werden nicht zuverlässig positioniert, da Paths keine intrinsische Größe haben.

**Falscher Ansatz:**
```swift
ZStack {
    Path { path in ... }
        .offset(x: -50, y: -50)  // ❌ Unzuverlässig
    Path { path in ... }
        .offset(x: 50, y: -50)   // ❌ Kann aus dem Bereich verschwinden
}
```

**Korrekter Ansatz - Canvas verwenden:**
```swift
Canvas { context, size in
    let centerX = size.width / 2
    let centerY = size.height / 2

    var path = Path()
    path.move(to: CGPoint(x: centerX - 50, y: centerY))
    // ... Pfad definieren relativ zum Zentrum

    context.stroke(path, with: .color(.white), style: ...)
}
.frame(width: 200, height: 200)  // ✅ Feste Größe definieren
```

**Grund:** `Canvas` gibt volle Kontrolle über Koordinaten und hat eine definierte Größe.

---

Erstellt: 2026-01-23
Aktualisiert: 2026-02-02 (macOS App Icons, SwiftUI Path in ViewBuilder)
