---
entity_id: focusblox-rebrand
type: feature
created: 2026-01-23
status: draft
workflow: focusblox-rebrand
---

# FocusBlox Rebrand (Vollständig)

- [ ] Approved for implementation

## Purpose

Vollständige Umbenennung der App von "TimeBox" zu "FocusBlox" inkl. Verzeichnisse, Xcode-Projekt, Targets, Swift-Code und neuem iOS 26 Liquid Glass App-Icon. Der neue Name passt besser zur Kernfunktion (Fokus-Blöcke) und das Icon visualisiert "The Glowing Gap".

## Scope

**Risk Level:** MEDIUM (viele Dateien, aber systematisch)

### Phase 1: Verzeichnisse & Projekt umbenennen

| Von | Nach |
|-----|------|
| `TimeBox/` | `FocusBlox/` |
| `TimeBox/TimeBox/` | `FocusBlox/FocusBlox/` |
| `TimeBox/TimeBoxCore/` | `FocusBlox/FocusBloxCore/` |
| `TimeBox/TimeBoxTests/` | `FocusBlox/FocusBloxTests/` |
| `TimeBox/TimeBoxUITests/` | `FocusBlox/FocusBloxUITests/` |
| `TimeBox/TimeBoxWidgets/` | `FocusBlox/FocusBloxWidgets/` |
| `TimeBox/TimeBoxCoreTests/` | `FocusBlox/FocusBloxCoreTests/` |
| `TimeBox.xcodeproj` | `FocusBlox.xcodeproj` |

### Phase 2: Swift Structs/Classes umbenennen

| Von | Nach | Datei |
|-----|------|-------|
| `TimeBoxApp` | `FocusBloxApp` | `FocusBloxApp.swift` |
| `TimeBoxShortcuts` | `FocusBloxShortcuts` | `FocusBloxShortcuts.swift` |
| `TimeBoxWidgetsBundle` | `FocusBloxWidgetsBundle` | `FocusBloxWidgetsBundle.swift` |

### Phase 3: Info.plist & Strings

```xml
<key>CFBundleDisplayName</key>
<string>FocusBlox</string>

<key>NSRemindersUsageDescription</key>
<string>FocusBlox benoetigt Zugriff auf deine Erinnerungen...</string>

<key>NSCalendarsUsageDescription</key>
<string>FocusBlox benoetigt Zugriff auf deinen Kalender...</string>

<key>UTTypeDescription</key>
<string>FocusBlox Plan Item</string>

<!-- Neues URL-Scheme parallel zu bestehendem -->
<key>CFBundleURLSchemes</key>
<array>
    <string>focusblox</string>
    <string>timebox</string>  <!-- Backwards compatibility -->
</array>
```

### Phase 4: Icon (iOS 26 Liquid Glass)

| Datei | Beschreibung |
|-------|-------------|
| `FocusBlox/Sources/Views/FocusBloxIconLayers.swift` | SwiftUI Layer-Views |
| `FocusBlox/Resources/Assets.xcassets/AppIcon.solidimagestack/` | Liquid Glass Icon |

### Phase 5: Dokumentation

| Datei | Änderung |
|-------|----------|
| `CLAUDE.md` | Pfade aktualisieren |
| `docs/**/*.md` | "TimeBox" → "FocusBlox" in relevanten Stellen |

## Was NICHT geändert wird

| Element | Bleibt | Grund |
|---------|--------|-------|
| **Bundle-ID** | `com.henning.timebox` | CloudKit, Keychain, App Store |
| **CloudKit Container** | `iCloud.com.henning.timebox` | Datenverlust vermeiden |
| **UTTypeIdentifier** | `com.henning.timebox.planitem` | Backwards compatibility |

## Implementation Details

### Git-Strategie

```bash
# Verzeichnisse umbenennen (Git tracked renames)
git mv TimeBox FocusBlox

# Xcode-Projekt umbenennen
git mv FocusBlox/TimeBox.xcodeproj FocusBlox/FocusBlox.xcodeproj

# Unterverzeichnisse
git mv FocusBlox/TimeBoxCore FocusBlox/FocusBloxCore
git mv FocusBlox/TimeBoxTests FocusBlox/FocusBloxTests
# etc.
```

### project.pbxproj Änderungen

Alle Referenzen aktualisieren:
- Product names: `TimeBox.app` → `FocusBlox.app`
- Target names: `TimeBox` → `FocusBlox`
- Test hosts: `TimeBox.app/TimeBox` → `FocusBlox.app/FocusBlox`
- Framework names: `TimeBoxCore.framework` → `FocusBloxCore.framework`

### Icon Layer Views (SwiftUI)

```swift
// FocusBloxIconLayers.swift

struct FocusBloxBackground: View { ... }
struct FocusBloxMidground: View { ... }
struct FocusBloxForeground: View { ... }
struct FocusWave: Shape { ... }
```

## Design-Details (Icon)

### Farben
| Element | Color |
|---------|-------|
| Background | `rgb(31, 31, 36)` / `#1F1F24` |
| Termin-Blöcke | `white.opacity(0.05)` |
| Focus Block Start | `rgb(0, 179, 204)` / `#00B3CC` |
| Focus Block End | `rgb(0, 102, 128)` / `#006680` |
| Glow | `rgb(0, 204, 230).opacity(0.4)` |
| Wave | White gradient |

### Layer-Struktur für Icon Composer
| Layer | Inhalt | Liquid Glass Property |
|-------|--------|----------------------|
| Background | Dunkler BG + matte Blöcke | Translucency |
| Midground | Leuchtender Teal-Block | Specular (Glass) |
| Foreground | FocusWave (Sinuswelle) | Minimal Blur |

## Test Plan

### Unit Tests
- [ ] `testAppStructExists`: `FocusBloxApp` struct existiert und ist `@main`
- [ ] `testShortcutsProviderExists`: `FocusBloxShortcuts` implementiert `AppShortcutsProvider`

### UI Tests (TDD RED)
- [ ] `testAppDisplaysCorrectName`: App-Name zeigt "FocusBlox"
- [ ] `testBothURLSchemesWork`: `focusblox://` und `timebox://` funktionieren

### Build Verification
- [ ] `xcodebuild build` erfolgreich mit neuem Projekt
- [ ] Alle Unit Tests grün
- [ ] Alle UI Tests grün

## Acceptance Criteria

- [ ] Verzeichnis heißt `FocusBlox/`
- [ ] Xcode-Projekt heißt `FocusBlox.xcodeproj`
- [ ] App heißt "FocusBlox" auf Home Screen
- [ ] Alle Targets heißen "FocusBlox*"
- [ ] Swift Structs heißen "FocusBlox*"
- [ ] Neues Liquid Glass Icon wird angezeigt
- [ ] URL-Scheme `focusblox://` funktioniert
- [ ] URL-Scheme `timebox://` funktioniert weiterhin (Backwards Compat)
- [ ] Bundle-ID ist unverändert `com.henning.timebox`
- [ ] Build & alle Tests erfolgreich

## Rollback-Plan

Falls Probleme auftreten:
```bash
git reset --hard HEAD~1
```

## Changelog

- 2026-01-23: Initial spec created
- 2026-01-23: Erweitert um vollständige Umbenennung (Verzeichnisse, Projekt, Code)
