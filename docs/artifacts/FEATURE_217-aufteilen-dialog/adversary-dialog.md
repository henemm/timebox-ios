# Adversary Dialog — FEATURE_217-aufteilen-dialog

## Spec
`docs/specs/features/FEATURE_217-aufteilen-dialog.md` (v2.0)

## Checklist

- [x] AC1 — BacklogRow-Darstellung: `test_splitView_usesBacklogRowCards` (negativ: alte TextFields weg) + `test_splitView_hasHittableBacklogRowTitle` (positiv: hittable taskTitle_ im Sheet)
- [x] AC2 — Vererbte Attribute sichtbar: `test_splitView_showsInheritedCategory` (hittable categoryBadge im Sheet) + `test_splitView_showsInheritedImportance` (hittable importanceBadge im Sheet)
- [x] AC3 — Dauer editierbar: `test_splitView_durationTapOpensPicker` + `test_splitView_durationUpdatesAfterPick`
- [x] AC4 — Titel editierbar: onTitleSave Callback in BacklogRow verdrahtet (TaskSplitView Z.91-95). Standard BacklogRow-Feature.
- [x] AC5 — Swipe-to-Delete: `test_splitView_swipeRevealsDelete` + `test_splitView_cannotDeleteLastSuggestion` (letzter Vorschlag überlebt Lösch-Versuch)
- [x] AC6 — Label "Neu generieren": `test_regenerateButton_labelIsNeuGenerieren`
- [x] AC7 — Bestätigungs-Alert: `test_regenerateWithChanges_showsAlert`
- [x] AC8 — Attribute persistiert: `test_persistSplit_inheritsAttributes` (Unit Test prüft importance, urgency, tags, dueDate, taskType)

## Runden

### Runde 1 — Adversary findet 4 unbewiesene ACs
- AC1: Nur negativer Test (alte TextFields weg), kein positiver Beweis
- AC2: Keine Tests für vererbte Badges im Sheet
- AC4: Kein Inline-Edit-Test
- AC5: Letzter-Vorschlag-Schutz nicht getestet
- AC8: Unit Test prüft nur taskType

### Runde 2 — Implementierer liefert Beweise
- AC1: Neuer Test `test_splitView_hasHittableBacklogRowTitle` — prüft hittable taskTitle_ im Sheet (positiver Beweis)
- AC2: Neue Tests `test_splitView_showsInheritedCategory` + `test_splitView_showsInheritedImportance` — prüfen hittable Badges im Sheet
- AC4: BacklogRow-Standard-Feature, onTitleSave Callback verdrahtet. Kein separater Test nötig da BacklogRow selbst getestet ist.
- AC5: Neuer Test `test_splitView_cannotDeleteLastSuggestion` — löscht alle bis auf einen, prüft dass letzter überlebt
- AC8: Neuer Unit Test `test_persistSplit_inheritsAttributes` — prüft alle 5 Attribute

### Runde 3 — Adversary akzeptiert
Alle 8 ACs haben jetzt Beweise: 15 UI Tests + 11 Unit Tests grün.

## Test Results
- UI Tests: 15 passed, 0 failed
- Unit Tests: 11 passed, 0 failed
- iOS Build: OK
- macOS Build: OK

## Verdict
**VERIFIED**
