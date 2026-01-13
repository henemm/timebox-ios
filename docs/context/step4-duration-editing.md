# Context: Step 4 - Duration Editing

## Request Summary
Manuelle Dauer-Auswahl fuer Tasks via vordefinierte Tags: #5min, #15min, #30min, #60min. Tap auf DurationBadge oeffnet Picker.

## Bestehendes Duration-System

**Prioritaet (absteigend):**
1. `TaskMetadata.manualDuration` (noch nie gesetzt bisher)
2. Parsed aus Title via Regex `#(\d+)min`
3. Default: 15 Minuten

**DurationSource Enum:**
- `.manual` - Manuell gesetzt
- `.parsed` - Aus Title geparst
- `.default` - Fallback (gelbes Badge)

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/TaskMetadata.swift` | Speichert `manualDuration: Int?` |
| `Sources/Models/PlanItem.swift` | `resolveDuration()` Logik, `durationSource` |
| `Sources/Views/DurationBadge.swift` | Anzeige (gelb=default, blau=gesetzt) |
| `Sources/Views/BacklogRow.swift` | Verwendet DurationBadge |
| `Sources/Views/BacklogView.swift` | Liste mit ForEach, braucht Edit-Handler |
| `Sources/Services/SyncEngine.swift` | Braucht `updateDuration()` Methode |

## Bestehende Patterns

1. **Edit-Pattern (SortOrder):** `SyncEngine.updateSortOrder()` - holt Metadata, aendert, speichert
2. **Badge-Styling:** Gelb fuer default, Blau fuer gesetzt - kann erweitert werden
3. **Feedback:** `.sensoryFeedback(.impact)` bei Aktionen

## Geplante Erweiterungen

1. **DurationPicker** (neu) - 4 Buttons: 5m, 15m, 30m, 60m
2. **DurationBadge** - Tappable machen
3. **BacklogRow** - onDurationTap Callback
4. **BacklogView** - Sheet State fuer Picker, Update-Logik
5. **SyncEngine** - `updateDuration(itemID:, minutes:)` Methode

## Vordefinierte Optionen

```swift
enum DurationOption: Int, CaseIterable {
    case fiveMin = 5
    case fifteenMin = 15
    case thirtyMin = 30
    case sixtyMin = 60
}
```

## UI-Flow

1. User tippt auf DurationBadge in BacklogRow
2. Sheet/Popover oeffnet sich mit 4 Buttons
3. User waehlt Dauer (oder "Reset" fuer default)
4. TaskMetadata.manualDuration wird aktualisiert
5. Badge wechselt zu blau, zeigt neue Dauer
6. Haptisches Feedback bei Auswahl

## Risks & Considerations

- **Performance:** Sheet pro Item vs. globaler Sheet mit Item-ID State
- **UX:** Sheet vs. Popover vs. Inline-Expansion
- **Reset-Option:** Moeglichkeit manualDuration auf nil zu setzen

---

## Analysis

### Affected Files (with changes)

| File | Change Type | Description | LoC |
|------|-------------|-------------|-----|
| `Views/DurationBadge.swift` | MODIFY | Optional onTap callback | +5 |
| `Views/BacklogRow.swift` | MODIFY | Pass onDurationTap callback | +3 |
| `Views/BacklogView.swift` | MODIFY | Sheet state, updateDuration call | +25 |
| `Services/SyncEngine.swift` | MODIFY | updateDuration(itemID:minutes:) | +12 |
| `Views/DurationPicker.swift` | CREATE | 4 Buttons + Reset option | +45 |

### Scope Assessment

- **Files:** 5 (4 modify, 1 create)
- **Estimated LoC:** +90
- **Risk Level:** LOW

### Technical Approach

1. **DurationPicker** als Sheet-Content mit HStack von Buttons
2. **Globaler Sheet-State** in BacklogView mit `selectedItemID: String?`
3. **Callback-Chain:** DurationBadge.onTap -> BacklogRow -> BacklogView.showPicker
4. **SyncEngine.updateDuration()** analog zu updateSortOrder()
5. **Badge-Farbe:** Manual = blau, Parsed = blau, Default = gelb (unveraendert)

### Open Questions

- [x] Vordefinierte Optionen: 5, 15, 30, 60 Minuten (bestaetigt)
- [ ] Reset-Option gewuenscht? (manualDuration auf nil setzen)
