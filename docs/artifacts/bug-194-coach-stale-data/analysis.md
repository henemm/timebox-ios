# Bug #194: Coach-Tab zeigt veraltete Daten nach Tab-Wechsel

## Symptom
User erledigt Task im Backlog → wechselt zurück zum Coach-Tab → Coach zeigt alten Zustand.

## Root Cause
`CoachView.loadAllData()` wird nur einmal in `.task {}` aufgerufen (Zeile 73-74). SwiftUI's `.task` Modifier führt den Block nur beim ersten Erscheinen der View aus. Bei Tab-Wechsel zurück wird er nicht erneut aufgerufen.

## Vergleich mit anderen Views

| View | Reload-Mechanismus |
|------|-------------------|
| BacklogView | `.task(id:)` + `.onChange` + `.onReceive` + `.refreshable` |
| DayView | Nur `.task {}` — hat dasselbe Problem, aber im Coach-Layout nicht sichtbar |
| DailyReviewView | Nur `.task {}` — hat dasselbe Problem |
| **CoachView** | **Nur `.task {}` — BUG** |

## Fix
`@State private var refreshID = UUID()` + `.task(id: refreshID)` + `.onAppear { refreshID = UUID() }`

Erzwingt Reload bei jedem Tab-Wechsel. Einfach, bewährt, keine Side-Effects.

## Challenge-Ergebnisse (eingearbeitet)

1. **completedAt wird korrekt gesetzt** — SyncEngine.swift:171 setzt `completedAt = Date()`. Kein orthogonaler Bug.
2. **Doppelter Load:** `.onAppear` + `.task(id:)` feuern beim ersten Mal beide. Lösung: `onAppear` nur bei Nicht-Erstaufruf nutzen, oder einfach akzeptieren (ein extra Load beim Start ist harmlos).
3. **deferredCompletion Timing:** BacklogView nutzt `deferredCompletion.scheduleCompletion()` mit Delay. Bei schnellem Tab-Wechsel könnten Daten noch nicht committed sein. Akzeptables Restrisiko — beim nächsten Tab-Wechsel werden sie korrekt geladen.

## Blast Radius
DayView und DailyReviewView haben dasselbe Problem — sind aber im Coach-Layout nicht aktiv.
