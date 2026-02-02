# BacklogRow Redesign

**Status:** In Progress
**Modus:** AENDERUNG (bestehendes BacklogRow ueberarbeiten)
**Erstellt:** 2026-01-29

---

## Zusammenfassung

Komplettes Redesign der BacklogRow mit neuem Layout:
- Wichtigkeit als Badge in Metadaten-Zeile (KEIN grosser Button links)
- Dringlichkeit als flame-Badge wenn urgent
- 2 Buttons rechts vertikal (Next Up + Menu)
- TBD Badge entfernt (nur kursiver Titel)

---

## Ziel-Layout

```
+--------------------------------------------------+--------+
| Titel (fett, max 2 Zeilen, kursiv wenn TBD)      |   ^    |
| [!!] [flame] [wrench Pflege] [Tag] [+2] [15m] [Mo]|  ...   |
+--------------------------------------------------+--------+
```

**Spalten:**
1. **Linke Spalte (flex):** Titel + Metadaten-Zeile
2. **Rechte Spalte (44pt breit):** 2 Buttons vertikal gestapelt

---

## Aktueller Zustand (Delta)

| Bereich | Aktuell | Neu |
|---------|---------|-----|
| Importance Button | Grosser Button links (`circle.fill`) | Badge in Metadata-Zeile (`exclamationmark.X`) |
| Dringlichkeit | Nicht angezeigt | `flame.fill` Badge wenn urgent |
| Rechte Spalte | Nur ellipsis Menu | 2 Buttons: arrow.up.circle + ellipsis |
| "Next Up" Action | Im Menu versteckt | Eigener Button (immer sichtbar) |
| TBD Badge | Separates Badge in Metadata | ENTFERNT (nur kursiver Titel) |
| Metadata-Reihenfolge | Kategorie, TBD, Tags, Due, Duration | Wichtigkeit, Dringlichkeit, Kategorie, Tags, Duration, Due |

---

## Anforderungen

### 1. Layout-Struktur

```swift
HStack(spacing: 12) {
    // Linke Spalte: Content
    VStack(alignment: .leading, spacing: 4) {
        // Titel (fett, max 2 Zeilen, kursiv wenn TBD)
        Text(item.title)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .lineLimit(2)
            .italic(item.isTbd)

        // Metadaten-Zeile
        metadataRow
    }

    Spacer(minLength: 8)

    // Rechte Spalte: 2 Buttons vertikal
    VStack(spacing: 0) {
        nextUpButton   // arrow.up.circle
        menuButton     // ellipsis
    }
    .frame(width: 44)
}
```

### 2. Wichtigkeit Badge (SF Symbols - Variante C)

| Importance | SF Symbol | Farbe |
|------------|-----------|-------|
| 3 (Hoch) | `exclamationmark.3` | Rot |
| 2 (Mittel) | `exclamationmark.2` | Gelb |
| 1 (Niedrig) | `exclamationmark` | Blau |
| nil | Kein Badge | - |

**Accessibility Identifier:** `importanceBadge_{item.id}`

### 3. Dringlichkeits Badge

| Urgency | Anzeige |
|---------|---------|
| "urgent" | `flame.fill` orange |
| andere / nil | Nichts anzeigen |

**Accessibility Identifier:** `urgencyBadge_{item.id}`

### 4. Rechte Spalte (44x44pt Touch-Targets)

**Next Up Button:**
- Icon: `arrow.up.circle`
- Aktion: `onAddToNextUp?()`
- Versteckt wenn `item.isNextUp == true`
- **Accessibility Identifier:** `nextUpButton_{item.id}`

**Menu Button:**
- Icon: `ellipsis`
- Enthaelt: Bearbeiten, Loeschen
- **Accessibility Identifier:** `actionsMenu_{item.id}`

### 5. Metadaten-Zeile (Reihenfolge)

1. Wichtigkeit Badge (SF Symbol)
2. Dringlichkeit Badge (flame wenn urgent)
3. Kategorie Badge (Icon + Label)
4. Tags (max 2, dann "+N")
5. Duration Badge
6. Due Date Badge

**Entfernt:** TBD Badge (nur kursiver Titel bleibt)

### 6. Touchbare Elemente (Chips)

**Alle touchbaren Elemente werden als Chips dargestellt:**

| Element | Touchbar | Aktion bei Tap |
|---------|----------|----------------|
| Wichtigkeit Badge | ✅ Ja | Inline-Picker öffnen |
| Dringlichkeit Badge | ✅ Ja | Toggle urgent/not_urgent |
| Kategorie Badge | ✅ Ja | Inline-Picker öffnen |
| Duration Badge | ✅ Ja | Inline-Picker öffnen |
| Due Date Badge | ✅ Ja | Date-Picker öffnen |
| Tags | ❌ Nein | Nur Anzeige |

**Chip-Styling (einheitlich für alle touchbaren Elemente):**
- Hintergrund: `.ultraThinMaterial` oder `Color.secondary.opacity(0.15)`
- Padding: `.horizontal(8)`, `.vertical(4)`
- Corner Radius: 8pt (Capsule oder RoundedRectangle)
- Mindesthöhe: 28pt (für Touch-Target)
- Bei Tap: Subtle Scale-Animation (0.95)

**Touch-Target Anforderung:**
- Minimum 44x28pt pro Chip (Apple HIG)
- Chips haben ausreichend Abstand (mind. 4pt)

### 7. Visual Style

- Glass Card Background (`.ultraThinMaterial`)
- Abgerundete Ecken (16pt)
- NUR SF Symbols, KEINE Emojis

---

## Dateien

| Datei | Aktion |
|-------|--------|
| `Sources/Views/BacklogRow.swift` | Modifizieren |

**Geschaetzter Aufwand:** ~100-150 LoC Aenderungen (innerhalb Limit)

---

## UI Tests (TDD RED)

Neue Tests in `FocusBloxUITests/BacklogRowRedesignUITests.swift`:

### Test 1: Wichtigkeit Badge mit exclamationmark Symbol
```swift
func testImportanceBadgeWithExclamationmark()
// Prueft: importanceBadge_* existiert in Metadaten-Zeile
```

### Test 2: Dringlichkeit Badge (flame) wenn urgent
```swift
func testUrgencyBadgeWhenUrgent()
// Prueft: urgencyBadge_* mit flame.fill wenn Task urgent ist
```

### Test 3: Next Up Button sichtbar (eigenstaendig)
```swift
func testNextUpButtonVisible()
// Prueft: nextUpButton_* existiert als eigener Button
```

### Test 4: Next Up Button versteckt wenn isNextUp
```swift
func testNextUpButtonHiddenWhenAlreadyNextUp()
// Prueft: nextUpButton nicht sichtbar fuer Next Up Tasks
```

### Test 5: Kein TBD Badge
```swift
func testNoTbdBadge()
// Prueft: tbdBadge_* existiert NICHT mehr
```

### Test 6: Kursiver Titel bei TBD Tasks
```swift
func testItalicTitleForTbdTasks()
// Prueft: Titel ist kursiv (accessibility trait)
```

### Test 7: Metadaten-Reihenfolge
```swift
func testMetadataOrder()
// Prueft: Badges erscheinen in korrekter Reihenfolge
```

---

## Akzeptanzkriterien

- [ ] Kein Importance Button links (entfernt)
- [ ] Wichtigkeit als Badge in Metadaten-Zeile mit exclamationmark.X
- [ ] Dringlichkeit als flame.fill wenn urgent
- [ ] Next Up Button eigenstaendig sichtbar (nicht im Menu versteckt)
- [ ] Menu nur mit Bearbeiten + Loeschen
- [ ] TBD Badge entfernt
- [ ] Kursiver Titel bei TBD Tasks funktioniert weiterhin
- [ ] Glass Card Styling beibehalten
- [ ] **Alle touchbaren Badges als Chips mit einheitlichem Styling**
- [ ] **Chip-Mindesthöhe 28pt, Touch-Target mind. 44x28pt**
- [ ] **Tap auf Chip öffnet entsprechenden Inline-Picker**
- [ ] Alle neuen UI Tests GRUEN
- [ ] Build erfolgreich

---

## Abhaengigkeiten

- **Design-System:** `DesignSystem.swift` (bereits vorhanden)
- **PlanItem.urgency:** Property existiert bereits (`String?`)

---

## Risiken

- **Gering:** Inline-Edit Section muss angepasst werden (keine Importance-Button-Logik mehr)
- **Mitigation:** onTapGesture bleibt auf Content-Bereich

---

## Genehmigung

- [ ] Product Owner genehmigt
- [ ] Implementation kann starten
