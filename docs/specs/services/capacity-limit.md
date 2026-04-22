---
entity_id: capacity-limit
type: feature
created: 2026-04-22
status: draft
version: "1.0"
tags: [suggestions, behavioral-profile, capacity]
---

# Kapazitäts-Limit für Vorschläge (Feature #237)

## Approval

- [ ] Approved

## Purpose

`NextUpSuggestionService.maxSuggestionsForLoad()` gibt feste 3/4/5 zurück, unabhängig von der echten Kapazität des Users. Dieses Feature begrenzt die Anzahl auf Basis von `BehavioralProfile.avgTasksPerDay` minus bereits geplanter Tasks.

## Source

- **File:** `Sources/Services/NextUpSuggestionService.swift` — `maxSuggestionsForLoad()` (Zeile 157), `compute()` (Zeile 54)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `BehavioralProfile.avgTasksPerDay` | property | Durchschnittliche Tasks/Tag (nil wenn <5 aktive Tage) |
| `PlanItem.isNextUp` | property | "Für heute geplant" |
| `MeetingLoad` | enum | Bestehende Meeting-basierte Lastberechnung |

## Implementation Details

### `compute()` erweitern

`compute()` hat bereits Zugriff auf `items` und `profile`. Ändere Zeile 62:

```swift
// Vorher:
let maxCount = maxSuggestionsForLoad(load)

// Nachher:
let alreadyPlanned = items.filter { $0.isNextUp && !$0.isCompleted }.count
let maxCount = capacityBasedMax(
    profile: profile,
    alreadyPlanned: alreadyPlanned,
    meetingLoad: load
)
```

### Neue Funktion `capacityBasedMax()`

```swift
static func capacityBasedMax(
    profile: BehavioralProfile,
    alreadyPlanned: Int,
    meetingLoad: MeetingLoad
) -> Int {
    let meetingMax = maxSuggestionsForLoad(meetingLoad)

    guard let avgTasks = profile.avgTasksPerDay else {
        // Profil noch dünn (<5 aktive Tage) → Fallback auf Meeting-basierte Limits
        return meetingMax
    }

    let capacityLeft = max(0, Int(avgTasks.rounded()) - alreadyPlanned)
    return min(capacityLeft, meetingMax)
}
```

Logik:
- `avgTasksPerDay` ist nil → Fallback auf bestehende feste Werte (3/4/5)
- `avgTasksPerDay` ist vorhanden → `min(avgTasks - alreadyPlanned, meetingMax)`
- Meeting-Load bleibt als Obergrenze erhalten
- Minimum ist 0 (keine negativen Vorschläge)

### `maxSuggestionsForLoad()` bleibt unverändert

Wird weiterhin als Obergrenze genutzt.

## Acceptance Criteria

1. Wenn avgTasksPerDay=4 und 3 Tasks geplant → max 1 Vorschlag
2. Wenn avgTasksPerDay=4 und 0 Tasks geplant → max 4 Vorschläge (begrenzt durch meetingMax)
3. Wenn avgTasksPerDay=nil (<5 Tage Daten) → Fallback auf feste 3/4/5
4. Wenn avgTasksPerDay=4 und 5 Tasks geplant → 0 Vorschläge
5. Meeting-Load bleibt als Obergrenze: avgTasks=10, 0 geplant, high load → max 3

## Known Limitations

- Kein UI-Feedback warum weniger Vorschläge kommen (separates Feature)
- `candidatesPerSlot()` wird nicht angepasst (nur `compute()`)

## Changelog

- 2026-04-22: Initial spec
