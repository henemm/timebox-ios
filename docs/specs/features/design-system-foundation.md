# Design-System Foundation

**Status:** Spec zur Genehmigung
**Ticket:** 1 von 4 (Futuristic Spatial Style Redesign)
**Erstellt:** 2026-01-28

---

## Zusammenfassung

Erstelle eine zentrale `DesignSystem.swift` Datei mit wiederverwendbaren Design-Tokens für das "Futuristic Spatial Style" UI-Redesign. Das System unterstützt **Light und Dark Mode**.

---

## Anforderungen

### 1. Farben (Adaptive)

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| `appBackground` | `#050510` (Deep Space) | `systemGroupedBackground` |
| `glassSurface` | `.ultraThinMaterial` + 5% weißer Tint | `.ultraThinMaterial` |
| `accentGlow` | Cyan/Blue Gradient | Cyan/Blue (gedämpfter) |
| `primaryText` | `.white` | `.primary` |
| `secondaryText` | `.white.opacity(0.7)` | `.secondary` |
| `goldAccent` | `#FFD700` (Gold) | `#D4A800` (dunkler) |

### 2. Spacing & Formen

| Token | Wert |
|-------|------|
| `cardCornerRadius` | 24 (Continuous) |
| `cardPadding` | 20 |
| `listRowSpacing` | 16 |
| `iconSize` | 28 |

### 3. Typografie

| Token | Wert |
|-------|------|
| `titleFont` | `.headline.bold().design(.rounded)` |
| `bodyFont` | `.body.design(.rounded)` |
| `captionFont` | `.caption.design(.rounded)` |
| `monospacedNumbers` | `.monospacedDigit()` |

### 4. View Modifiers

| Modifier | Beschreibung |
|----------|--------------|
| `.glassCard()` | Wendet Glass-Surface + Corner Radius an |
| `.glowEffect(color:)` | Fügt Neon-Glow Shadow hinzu |
| `.appBackground()` | Setzt den adaptiven Hintergrund |

---

## Dateien

| Datei | Aktion |
|-------|--------|
| `Sources/Views/DesignSystem.swift` | NEU erstellen |

**Geschätzter Aufwand:** ~80 LoC

---

## Tests

### Unit Tests (FocusBloxTests/DesignSystemTests.swift)

```swift
// Test: Farben existieren und sind korrekt definiert
func testAppBackgroundColorExists()
func testGoldAccentColorExists()
func testSpacingConstantsExist()
func testCornerRadiusConstantsExist()
```

### UI Tests

Keine UI Tests erforderlich - reine Definitionen ohne UI-Verhalten.

---

## Akzeptanzkriterien

- [x] `DesignSystem.swift` erstellt mit allen definierten Tokens
- [x] Farben sind adaptive (Light/Dark Mode)
- [x] View Modifiers funktionieren
- [x] Unit Tests bestanden (8/8)
- [x] Build erfolgreich

---

## Abhängigkeiten

Keine - dies ist die Basis für alle folgenden Redesign-Tickets.

---

## Risiken

- **Gering:** Könnte bestehende Views beeinflussen, die bereits `.ultraThinMaterial` nutzen
- **Mitigation:** Design-System wird nur in neuen/überarbeiteten Views verwendet
