# Context: Sprint-Ende Bug #216

## Request Summary
Nach dem Sprint-Ende gibt es UX-Probleme: "Abbrechen"-Button wird gezeigt obwohl Sprint schon beendet ist, "Fertig" vs. "Sprint Review beenden" ist verwirrend, und nach Schließen kommt man zurück und kann erneut "Sprint Review starten".

## Bug-Details (aus Issue #216)
1. **"Abbrechen" nach Sprint-Ende**: Der Abort-Button in `progressHeader` wird IMMER gezeigt, auch wenn `block.isPast` — sollte ausgeblendet oder umbenannt werden
2. **"Fertig" vs. "Sprint Review beenden"**: SprintReviewSheet hat sowohl Toolbar-Button "Fertig" als auch Action-Button "Sprint Review beenden" — beide tun dasselbe (dismiss + onDismiss)
3. **Review-Loop**: Nach Schließen kann Sprint Review erneut gestartet werden — `reviewDismissed` wird im sheet-onDismiss nur gesetzt wenn `isAbortingBlock == true` (Zeile 152), bei natürlichem Sprint-Ende greift nur der onDismiss-Callback

## Related Files
| File | Relevance |
|------|-----------|
| Sources/Views/FocusLiveView.swift | Hauptview mit Sprint-Ablauf, progressHeader (Abort-Button), Sheet-Steuerung |
| Sources/Views/SprintReviewSheet.swift | iOS Sprint Review Dialog mit "Fertig" + "Sprint Review beenden" |
| FocusBloxMac/MacFocusView.swift | macOS-Pendant, gleiche Probleme (platform:both) |

## Existing Patterns
- `reviewDismissed` Flag verhindert Re-Opening des Sprint Review nach Dismiss
- `isAbortingBlock` unterscheidet User-Abort vs. natürliches Ende
- `block.isPast` prüft ob Block zeitlich abgelaufen ist
- Bug #42 hat bereits den Review-Loop-Fix eingeführt (reviewDismissed)

## Dependencies
- Upstream: `FocusBlock.isPast`, `EventKitRepository`, `NotificationService`
- Downstream: UI-State in FocusLiveView, MacFocusView

## Existing Specs
- `docs/specs/bugfixes/bug-42-sprint-review-loop.md` — Früherer Loop-Fix (reviewDismissed)
- `docs/specs/bugs/bug-211-cancel-focusblox.md` — Abort-Flow
- `docs/specs/bugfixes/bug-218-sprint-review-nudge.md` — Notification Cleanup

## Risks & Considerations
- Der "Abbrechen"-Button Abort-Flow (isAbortingBlock) muss erhalten bleiben für LAUFENDE Sprints
- platform:both — Fix muss auf iOS UND macOS angewendet werden
- Toolbar "Fertig" vs. Action "Sprint Review beenden" — eines entfernen, nicht beide behalten
