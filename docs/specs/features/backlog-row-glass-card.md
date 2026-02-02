# BacklogRow Glass Card Redesign

**Status:** Spec zur Genehmigung
**Ticket:** 2 von 4 (Futuristic Spatial Style Redesign)
**Erstellt:** 2026-01-28

---

## Zusammenfassung

Überarbeitet `BacklogRow.swift` mit dem neuen Design-System. Die Rows erhalten Glass Card Styling, verbesserte Typografie und nutzen die zentralen Design-Tokens.

---

## Anforderungen

### 1. Glass Card Container

Die gesamte Row wird in einen Glass Card Container gepackt:
- `.glassCard()` Modifier anwenden
- `DesignSystem.Spacing.cardPadding` für inneren Abstand
- Bestehende `.padding(.vertical, 8)` ersetzen

### 2. Typografie-Tokens

| Element | Aktuell | Neu |
|---------|---------|-----|
| Title | `.font(.body)` | `DesignSystem.Typography.bodyFont` |
| Category Label | `.font(.caption)` | `DesignSystem.Typography.captionFont` |
| Tags | `.font(.caption2)` | `DesignSystem.Typography.captionFont` |
| Due Date | `.font(.caption2)` | `DesignSystem.Typography.captionFont` |

### 3. Farb-Tokens

| Element | Aktuell | Neu |
|---------|---------|-----|
| Title Text | `.foregroundStyle(.primary)` | `DesignSystem.Colors.primaryText` |
| Category Badge BG | `Color.secondary.opacity(0.15)` | `.ultraThinMaterial` |
| Tag Chips BG | `Color.accentColor.opacity(0.15)` | Behalten (Akzentfarbe) |
| TBD Badge BG | `Color.secondary.opacity(0.2)` | `DesignSystem.Colors.goldAccent.opacity(0.2)` |

### 4. Icon-Größe

- Importance Badge Icon: Größe `DesignSystem.Spacing.iconSize` (28pt)

---

## Dateien

| Datei | Aktion |
|-------|--------|
| `Sources/Views/BacklogRow.swift` | Modifizieren |

**Geschätzter Aufwand:** ~30 LoC Änderungen

---

## Tests

### UI Tests (FocusBloxUITests/BacklogRowGlassUITests.swift)

```swift
// Test: Glass Card Styling wird angewendet
func testBacklogRowHasGlassCardStyling()

// Test: Row ist sichtbar und interagierbar
func testBacklogRowElementsExist()

// Test: Importance Badge ist tappbar
func testImportanceBadgeIsTappable()
```

**Hinweis:** Visuelle Tests sind begrenzt - wir testen primär, dass die UI-Elemente existieren und funktionieren.

---

## Akzeptanzkriterien

- [x] BacklogRow verwendet `.glassCard()` Modifier
- [x] Design-System Typography Tokens verwendet
- [x] Design-System Color Tokens verwendet
- [x] Alle bestehenden UI Tests weiterhin grün (3/3)
- [x] Build erfolgreich

---

## Abhängigkeiten

- **Ticket 1:** Design-System Foundation (abgeschlossen)

---

## Risiken

- **Gering:** Visuelle Regression möglich - manuelle Sichtprüfung empfohlen
- **Mitigation:** Keine funktionalen Änderungen, nur Styling
