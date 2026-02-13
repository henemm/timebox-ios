# Context: BACKLOG-006 Color Hex Extension Deduplizierung

## Request Summary
Identische `Color.init(hex:)` Extension in iOS SettingsView und macOS MacSettingsView nach `Sources/Extensions/Color+Hex.swift` extrahieren.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/SettingsView.swift:229-246` | Enthalt duplizierte Color hex Extension |
| `FocusBloxMac/MacSettingsView.swift:372-390` | Enthalt duplizierte Color hex Extension |
| `Sources/Extensions/Color+Hex.swift` | NEU - Ziel fuer shared Extension |

## Nutzung von `Color(hex:)`
| File | Zeile | Nutzung |
|------|-------|---------|
| `Sources/Views/SettingsView.swift:215` | `Color(hex: hex)` in ReminderListRow |
| `FocusBloxMac/MacSettingsView.swift:358` | `Color(hex: hex)` in MacReminderListRow |

## Existing Patterns
- `Sources/Helpers/` existiert fuer Helper-Code
- `Sources/Models/` fuer Datenmodelle
- Kein `Sources/Extensions/` Verzeichnis bisher - muss neu angelegt werden

## Dependencies
- Upstream: SwiftUI `Color`, Foundation `Scanner`, `CharacterSet`
- Downstream: `SettingsView.swift` (iOS), `MacSettingsView.swift` (macOS)

## Risks & Considerations
- Sehr niedriges Risiko: reine Code-Verschiebung ohne Logik-Aenderung
- Extension muss fuer beide Targets sichtbar sein (Sources/ ist shared)
- Xcode-Projekt muss die neue Datei kennen (Datei muss in Sources/ Gruppe liegen)

## Analysis

### Type
Refactoring (Deduplizierung)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Extensions/Color+Hex.swift` | CREATE | Shared Color hex Extension |
| `Sources/Views/SettingsView.swift` | MODIFY | Extension entfernen (Zeilen 227-246) |
| `FocusBloxMac/MacSettingsView.swift` | MODIFY | Extension entfernen (Zeilen 370-390) |

### Scope Assessment
- Files: 3 (1 CREATE, 2 MODIFY)
- Estimated LoC: +18 / -38 (netto -20)
- Risk Level: LOW

### Technical Approach
1. `Sources/Extensions/Color+Hex.swift` anlegen mit der Extension
2. Extension aus `SettingsView.swift` entfernen
3. Extension aus `MacSettingsView.swift` entfernen
4. Build testen - beide Targets muessen kompilieren

### Verifizierung
- Code ist 1:1 identisch in beiden Dateien (verglichen)
- Keine zusaetzlichen Imports noetig (SwiftUI + Foundation sind bereits vorhanden)
- `Sources/` ist shared - beide Targets sehen die neue Datei
