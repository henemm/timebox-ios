---
entity_id: coach-inline-actions
type: feature
created: 2026-04-21
status: draft
version: "1.0"
tags: [coach, ux, actions]
---

# CoachView Inline-Actions für alle Sections (Feature #278)

## Approval

- [ ] Approved

## Purpose

Sections "Heute geplant" und "Offen geblieben" in CoachView haben keine schnellen Aktionen — nur Long-Press-Kontextmenü. Vorschläge-Sections haben bereits Inline-Buttons. Dieses Feature erweitert `taskWithActions()` so dass alle Task-Sections passende Inline-Actions bekommen.

## Source

- **File:** `Sources/Views/CoachView.swift` — `taskWithActions()` (Zeilen 764–838), `coachTaskSection()` (Zeilen 686–738)

## Implementation Details

### Erweiterung von `taskWithActions()`

Aktuell: `showActions: Bool` steuert ob "Für heute einplanen" + "Ausblenden" angezeigt werden.

Neu: Statt Boolean → Enum-basierte Action-Typen:

```swift
enum CoachTaskActionType {
    case suggest      // Vorschläge: "Für heute einplanen" + "Ausblenden"
    case planned      // Heute geplant: "Erledigt" + "Entplanen"
    case remaining    // Offen geblieben: "Erledigt" + "Auf morgen"
    case completed    // Erledigt: keine Actions
    case none         // Keine Inline-Actions
}
```

Die Buttons je Typ:

| Typ | Button 1 | Button 2 |
|-----|----------|----------|
| suggest | "Für heute einplanen" (blau, calendar.badge.plus) | "Ausblenden" (secondary, eye.slash) |
| planned | "Erledigt" (grün, checkmark.circle) | "Entplanen" (secondary, calendar.badge.minus) |
| remaining | "Erledigt" (grün, checkmark.circle) | "Auf morgen" (secondary, arrow.right.circle) |
| completed | — | — |
| none | — | — |

### Aufrufe anpassen

| Zeile | Section | Vorher | Nachher |
|-------|---------|--------|---------|
| 299 | Tag-Cluster | showActions: true | actionType: .suggest |
| 316 | Vorschläge morgens | showActions: true | actionType: .suggest |
| 402 | Heute geplant | showActions: false | actionType: .planned |
| 414 | Erledigt | showActions: false, completed: true | actionType: .completed |
| 427 | Vorschläge tagsüber | showActions: true | actionType: .suggest |
| 502 | Erledigt abends | showActions: false, completed: true | actionType: .completed |
| 515 | Offen geblieben | showActions: false | actionType: .remaining |

### Aktionen

- "Erledigt" → `completeTask(task)` (existiert)
- "Entplanen" → `removeFromToday(task)` — setzt `isNextUp = false` (existiert als `toggleNextUp`)
- "Auf morgen" → `dismissTask(task.id)` (existiert, blendet für heute aus)

## Acceptance Criteria

1. "Heute geplant" Tasks zeigen "Erledigt" + "Entplanen" Buttons
2. "Offen geblieben" Tasks zeigen "Erledigt" + "Auf morgen" Buttons
3. "Vorschläge" Tasks zeigen weiterhin "Für heute einplanen" + "Ausblenden"
4. "Erledigt" Tasks zeigen keine Action-Buttons
5. Kontextmenü (Long-Press) bleibt unverändert
6. Build erfolgreich (iOS + macOS)

## Known Limitations

- Kein echter Swipe — dafür wäre List-Umbau nötig (separates Ticket)
- Inline-Buttons sind visuell etwas größer als Swipe-Actions, nehmen mehr Platz ein

## Changelog

- 2026-04-21: Initial spec
