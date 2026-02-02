# NextUp Section Neon-Glow Redesign

**Status:** Spec zur Genehmigung
**Ticket:** 3 von 4 (Futuristic Spatial Style Redesign)
**Erstellt:** 2026-01-28

---

## Zusammenfassung

Überarbeitet `NextUpSection.swift` mit Neon-Glow Effekten. Der Header erhält einen Gradient-Text, der erste Task bekommt einen Glow-Effekt um ihn als "aktiven" Task hervorzuheben.

---

## Anforderungen

### 1. Header mit Gradient

Der "Next Up" Header-Text erhält den `accentGlow` Gradient:
- Icon: Behalten, aber mit Glow-Effekt
- Text: Gradient-Foreground mit `DesignSystem.Colors.accentGlow`
- Counter-Badge: `.ultraThinMaterial` statt `.blue.opacity(0.15)`

### 2. Section Container

Der gesamte Container erhält Glass-Styling:
- Hintergrund: `.ultraThinMaterial` statt `.blue.opacity(0.05)`
- Border: `.glowEffect()` statt einfache Stroke
- Corner Radius: `DesignSystem.Spacing.cardCornerRadius` (24)

### 3. Aktiver Task (erster in der Liste)

Der erste Task in der Next Up Liste bekommt einen subtilen Glow:
- `.glowEffect(color: DesignSystem.Colors.glowCyan, radius: 8)`
- Nur für den ersten Task, nicht für alle

### 4. Task Rows

Alle NextUpRow-Elemente nutzen Design-System Tokens:
- Typography: `captionFont`, `bodyFont`
- Colors: `primaryText`, `secondaryText`
- Spacing: Design-System Konstanten

---

## Dateien

| Datei | Aktion |
|-------|--------|
| `Sources/Views/NextUpSection.swift` | Modifizieren |

**Geschätzter Aufwand:** ~40 LoC Änderungen

---

## Tests

### UI Tests

Keine neuen UI Tests nötig - rein visuelle Änderungen.
Bestehende Tests müssen weiterhin grün sein.

---

## Akzeptanzkriterien

- [x] Header mit Cyan Glow-Color
- [x] Section mit Glass-Material Hintergrund
- [x] Erster Task hat Glow-Effekt (isActive)
- [x] Design-System Tokens verwendet
- [x] Bestehende UI Tests grün (14/14 inkl. 5 NextUp-spezifische)
- [x] Build erfolgreich

---

## Abhängigkeiten

- **Ticket 1:** Design-System Foundation (abgeschlossen)
- **Ticket 2:** BacklogRow Glass Card (abgeschlossen)
