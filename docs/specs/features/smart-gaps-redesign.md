# Smart Gaps - Blöcke-Tab Redesign

- [ ] Approved for implementation

## Purpose

Automatische Erkennung freier Zeitslots (30-60 min) mit One-Tap Block-Erstellung statt umständlichem Sheet-Flow.

**Problem:** User muss durch 16 Stunden scrollen, freie Slots manuell finden, dann Sheet durchlaufen.

**Lösung:** App zeigt passende Lücken direkt an, One-Tap erstellt Block.

## Scope

| Metrik | Wert |
|--------|------|
| **Dateien** | 1 |
| **LoC** | ~+80 / -20 |

**Betroffene Datei:**
- `TimeBox/Sources/Views/BlockPlanningView.swift`

## Implementation Details

### 1. Gap Detection Algorithm

```swift
func findFreeSlots(minMinutes: Int = 30, maxMinutes: Int = 60) -> [TimeSlot] {
    // 1. Sammle alle belegten Zeiträume (Events + FocusBlocks)
    // 2. Finde Lücken zwischen 6:00 und 22:00
    // 3. Filtere auf minMinutes...maxMinutes
    // 4. Sortiere nach Startzeit
}
```

### 1b. Edge Case: Ganzer Tag frei

Wenn keine Events vorhanden sind (Gap > 4 Stunden), zeige "Smart Suggestions":

```swift
let defaultSuggestions = [9, 11, 14, 16] // Uhrzeit als volle Stunde
// Zeige 4 vorgeschlagene 60-min Slots
```

**UI bei freiem Tag:**
```
┌─────────────────────────────────┐
│ 🎯 Tag ist frei!                │
│                                 │
│ Vorgeschlagene Zeiten:          │
│ ┌─────────────────────────────┐ │
│ │ 09:00 (60m)          [+]    │ │
│ │ 11:00 (60m)          [+]    │ │
│ │ 14:00 (60m)          [+]    │ │
│ │ 16:00 (60m)          [+]    │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### 2. UI Struktur

```
SmartGapsSection (neue Komponente)
├── Header: "Freie Slots"
├── ForEach(freeSlots) { slot in
│   └── GapRow(slot)
│       ├── Zeitraum (z.B. "09:30-10:15")
│       ├── Dauer Badge (z.B. "45 min")
│       └── "+" Button → createFocusBlock(slot)
└── Empty State wenn keine Slots
```

### 3. Timeline (optional)

- Timeline bleibt als sekundäre Ansicht
- Kann via Toggle ein/ausgeklappt werden
- Oder: Komplett entfernen (simpler)

## Test Plan

### Automated Tests (TDD RED)

1. **testFindFreeSlotsFindsGaps**
   - GIVEN: Calendar with events at 8-9, 11-12, 15-16
   - WHEN: findFreeSlots(min: 30, max: 60) called
   - THEN: Returns slots [9-10, 12-13, 13-14, 14-15, 16-17...] filtered by duration

2. **testFindFreeSlotsRespectsMinDuration**
   - GIVEN: 20-minute gap between events
   - WHEN: findFreeSlots(min: 30) called
   - THEN: Gap is NOT included (too short)

3. **testFindFreeSlotsRespectsMaxDuration**
   - GIVEN: 90-minute gap between events
   - WHEN: findFreeSlots(max: 60) called
   - THEN: Gap is split or excluded based on implementation

4. **testWholeDayFreeShowsSuggestions**
   - GIVEN: No calendar events for the day
   - WHEN: findFreeSlots() called
   - THEN: Returns 4 default suggestions at 9:00, 11:00, 14:00, 16:00 (each 60 min)

### Manual Tests

1. [ ] App zeigt "Freie Slots" Section oben
2. [ ] Slots sind korrekt berechnet (Kalender-Events berücksichtigt)
3. [ ] Tap auf "+" erstellt Focus Block sofort
4. [ ] Kein Sheet öffnet sich
5. [ ] Neu erstellter Block erscheint in Liste/Timeline
6. [ ] Empty State wenn keine passenden Slots

## Acceptance Criteria

- [ ] Freie Slots (30-60 min) werden automatisch erkannt
- [ ] One-Tap Erstellung ohne Sheet
- [ ] Performance: Berechnung < 100ms
- [ ] Kalender-Events werden korrekt berücksichtigt
- [ ] Bestehende FocusBlocks werden berücksichtigt

## Design Decisions

| Frage | Entscheidung |
|-------|--------------|
| Timeline behalten? | Ja, als Toggle (collapsed by default) |
| Slot-Dauer anpassbar? | Nein, feste 30-60 min für MVP |
| Mehrere Slots gleichzeitig? | Nein, einer nach dem anderen |
