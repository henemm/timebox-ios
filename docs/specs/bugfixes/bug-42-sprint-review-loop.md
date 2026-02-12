# Bug 42: Sprint Review Dauerloop + macOS Parity

## Problem

### Bug A: Dauerloop beim Schließen
Der Sprint Review Dialog lässt sich nach einem abgelaufenen Focus Block nicht mehr schließen.

**Ablauf:**
1. Focus Block läuft ab → `showSprintReview = true` → Sheet öffnet sich
2. User klickt "Schließen"/"Fertig" → `onDismiss()` ruft `loadData()` auf
3. `loadData()` findet denselben abgelaufenen Block (`isPast == true`)
4. Setzt `showSprintReview = true` → Sheet öffnet sich sofort wieder
5. → Endlos-Loop

**Root Cause:** `loadData()` prüft nicht, ob der User die Review bereits geschlossen hat.

**Betroffene Stellen:**
- `FocusLiveView.swift:459-461` - iOS loadData()
- `MacFocusView.swift:412-414` - macOS loadData()

### Bug B: macOS Sprint Review ist Placeholder
`MacSprintReviewSheet` (MacFocusView.swift:634-727) ist ein statischer Placeholder:
- Nur Icon + Titel + Zahlen + "Schließen"
- Kein interaktives Task-Toggling
- Kein Completion Ring
- Kein Zeitvergleich (geplant vs. gebraucht)
- Kein "Offene Tasks ins Backlog"

iOS `SprintReviewSheet` hat all diese Features.

## Fix

### Fix A: reviewDismissed Flag (beide Plattformen)

Neues `@State private var reviewDismissed = false` Flag:

1. **Bei Dismiss** → `reviewDismissed = true`
2. **In loadData()** → `if activeBlock?.isPast == true && !reviewDismissed { showSprintReview = true }`
3. **In checkBlockEnd()** → `if block.isPast && !showSprintReview && !reviewDismissed { ... }`
4. **Reset** → Wenn `activeBlock` sich ändert (neuer Block), `reviewDismissed = false`

### Fix B: macOS SprintReviewSheet auf iOS-Niveau bringen

`MacSprintReviewSheet` ersetzen durch vollwertige Version mit:
- Completion Ring (Prozentanzeige)
- Interaktives Task-Toggling (erledigt/unerledigt umschalten)
- Zeitvergleich pro Task (geplant vs. gebraucht)
- "Offene Tasks ins Backlog" Button
- "Änderungen speichern" Button
- Stats: Erledigt, Offen, geplant, gebraucht

Hinweis: macOS verwendet `LocalTask` statt `PlanItem`, daher kein 1:1 Copy-Paste.

## Affected Files

| Datei | Änderung |
|-------|----------|
| `Sources/Views/FocusLiveView.swift` | reviewDismissed Flag + loadData/checkBlockEnd Guard |
| `FocusBloxMac/MacFocusView.swift` | reviewDismissed Flag + loadData/checkBlockEnd Guard + MacSprintReviewSheet komplett neu |

## Acceptance Criteria

- [ ] Sprint Review lässt sich auf iOS schließen ohne Loop
- [ ] Sprint Review lässt sich auf macOS schließen ohne Loop
- [ ] macOS Sprint Review zeigt Completion Ring
- [ ] macOS Sprint Review erlaubt Task-Toggling
- [ ] macOS Sprint Review zeigt Zeitvergleich (geplant vs. gebraucht)
- [ ] macOS Sprint Review hat "Offene Tasks ins Backlog" Button
