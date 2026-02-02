---
entity_id: quick-edit-backlog
type: feature
created: 2026-01-27
status: draft
version: "1.0"
workflow: quick-edit-backlog
tags: [backlog, editing, ux]
---

# Quick Edit Tasks im Backlog

## Approval

- [ ] Approved

## Purpose

Nutzer sollen Task-Metadaten (Kategorie, Wichtigkeit, Dringlichkeit, Dauer) direkt im Backlog aendern koennen - ohne den umstaendlichen 3-Schritt-Flow (Tap -> Detail-Sheet -> Bearbeiten-Button). Ziel: max. 2 Taps, Backlog bleibt sichtbar.

## User Story

Siehe: `docs/project/stories/quick-edit-backlog.md`

## Source

- **BacklogView:** `Sources/Views/BacklogView.swift`
- **BacklogRow:** `Sources/Views/BacklogRow.swift`
- **DurationBadge:** `Sources/Views/DurationBadge.swift`
- **DurationPicker:** `Sources/Views/DurationPicker.swift`
- **PlanItem:** `Sources/Models/PlanItem.swift`

## Scope

### Betroffene Dateien

| Datei | Aenderung | Beschreibung |
|-------|-----------|--------------|
| `Sources/Views/BacklogRow.swift` | MODIFY | Tappable Badges fuer Kategorie + Wichtigkeit hinzufuegen, Callbacks ergaenzen |
| `Sources/Views/BacklogView.swift` | MODIFY | Neue State-Variablen + Sheet-Bindings fuer Inline-Picker, Context Menu |
| `Sources/Views/ImportancePicker.swift` | CREATE | Inline-Picker fuer Wichtigkeit (3 Buttons, analog DurationPicker) |
| `Sources/Views/CategoryPicker.swift` | CREATE | Inline-Picker fuer Kategorie (5 Buttons, analog DurationPicker) |

- **Dateien:** 2 Modify + 2 Create = 4 Dateien
- **Geschaetzt:** +120 / -5 LoC

## Implementation Details

### Feature A: Tappable Inline-Badges in BacklogRow

Aktuell zeigt BacklogRow links ein Importance-Emoji (`importanceIcon`) und rechts ein DurationBadge. Die Badges sind **nicht direkt tappbar** (nur DurationBadge hat `onTap`).

**Aenderung:**

1. **Importance-Badge** (links, aktuell nur Text-Emoji):
   - Zu einem tappbaren Badge umbauen (analog DurationBadge)
   - Tap oeffnet ImportancePicker (kleines Sheet)
   - Zeigt: Emoji + "Hoch"/"Mittel"/"Niedrig" oder "?" wenn nil

2. **Kategorie-Badge** (neu, in der Tag-Zeile):
   - Neues tappbares Badge zeigt aktuelle Kategorie-Icon
   - Tap oeffnet CategoryPicker (kleines Sheet)
   - Zeigt: SF Symbol fuer die aktuelle Kategorie

3. **DurationBadge** (rechts, bereits tappbar):
   - Bestehendes Verhalten bleibt (oeffnet DurationPicker)
   - Keine Aenderung noetig

**Neue Callbacks in BacklogRow:**
```
var onImportanceTap: (() -> Void)?
var onCategoryTap: (() -> Void)?
```

### Feature B: Inline-Picker (kleine Sheets)

Zwei neue Picker nach dem **bestehenden DurationPicker-Pattern**:

**ImportancePicker** (`.presentationDetents([.height(180)])`):
```
Titel: "Wichtigkeit"
3 Buttons: 🟦 Niedrig | 🟨 Mittel | 🔴 Hoch
+ Zuruecksetzen-Button (setzt auf nil)
```

**CategoryPicker** (`.presentationDetents([.height(220)])`):
```
Titel: "Kategorie"
5 Buttons mit SF Symbols:
  💰 Einkommen | 🔧 Maintenance | 🔋 Recharge | 📚 Lernen | 🤝 Giving Back
```

### Feature C: Context Menu (Long-Press)

`.contextMenu` auf BacklogRow mit:
- "Bearbeiten" → oeffnet TaskFormSheet direkt (ueberspringt Detail-Sheet)
- "Zu Next Up" (wenn nicht schon drin)
- "Loeschen"

### Datenfluss

```
BacklogRow (Tap auf Badge)
  → BacklogView State-Variable gesetzt (z.B. selectedItemForImportance)
  → Sheet oeffnet Inline-Picker
  → Nutzer waehlt Wert
  → BacklogView ruft updateSingleProperty() auf
  → SyncEngine persistiert
  → loadTasks() aktualisiert Liste
  → Nutzer ist noch im Backlog, gleiche Position
```

Fuer einzelne Property-Updates wird eine neue Hilfsmethode `updateSingleProperty()` in BacklogView ergaenzt, die nur den geaenderten Wert an SyncEngine weitergibt (statt alle Felder wie bei `updateTask()`).

## Expected Behavior

### Inline Importance Edit
- **Tap** auf Importance-Badge in BacklogRow
- **Sheet** oeffnet mit 3 Buttons (Niedrig/Mittel/Hoch) + Zuruecksetzen
- **Auswahl** schliesst Sheet, Badge aktualisiert sich sofort
- **Backlog** bleibt sichtbar, Scroll-Position unveraendert

### Inline Category Edit
- **Tap** auf Kategorie-Badge in BacklogRow
- **Sheet** oeffnet mit 5 Kategorie-Buttons
- **Auswahl** schliesst Sheet, Badge aktualisiert sich sofort

### Context Menu (Long-Press)
- **Long-Press** auf beliebige Stelle der BacklogRow
- **Menu** zeigt: Bearbeiten, Zu Next Up, Loeschen
- **Bearbeiten** oeffnet TaskFormSheet direkt (1 Schritt statt 3)

## Accessibility

| Element | Identifier | Label |
|---------|-----------|-------|
| Importance Badge | `"importance-badge-{taskID}"` | "Wichtigkeit: {wert}" |
| Category Badge | `"category-badge-{taskID}"` | "Kategorie: {wert}" |
| ImportancePicker | `"importance-picker"` | - |
| CategoryPicker | `"category-picker"` | - |
| Context Menu: Edit | `"context-edit"` | "Bearbeiten" |
| Context Menu: Next Up | `"context-next-up"` | "Zu Next Up" |
| Context Menu: Delete | `"context-delete"` | "Loeschen" |

## Test Plan

### Unit Tests (TDD RED)

- [ ] **Test ImportancePicker Auswahl:** GIVEN ImportancePicker angezeigt, WHEN Nutzer "Hoch" tippt, THEN onSelect(3) wird aufgerufen
- [ ] **Test CategoryPicker Auswahl:** GIVEN CategoryPicker angezeigt, WHEN Nutzer "Recharge" tippt, THEN onSelect("recharge") wird aufgerufen
- [ ] **Test ImportancePicker Zuruecksetzen:** GIVEN ImportancePicker angezeigt, WHEN "Zuruecksetzen" getippt, THEN onSelect(nil) wird aufgerufen

### UI Tests (TDD RED)

- [ ] **Test Importance Inline Edit:** GIVEN Backlog mit Task, WHEN Tap auf Importance-Badge, THEN ImportancePicker oeffnet. WHEN "Hoch" gewaehlt, THEN Badge zeigt Rot
- [ ] **Test Category Inline Edit:** GIVEN Backlog mit Task, WHEN Tap auf Category-Badge, THEN CategoryPicker oeffnet. WHEN Kategorie gewaehlt, THEN Badge aktualisiert
- [ ] **Test Context Menu Edit:** GIVEN Backlog mit Task, WHEN Long-Press auf Task, THEN Context Menu erscheint mit "Bearbeiten". WHEN "Bearbeiten" getippt, THEN TaskFormSheet oeffnet direkt
- [ ] **Test Scroll-Position bleibt:** GIVEN Backlog gescrollt, WHEN Inline-Edit durchgefuehrt, THEN Scroll-Position unveraendert

## Acceptance Criteria

- [ ] Wichtigkeit ist mit 2 Taps aenderbar (Tap Badge -> Tap Wert)
- [ ] Kategorie ist mit 2 Taps aenderbar (Tap Badge -> Tap Wert)
- [ ] Dauer bleibt mit 2 Taps aenderbar (bestehendes Verhalten)
- [ ] Long-Press oeffnet Context Menu mit "Bearbeiten" (direkter Edit-Modus)
- [ ] Backlog bleibt sichtbar waehrend Inline-Edit
- [ ] Scroll-Position geht nicht verloren
- [ ] Alle Accessibility Identifiers gesetzt

## Known Limitations

- Urgency (Dringlichkeit) wird nicht als eigenes Inline-Badge angezeigt, da es nur 2 Werte hat und weniger oft geaendert wird. Erreichbar ueber Context Menu -> Bearbeiten.
- Nur in der Listen-Ansicht des Backlogs (nicht in Eisenhower-Matrix).

## Changelog

- 2026-01-27: Initial spec created
