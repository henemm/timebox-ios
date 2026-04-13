# Context: #217 Aufteilen Dialog verbessern

## Request Summary
Der bestehende TaskSplitView (AI-basiertes Task-Aufteilen) soll verbessert werden: Vorschläge müssen editierbarer sein — insbesondere Löschen per Button und Zeit ändern. Der "Nochmal"-Button soll klar als "neue AI-Vorschläge generieren" erkennbar sein.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/TaskSplitView.swift` | **Hauptdatei** — der Split-Dialog, der geändert werden muss |
| `Sources/Services/TaskSplitService.swift` | AI-Service für Vorschläge + Persist-Logik |
| `Sources/Views/BacklogHygieneView.swift` | Ruft TaskSplitView als Sheet auf (Z.126, Z.149) |
| `Sources/Views/DurationPicker.swift` | Bestehender Duration-Picker (5/15/30/60 min) — wiederverwendbar |
| `FocusBloxUITests/TaskSplitUITests.swift` | Bestehende UI Tests für den Split-Dialog |

## Aktueller Zustand (TaskSplitView)
- **Titel editierbar**: ✅ TextField pro Vorschlag
- **Löschen**: ✅ Nur via Swipe-to-Delete (`.onDelete`) — kein expliziter Button
- **Zeit ändern**: ❌ Nur statischer Text `"\(suggestion.minutes) min"` — nicht editierbar
- **Hinzufügen**: ✅ "Hinzufügen"-Button für neue leere Zeile
- **Nochmal**: ✅ Regeneriert AI-Vorschläge (Button mit `arrow.clockwise`)
- **Erstellen**: ✅ Erstellt Sub-Tasks und dismissed

## Fehlende Features (aus Issue #217)
1. **Zeit ändern** pro Vorschlag — z.B. Tap auf Minuten öffnet DurationPicker oder Inline-Picker
2. **Expliziter Löschen-Button** — neben Swipe auch visuell sichtbar (Icon/Button)
3. **"Nochmal"-Semantik** klären — Button-Label deutlicher machen ("Neue Vorschläge")

## Existing Patterns
- `DurationPicker` existiert: HStack mit 5m/15m/30m/60m Buttons, wird als Sheet (`.presentationDetents([.height(180)])`) angezeigt
- Wird in `QuickCaptureView`, `BacklogView` verwendet
- Swipe-to-Delete Pattern in Lists ist Standard

## Dependencies
- **Upstream**: `TaskSplitService.suggestSplit()` liefert `[(title, minutes)]`
- **Upstream**: `PlanItem` wird als Input übergeben (aus BacklogHygieneView)
- **Downstream**: `TaskSplitService.persistSplit()` erstellt `LocalTask`s aus Suggestions

## Existing Specs
- Keine separate Spec für TaskSplitView gefunden

## Risks & Considerations
- DurationPicker als Sheet könnte bei mehreren Vorschlägen UX-Probleme verursachen (immer Sheet öffnen?)
- Alternative: Inline Segmented Control oder Tap-to-Cycle für Minuten
- Bestehende UI Tests müssen angepasst werden (neue Identifier für Zeit-Buttons, Löschen-Buttons)
