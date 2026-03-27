# Context: RW_4.4 — Morning Widget

## Request Summary
Lock Screen Widget als passiver Tageseinstieg: Morgens zeigt es freie Zeit + wartende Tasks, abends Erfolgszusammenfassung. Tap oeffnet DayView.

## Related Files

| File | Relevance |
|------|-----------|
| `FocusBloxWidgets/FocusBloxWidgetsBundle.swift` | Widget Bundle — neues Widget hier registrieren |
| `FocusBloxWidgets/QuickCaptureWidget.swift` | Bestehendes Widget — Pattern fuer TimelineProvider, Entry, View |
| `FocusBloxWidgets/FocusBloxWidgets.entitlements` | App Group Entitlement — bereits vorhanden |
| `FocusBloxWidgets/QuickAddTaskControl.swift` | Control Center Widget — Pattern fuer Intents |
| `FocusBloxWidgets/FocusBlockLiveActivity.swift` | Live Activity — anderes Pattern (ActivityKit) |
| `Sources/Services/WidgetRelevanceCalculator.swift` | Relevance-Scoring — erweitern fuer Tageszeit-basierte Relevanz |
| `Sources/Views/DayView.swift` | DayPhase enum (morning/daytime/evening) + Daten-Loading |
| `Sources/Models/GapFinder.swift` | Freie-Zeit-Berechnung — Logik fuer Morgen-Modus |
| `Sources/Services/SuccessStoryService.swift` | RW_4.2 — Abend-Zusammenfassung (fuer Evening-Widget-Text) |
| `Sources/Services/FailureProtocolService.swift` | RW_4.3 — Failure-Daten (optional fuer Kontext) |
| `Sources/Models/PlanItem.swift` | Task-Datenmodell — isCompleted, isNextUp, rescheduleCount |
| `Sources/Models/LocalTask.swift` | SwiftData Model — Abfrage-Basis |
| `Sources/Intents/TaskEntity.swift` | SharedModelContainer — Pattern fuer SwiftData-Zugriff aus Extension |
| `Sources/FocusBloxApp.swift` | Haupt-App — URL-Handling fuer Widget-Tap, App Group Defaults |
| `Resources/FocusBlox.entitlements` | App Entitlements — App Group bereits konfiguriert |

## Existing Patterns

### Widget-Architektur (QuickCaptureWidget)
- `StaticConfiguration` + `TimelineProvider` (kein Intent-basiert)
- Entry mit `TimelineEntryRelevance` fuer Smart Stack
- App Group UserDefaults fuer Daten-Sync (`group.com.henning.focusblox`)
- `widgetURL()` fuer Deep Link bei Tap
- 15-Minuten-Refresh-Intervall
- `.containerBackground(.fill.tertiary, for: .widget)` Styling

### Data Sharing
- App Group: `group.com.henning.focusblox` (in allen Targets konfiguriert)
- `SharedModelContainer.create()` in `TaskEntity.swift` — SwiftData aus Extension
- **Luecke:** Haupt-App schreibt aktuell KEINE `widget_*` Keys in App Group Defaults
- **Luecke:** Kein `WidgetCenter.shared.reloadTimelines()` Aufruf in der App

### DayPhase-Logik (DayView.swift:61-76)
- `.morning` = vor `morningEndHour` (Default 12)
- `.daytime` = zwischen morning und evening
- `.evening` = nach `eveningStartHour` (Default 18)
- AppStorage Keys: `morningEndHour`, `eveningStartHour`

### Daten fuer Widget-Content
- **Morgen:** `GapFinder.findFreeSlots()` → freie Stunden, `nextUpTasks` → wartende Tasks
- **Abend:** `completedTasks.count` vs. Gesamtzahl, `SuccessStoryService.generate()` (aber AI — zu schwer fuer Widget)

## Dependencies

### Upstream (was das Widget braucht)
- `WidgetKit` Framework (bereits im Projekt)
- App Group UserDefaults (bereits konfiguriert)
- `SharedModelContainer` fuer SwiftData-Zugriff (oder UserDefaults-basierter Ansatz)
- DayPhase-Berechnung (kann inline im Widget sein — nur Stunden-Vergleich)
- URL-Scheme `focusblox://` (bereits vorhanden fuer QuickCapture)

### Downstream (was vom Widget abhaengt)
- `FocusBloxWidgetsBundle` — muss neues Widget registrieren
- `WidgetRelevanceCalculator` — sollte Tageszeit-Relevanz unterstuetzen
- Haupt-App — muss bei Task-Aenderungen Widget-Daten in App Group schreiben

## Existing Specs
- `docs/specs/rework/4.4-morning-widget.md` — Akzeptanzkriterien + technische Vorgaben

## Analysis

### Type
Feature (neues UI, iOS-only)

### Decisions
- **UserDefaults via App Group** (nicht SwiftData im Widget) — passt zum QuickCaptureWidget-Pattern
- **Lock Screen only** (`.accessoryRectangular` + `.accessoryInline`) — Spec sagt Lock Screen
- **Widget-Name:** DayStatusWidget (zeigt morgens UND abends Content)
- **Freie Stunden:** Entfaellt in V1 (GapFinder braucht EventKit). Morgen-Text: "X Tasks warten. Aelteste seit Y Tagen."
- **`#if canImport(WidgetKit)`** in allen Shared-Dateien (SyncEngine, FocusBloxApp) — sonst bricht mac-build
- **Timeline:** 3 Entries/Tag (07:00 Morgen, 12:00 Mittag, 18:00 Abend)
- **Commit-Strategie:** Phase A (Daten-Infra) separat, dann Phase B (Widget UI)

### Affected Files

| File | Change Type | Description | LoC |
|------|-------------|-------------|-----|
| `Sources/Services/WidgetDataPublisher.swift` | CREATE | Service: schreibt widget_* Keys in App Group + reloadTimelines() | ~55 |
| `FocusBloxWidgets/DayStatusWidget.swift` | CREATE | Widget + TimelineProvider + View (Lock Screen) | ~155 |
| `FocusBloxWidgets/FocusBloxWidgetsBundle.swift` | MODIFY | DayStatusWidget registrieren | +3 |
| `Sources/FocusBloxApp.swift` | MODIFY | WidgetDataPublisher aufrufen + URL-Handler day-view | +20 |
| `Sources/Services/SyncEngine.swift` | MODIFY | WidgetDataPublisher nach Task-Completion | +5 |

### Scope Assessment
- Files: 5 (2 CREATE, 3 MODIFY)
- Estimated LoC: ~238
- Risk Level: LOW

### App Group Keys (widget_*)
- `widget_nextUpCount` (Int) — Tasks in Next Up, nicht completed
- `widget_completedTodayCount` (Int) — completedAt >= startOfDay
- `widget_totalTodayCount` (Int) — nextUpCount + completedTodayCount
- `widget_oldestWaitingDays` (Int) — max Tage seit createdAt fuer unfinished Next Up
- `widget_lastUpdated` (TimeInterval) — Staleness-Detection

### Risks & Considerations
1. **mac-build:** WidgetKit nicht auf macOS verfuegbar → `#if canImport(WidgetKit)` Guard pflicht
2. **Daten-Aktualitaet:** Timeline-basiert, kann veraltet sein → Texte neutral formulieren (Spec-Requirement)
3. **pbxproj:** Neue Datei muss via python-pbxproj zum FocusBloxWidgetsExtension Target hinzugefuegt werden
