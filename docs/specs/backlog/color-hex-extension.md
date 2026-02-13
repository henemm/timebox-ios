---
entity_id: color_hex_extension
type: refactoring
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [backlog-006, deduplication, cross-platform]
---

# Color+Hex Extension Deduplizierung (BACKLOG-006)

## Approval

- [ ] Approved

## Purpose

Identische `Color.init(hex:)` Extension aus zwei Dateien (iOS SettingsView, macOS MacSettingsView) in eine shared Datei `Sources/Extensions/Color+Hex.swift` extrahieren. Eliminiert Code-Duplikation gemaess Cross-Platform Guideline.

## Source

- **File:** `Sources/Extensions/Color+Hex.swift` (NEU)
- **Identifier:** `extension Color { init(hex: String) }`

### Duplikate (werden entfernt)
- `Sources/Views/SettingsView.swift` Zeilen 227-246
- `FocusBloxMac/MacSettingsView.swift` Zeilen 370-390

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SwiftUI.Color | Framework | Base type being extended |
| Foundation.Scanner | Framework | Hex string parsing |
| Foundation.CharacterSet | Framework | Input sanitization |

## Implementation Details

### Schritt 1: Neue Datei anlegen
Verzeichnis `Sources/Extensions/` erstellen und `Color+Hex.swift` mit der Extension anlegen.

### Schritt 2: Duplikate entfernen
- `SettingsView.swift`: Zeilen 227-246 (MARK + Extension) loeschen
- `MacSettingsView.swift`: Zeilen 370-390 (MARK + Extension) loeschen

### Schritt 3: Build verifizieren
Beide Targets (iOS + macOS) muessen kompilieren.

## Expected Behavior

- **Input:** Hex-String (z.B. "#FF0000" oder "FF0000")
- **Output:** `Color` mit entsprechenden RGB-Werten
- **Side effects:** Keine - reine Code-Verschiebung

## Affected Files

| File | Change | LoC |
|------|--------|-----|
| `Sources/Extensions/Color+Hex.swift` | CREATE | +18 |
| `Sources/Views/SettingsView.swift` | MODIFY | -19 |
| `FocusBloxMac/MacSettingsView.swift` | MODIFY | -19 |

**Scope:** 3 Dateien, netto -20 LoC

## Test Plan

- Build-Validierung: beide Targets kompilieren
- Bestehende Funktionalitaet bleibt unveraendert (reine Verschiebung)

## Known Limitations

- Extension unterstuetzt nur 6-Zeichen Hex-Strings (kein Alpha-Kanal)
- Ungueltige Strings ergeben Grau (128, 128, 128)

## Changelog

- 2026-02-13: Initial spec created
