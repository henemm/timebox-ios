# Feature: Kalender-App Deep Link

## Zusammenfassung
Aus der Timeline/BlockPlanningView soll man direkt in die Kalender-App springen koennen, um ein Event zu sehen/bearbeiten.

## Kontext
- Events werden in der Timeline angezeigt, aber es gibt keinen Weg in die native Kalender-App zu springen
- Apple bietet keinen event-spezifischen Deep Link — `calshow:` oeffnet nur zu einem Datum
- Auf macOS funktioniert `calshow:` ebenfalls (oeffnet Calendar.app am entsprechenden Tag)

## Verhalten

### CalendarEvent.openInCalendarApp()
- Neue Methode auf `CalendarEvent` (Shared Code in `Sources/Models/`)
- Oeffnet die Kalender-App am Tag des Events via `calshow:{unixTimestamp}`
- Cross-Platform: iOS nutzt `UIApplication.shared.open()`, macOS nutzt `NSWorkspace.shared.open()`

### iOS — EventCategorySheet (SharedSheets.swift)
- Neuer Button "In Kalender oeffnen" am Ende der Category-Liste
- Nur fuer externe Events (NICHT fuer FocusBlocks: `!event.isFocusBlock`)
- Ruft `event.openInCalendarApp()` auf und dismisst das Sheet

### iOS — PlanningView.swift
- Neuer Button "In Kalender oeffnen" im bestehenden confirmationDialog
- Nur fuer externe Events (`!event.isFocusBlock`)

### macOS — EventCategorySheet (SharedSheets.swift)
- Gleicher Button wie iOS (SharedSheets.swift ist Shared Code, `#if os()` Branches existieren)

## Scope
- **Dateien:** 3 (CalendarEvent.swift, SharedSheets.swift, PlanningView.swift)
- **LoC:** ~30

## Nicht enthalten
- Event-spezifischer Deep Link (Apple bietet das nicht an)
- Deep Link aus FocusBlocks (die werden in unserer App verwaltet)
