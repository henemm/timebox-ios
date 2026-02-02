# Floating Tab Bar Redesign

**Status:** Spec zur Genehmigung
**Ticket:** 4 von 4 (Futuristic Spatial Style Redesign)
**Erstellt:** 2026-01-28

---

## Zusammenfassung

Ersetzt die Standard-TabView durch eine custom Floating Tab Bar mit Glass-Effekt. Die Tab Bar schwebt über dem Content und hat abgerundete Ecken mit Glow-Effekt für den aktiven Tab.

---

## Anforderungen

### 1. Custom Tab Bar Component

Neue `FloatingTabBar` View:
- Horizontales Layout mit 5 Tab-Buttons
- Glass-Material Hintergrund (`.ultraThinMaterial`)
- `cardCornerRadius` für abgerundete Ecken
- Positioniert am unteren Bildschirmrand mit Abstand

### 2. Tab Button Styling

Jeder Tab-Button:
- SF Symbol Icon (gleiche wie bisher)
- Label-Text darunter
- Aktiver Tab: `glowCyan` Farbe + `.glowEffect()`
- Inaktive Tabs: `secondaryText` Farbe

### 3. Layout

```
┌─────────────────────────────────────┐
│                                     │
│           Content Area              │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │  📋   📊   ↕️   🎯   🔄  │    │  ← Floating Tab Bar
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### 4. Animation

- Tab-Wechsel mit `.spring()` Animation
- Subtiler Scale-Effekt beim Tap

---

## Dateien

| Datei | Aktion |
|-------|--------|
| `Sources/Views/MainTabView.swift` | Modifizieren |

**Geschätzter Aufwand:** ~80 LoC

---

## Tests

### UI Tests

Bestehende Tab-Navigation Tests müssen weiterhin grün sein.
Keine neuen Tests nötig - Funktionalität bleibt gleich.

---

## Akzeptanzkriterien

- [x] Floating Tab Bar mit Glass-Material
- [x] Aktiver Tab mit Glow-Effekt
- [x] Alle 5 Tabs funktionieren
- [x] Spring-Animation bei Tab-Wechsel
- [x] Bestehende UI Tests grün
- [x] Build erfolgreich

---

## Abhängigkeiten

- **Ticket 1-3:** Design-System, BacklogRow, NextUp (abgeschlossen)

---

## Risiken

- **Mittel:** Custom TabBar erfordert manuelle State-Verwaltung
- **Mitigation:** Einfache @State Variable für selectedTab
