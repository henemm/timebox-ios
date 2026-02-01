# Context: iOS Duration Chip Scroll Bug

## Request Summary
Wenn der User auf einen Dauer-Chip in der iOS App tippt, springt der Fokus nach oben bzw. scrollt die Liste nach oben.

## Problem-Analyse

### Symptom
- User tippt auf Duration-Chip in BacklogRow
- Liste scrollt nach oben (zum Anfang)
- Erst dann öffnet sich der DurationPicker Sheet

### Root Cause

**Nested ScrollViews:**
1. `BacklogView.listView` verwendet `ScrollView` (vertikal, Zeile 531)
2. `BacklogRow.metadataRow` verwendet `ScrollView(.horizontal)` (Zeile 128)
3. Die Badges (inkl. `durationBadge`) sind Buttons innerhalb des horizontalen ScrollViews

**Problem:**
- Wenn ein Button in einem nested ScrollView getappt wird, kann SwiftUI versuchen:
  1. Den Fokus zu verschieben
  2. Das Parent-ScrollView zu "resetten"
  3. Animations-Konflikte zwischen ScrollView und Sheet-Presentation

### Code-Stellen

| Datei | Zeile | Beschreibung |
|-------|-------|--------------|
| `BacklogView.swift` | 531 | `ScrollView` für List View |
| `BacklogView.swift` | 537 | `onDurationTap: { selectedItemForDuration = item }` |
| `BacklogView.swift` | 238-243 | `.sheet(item: $selectedItemForDuration)` |
| `BacklogRow.swift` | 128 | `ScrollView(.horizontal)` für metadataRow |
| `BacklogRow.swift` | 374-398 | `durationBadge` Button |

### Vermutete Ursachen

1. **ScrollView ID Instabilität**: Wenn `planItems` neu geladen wird nach `selectedItemForDuration` Änderung, könnte SwiftUI die ScrollPosition verlieren

2. **Sheet Presentation Animation**: Die Sheet-Animation könnte mit dem ScrollView interagieren

3. **Fokus-Management**: SwiftUI könnte den Fokus auf das Sheet legen und dabei das ScrollView resetten

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/BacklogView.swift` | Haupt-View mit ScrollView und Sheet-Binding |
| `Sources/Views/BacklogRow.swift` | Enthält metadataRow mit horizontalem ScrollView |
| `Sources/Views/DurationPicker.swift` | Der Picker Sheet der geöffnet wird |

## Lösungsansätze

### Option A: ScrollViewReader + scrollPosition
- `ScrollViewReader` um aktuelle Position zu speichern
- Nach Sheet-Dismiss zur gespeicherten Position zurückscrollen

### Option B: Kein Nested ScrollView
- Horizontalen ScrollView in metadataRow entfernen
- Stattdessen `HStack` mit `.lineLimit(1)` und Truncation

### Option C: Button außerhalb des ScrollViews
- Duration Badge nicht im horizontalen ScrollView platzieren

### Option D: Explicit Animation Control
- `.transaction { $0.animation = nil }` beim Setzen von `selectedItemForDuration`

## Empfehlung

**Option B** ist die sauberste Lösung:
- Entferne den horizontalen ScrollView aus `metadataRow`
- Verwende einen einfachen `HStack` mit `fixedSize()` auf den Badges
- Das eliminiert die Nested-ScrollView-Problematik komplett

## Risks & Considerations

- Bei sehr vielen Badges könnte der HStack abgeschnitten werden
- Aber die aktuelle UI zeigt max. 5-6 Badges, das passt auf jeden Bildschirm
