# Context: FEATURE_031 — iOS App Icon Quick Actions

## Anfrage
iOS Long-Press auf App-Icon (Quick Actions) für FocusBlox implementieren.

## User-Erwartung (bestätigt)
3 Quick Actions:
1. **Task notieren** — Quick Capture Sheet direkt öffnen
2. **Sprint starten** — Next-Up Tasks als Sheet, antippen startet Sprint
3. **Heute** — DayView Tab öffnen

## Bestehende Infrastruktur
- URL-Scheme `focusblox://` registriert in Info.plist
- `onOpenURL` Handler in FocusBloxApp.swift (Z.401-410): `day-view`, `create-task`, `focus-block/{id}`
- Quick Capture Sheet existiert vollständig (QuickCaptureView.swift)
- `FocusBlockActionService.startImmediate()` für Sprint-Start
- `isNextUp` Flag auf PlanItem für Next-Up Tasks
- NextUpSection.swift zeigt Next-Up Tasks mit Sprint-Button

## Technische Entscheidungen
- **Statische Quick Actions** in Info.plist (kein AppDelegate nötig)
- Neuer URL-Case `focusblox://sprint-picker` für Sprint-Sheet
- Sprint-Picker: Zeigt Next-Up Tasks, Antippen startet Sprint direkt
- 3 Dateien, ~120 LoC
