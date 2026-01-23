# Context: FocusBlox Rebrand

## Request Summary
Umbenennung der App von "TimeBox" zu "FocusBlox" inkl. neuem App-Icon Design.

## Scope

### Was enthalten ist:
1. **App-Name ändern** - TimeBox → FocusBlox
2. **Neues App-Icon** - "The Glowing Gap" Design mit FocusWave

### Was NICHT enthalten ist (zu riskant für einen Sprint):
- Xcode-Projekt/Verzeichnisse umbenennen (würde Codebase destabilisieren)
- Bundle-Identifier ändern (würde CloudKit/Keychain-Daten verlieren)
- URL-Schemes ändern (würde Deep-Links brechen)

## Related Files

### Icon-relevante Dateien
| File | Relevance |
|------|-----------|
| `TimeBox/Resources/Assets.xcassets/AppIcon.appiconset/` | Hier kommt das neue Icon |
| `TimeBox/TimeBoxWidgets/Assets.xcassets/AppIcon.appiconset/` | Widget-Icon |

### Display-Name Dateien
| File | Relevance |
|------|-----------|
| `TimeBox/Resources/Info.plist` | CFBundleDisplayName setzen |
| `TimeBox/TimeBoxWidgets/Info.plist` | Widget Extension Name |

### User-facing Strings (Optional)
| File | Relevance |
|------|-----------|
| `TimeBox/Resources/Info.plist:35,37` | "TimeBox benötigt..." → "FocusBlox benötigt..." |

## Neue Dateien zu erstellen

| File | Purpose |
|------|---------|
| `TimeBox/Sources/Views/FocusBloxIcon.swift` | SwiftUI Icon-Generator View |
| `TimeBox/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | 1024x1024 exportiertes Icon |

## Design-Details

### Design-Philosophie
"The Glowing Gap" - Der leuchtende Block zwischen den dunklen Terminen

### Farben
- **Hintergrund:** Dark Matter (`Color(red: 0.12, green: 0.12, blue: 0.14)`)
- **Focus Block:** Electric Teal Gradient (`#00B3CC` → `#006680`)
- **Glow:** `Color(red: 0.0, green: 0.8, blue: 0.9).opacity(0.4)`

### Komponenten
1. Oberer Block (Termin davor) - matt & dunkel
2. **Focus Block** (die leuchtende Lücke) - mit FocusWave Animation
3. Unterer Block (Termin danach) - matt & dunkel

## Existing Patterns

### Asset-Handling
- Icons werden als 1024x1024 PNG in `AppIcon.appiconset` gespeichert
- Xcode generiert automatisch alle benötigten Größen

### App-Name in SwiftUI
- `TimeBoxApp.swift` definiert `@main struct TimeBoxApp: App`
- Der Display-Name kommt aus `Info.plist` CFBundleDisplayName

## Risks & Considerations

### Low Risk (empfohlen)
- Display-Name ändern (nur Info.plist)
- Neues Icon erstellen und exportieren
- User-facing Strings aktualisieren

### High Risk (NICHT empfohlen)
- Xcode-Projekt umbenennen → Git-History, Xcode-Bugs, Referenzen kaputt
- Bundle-ID ändern → CloudKit-Daten weg, App Store neue App
- URL-Scheme ändern → Siri Shortcuts, Deep Links brechen

## Empfehlung

**Minimaler Scope für sauberes Rebrand:**
1. `CFBundleDisplayName` auf "FocusBlox" setzen in Info.plist
2. Neues App-Icon erstellen (FocusBloxIcon.swift → PNG Export)
3. User-facing Strings optional anpassen

Der technische Projektname bleibt "TimeBox" (intern) - nur der User-sichtbare Name wird "FocusBlox".

## Dependencies

- **Upstream:** SwiftUI, CoreGraphics (für Icon-Rendering)
- **Downstream:** App Store Connect (neuer Name/Icon beim nächsten Release)

## Siri/Voice Trigger
- "FocusBlox" ist phonetisch eindeutig
- Kein Konflikt mit bestehenden Siri-Befehlen erwartet

---

## Analysis

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `TimeBox/Resources/Info.plist` | MODIFY | CFBundleDisplayName + User-facing Strings |
| `TimeBox/Sources/Views/FocusBloxIconLayers.swift` | CREATE | SwiftUI Layer-Views für Icon Composer |
| `TimeBox/Resources/Assets.xcassets/AppIcon.appiconset/` | REPLACE | Neues Liquid Glass Icon (.icon Format) |

### Scope Assessment
- **Files:** 2
- **Estimated LoC:** +4/-0 (Info.plist Einträge)
- **Risk Level:** LOW

### Technical Approach

1. **Info.plist anpassen:**
   - `CFBundleDisplayName` Key hinzufügen mit Wert "FocusBlox"
   - User-facing Strings aktualisieren ("TimeBox benötigt" → "FocusBlox benötigt")

2. **Icon erstellen (iOS 26 Liquid Glass):**
   - SwiftUI Layer-Views erstellen (Background, Midground, Foreground)
   - Layer als 1024x1024 PNG exportieren
   - In **Icon Composer** importieren (Xcode → Open Developer Tool → Icon Composer)
   - Liquid Glass Properties konfigurieren
   - Als `.icon` File speichern
   - In Asset Catalog integrieren

### Icon Layer Struktur

| Layer | SwiftUI View | Inhalt |
|-------|--------------|--------|
| **Background** | `FocusBloxBackground` | Dunkler Hintergrund + matte Terminblöcke |
| **Midground** | `FocusBloxMidground` | Leuchtender Teal Focus-Block |
| **Foreground** | `FocusBloxForeground` | FocusWave (Sinuswelle) |

### Icon Composer Workflow
1. `Xcode → Open Developer Tool → Icon Composer`
2. Neues Icon erstellen
3. Layer importieren (PNG 1024x1024 mit Transparenz)
4. Liquid Glass Properties:
   - Background: Translucency aktivieren
   - Midground: Specular für Glass-Effekt
   - Foreground: Blur minimal für Schärfe
5. Als `AppIcon.icon` exportieren
6. In `Assets.xcassets` integrieren

### Open Questions
- [x] Soll das Widget-Icon auch aktualisiert werden? → JA (gleiche Optik)
- [x] Sollen alle User-facing Strings geändert werden? → JA

---
*Context generiert am 2026-01-23*
*Analyse ergänzt am 2026-01-23*
