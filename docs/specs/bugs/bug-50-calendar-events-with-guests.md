---
entity_id: bug_50_calendar_guests
type: bugfix
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [ios, macos, calendar, eventkit, read-only, attendees]
---

# Bug 50: Kalender-Events mit Gaesten funktionieren nicht (iOS + macOS)

## Approval

- [ ] Approved

## Purpose

Kalender-Events mit Gaesten (Attendees) sind in EventKit schreibgeschuetzt. Die App behandelt diesen Fall nicht korrekt: Drag & Drop schlaegt fehl, es gibt kein visuelles Feedback und keine verstaendliche Fehlermeldung. Ein frueherer Teilfix (Commit `4a5eafe`) hat nur die Kategorie-Zuweisung per iCloud KV Store Fallback geloest - alle anderen Interaktionen sind weiterhin kaputt.

## Vorgeschichte

- **Commit `4a5eafe`** (2026-02-12): "Kalender-Fixes - Kategorie-Sync, Zeitpicker, FocusBlox-Rename"
  - Fix 1: `updateEventCategory()` Fallback auf iCloud KV Store bei read-only Events
  - Aber: NUR Kategorie-Zuweisung wurde gefixed, Rest nicht

## Root Cause Analyse

### Kern-Problem: `CalendarEvent` kennt keinen Read-Only Status

Das `CalendarEvent` Model (`Sources/Models/CalendarEvent.swift:13-21`) erfasst beim Mapping von `EKEvent` NICHT:
- `event.hasAttendees` (hat Gaeste)
- `event.calendar.allowsContentModifications` (Kalender beschreibbar)

Ohne diese Information koennen Views nicht unterscheiden zwischen:
- Normale Events (voll editierbar)
- Events mit Gaesten (schreibgeschuetzt)
- Events aus Read-Only Kalendern (Abonnements)

### Betroffene Operationen

| Operation | Datei:Zeile | Problem |
|-----------|-------------|---------|
| **Verschieben (Drag&Drop)** | `EventKitRepository.swift:221-238` | `moveCalendarEvent()` hat KEIN Error-Handling fuer read-only Events. Save schlaegt fehl, User sieht nur generischen Fehler |
| **Drag-Affordance** | `EventBlock.swift:48` | `.draggable()` auf ALLEN Events, auch read-only. User kann draggen, aber Drop scheitert |
| **Kategorie-Zuweisung** | `EventKitRepository.swift:240-268` | GEFIXT (iCloud KV Store Fallback) |
| **macOS Timeline** | `MacTimelineView.swift:96-107` | Events erscheinen interaktiv, Verschieben scheitert still |

### Warum kein Fallback fuer Verschieben moeglich

Kategorie ist Metadata (in Notes oder iCloud KV Store speicherbar). Aber Event-Zeiten (Start/Ende) sind **strukturelle EKEvent-Properties** - die MUESSEN im Kalender gespeichert werden. Ein iCloud KV Store Fallback ist hier NICHT moeglich. Stattdessen muss die UI das Verschieben fuer read-only Events **verhindern**.

## Fix-Strategie

### Fix 1: CalendarEvent Model erweitern

Neue Properties im `CalendarEvent` Model:

```
hasAttendees: Bool     // aus EKEvent.hasAttendees
isReadOnly: Bool       // !calendar.allowsContentModifications || hasAttendees
calendarTitle: String  // fuer Fehlermeldung ("Shared Calendar" etc.)
```

Beide Init-Methoden (EKEvent + Test-Init) muessen erweitert werden.

### Fix 2: Drag-Affordance nur fuer editierbare Events

In `EventBlock.swift` und `MacTimelineView.swift`:
- `.draggable()` NUR wenn `!event.isReadOnly`
- Visueller Hinweis: Read-only Events leicht anders darstellen (z.B. Schloss-Icon, reduzierte Opacity auf Drag-Handle)

### Fix 3: moveCalendarEvent() Error-Handling verbessern

In `EventKitRepository.swift:moveCalendarEvent()`:
- VOR dem Save pruefen ob Event editierbar ist
- Spezifische Exception werfen: `EventKitError.eventReadOnly`
- UI zeigt verstaendliche Meldung: "Termine mit Gaesten koennen nicht verschoben werden"

### Fix 4: Visuelle Unterscheidung in Timeline

Read-only Events in der Timeline kennzeichnen:
- Kleines Schloss-Icon oder "Gaeste"-Indikator
- Kein Drag-Handle / Drag-Cursor
- Tap oeffnet Detail-View (readonly) statt Edit-Sheet

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `Sources/Models/CalendarEvent.swift` | +hasAttendees, +isReadOnly, +calendarTitle |
| `Sources/Services/EventKitRepository.swift` | moveCalendarEvent() Error-Handling, +EventKitError.eventReadOnly |
| `Sources/Views/EventBlock.swift` | Conditional .draggable(), visueller Read-Only Indikator |
| `FocusBloxMac/MacTimelineView.swift` | Conditional Drag, visueller Read-Only Indikator |

**Geschaetzter Aufwand:** ~40-60k Tokens, 4 Dateien, ~80 LoC

## Expected Behavior

### Nach Fix:
- Events MIT Gaesten werden angezeigt, aber als "read-only" markiert (Schloss-Icon)
- Drag & Drop ist fuer read-only Events **deaktiviert** (kein Drag-Handle)
- Kategorie-Zuweisung funktioniert weiterhin (iCloud KV Store Fallback)
- Tap auf read-only Event oeffnet Detail-Ansicht (nicht Edit)
- Falls doch ein Fehler auftritt: Klare Meldung "Termine mit Gaesten koennen nicht verschoben werden"

## Akzeptanzkriterien

1. `CalendarEvent` hat `hasAttendees` und `isReadOnly` Properties
2. Read-only Events sind visuell unterscheidbar (Schloss-Icon)
3. Drag & Drop ist fuer read-only Events deaktiviert
4. `moveCalendarEvent()` wirft spezifischen Fehler bei read-only Events
5. Kategorie-Zuweisung funktioniert weiterhin (bestehender Fix bleibt)
6. iOS und macOS gleichermassen gefixed

## Known Limitations

- Events mit Gaesten koennen NICHT verschoben werden - das ist eine EventKit-Beschraenkung, kein FocusBlox-Bug
- Kategorie-Fallback nutzt iCloud KV Store, was bei vielen Events langsam werden kann

## Changelog

- 2026-02-13: Initial spec (Root Cause Analyse, Fix-Strategie, alle 4 Fix-Bereiche)
