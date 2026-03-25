# Context: RW_2.1b — DayView Phase B: Morgen-Modus

## Request Summary

Der Morgen-Modus in der DayView soll mit echtem Content befuellt werden: Kompakte Kalender-Uebersicht mit freien Luecken (visuell hervorgehoben) und eine Task-Liste fuer den Tag. Task-Vorschlaege (Story 2.2) kommen spaeter — hier nur die Infrastruktur + manuelle Task-Anzeige.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/DayView.swift` | **HAUPTDATEI** — Morgen-Platzhalter ersetzen durch echten Content |
| `Sources/Models/GapFinder.swift` | Findet freie Zeitslots zwischen Kalender-Events + FocusBlocks |
| `Sources/Models/CalendarEvent.swift` | Kalender-Event Model |
| `Sources/Models/LocalTask.swift` | Task-Model mit scheduledDate, isScheduled, isNextUp |
| `Sources/Models/TimelineItem.swift` | Timeline-Item fuer scheduled Tasks |
| `Sources/Views/TimelineView.swift` | Bestehende Timeline-View (Referenz fuer UI-Patterns) |
| `Sources/Views/BlockPlanningView.swift` | Referenz: Wie Kalender + Tasks geladen werden (loadData Pattern) |
| `Sources/Views/ScheduledTaskBlock.swift` | Scheduled Task UI-Block (wiederverwendbar) |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | fetchCalendarEvents(for:), fetchFocusBlocks(for:) |
| `Sources/Helpers/EventKitRepositoryEnvironment.swift` | Environment-Key fuer EventKitRepository |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Task-Quelle (SwiftData) |
| `Sources/Views/MainTabView.swift` | Tab-Navigation (keine Aenderung noetig) |
| `FocusBloxMac/SidebarView.swift` | macOS Sidebar (keine Aenderung in Phase B) |
| `FocusBloxUITests/DayViewUITests.swift` | Bestehende UI Tests — muessen erweitert werden |
| `FocusBloxTests/DayPhaseTests.swift` | Bestehende Unit Tests fuer DayPhase |
| `FocusBloxTests/GapFinderTests.swift` | Bestehende Unit Tests fuer GapFinder |

## Existing Patterns

### Daten laden (BlockPlanningView Pattern)
```swift
@Environment(\.eventKitRepository) private var eventKitRepo
@Environment(\.modelContext) private var modelContext

func loadData() async {
    let hasAccess = try await eventKitRepo.requestAccess()
    calendarEvents = try eventKitRepo.fetchCalendarEvents(for: date)
    focusBlocks = try eventKitRepo.fetchFocusBlocks(for: date)
    let taskSource = LocalTaskSource(modelContext: modelContext)
    let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
    allTasks = try await syncEngine.sync()
}
```

### GapFinder Nutzung
```swift
let gapFinder = GapFinder(events: calendarEvents, focusBlocks: focusBlocks, scheduledTasks: [...], date: date)
let freeSlots = gapFinder.findFreeSlots(minMinutes: 30, maxMinutes: 60)
```

### Scheduled Tasks filtern (BlockPlanningView)
```swift
allTasks.filter { $0.isScheduled && $0.scheduledDate! >= dayStart && $0.scheduledDate! < dayEnd }
```

## Dependencies

### Upstream (was unser Code nutzt)
- `EventKitRepository` — Kalender-Events + FocusBlocks
- `LocalTaskSource` / `SyncEngine` — Tasks laden
- `GapFinder` — freie Luecken berechnen
- `CalendarEvent`, `FocusBlock`, `LocalTask` Models
- `TimeSlot` — Ergebnis von GapFinder

### Downstream (was unseren Code nutzt)
- `MainTabView` — bindet DayView als Tab ein (bereits vorhanden)
- `SidebarView` (macOS) — bindet DayView ein (bereits vorhanden)
- Phase C (RW_2.1c) wird auf dem Morgen-Modus aufbauen
- Phase D (RW_2.1d) wird Abend-Modus aufbauen

## Existing Specs

- `docs/specs/rework/2.1-day-view.md` — Haupt-Spec fuer alle DayView-Phasen
- `docs/specs/rework/2.1a-day-view-skeleton.md` — Phase A Spec (bereits implementiert)

## Risks & Considerations

1. **EventKit Permissions** — DayView braucht Kalender-Zugriff. BlockPlanningView hat bereits ein Permission-Handling-Pattern → wiederverwenden
2. **Performance** — Kalender-Daten werden bei jedem Phasen-Wechsel geladen. EventKitRepository cached bereits
3. **Kein NextUpSuggestionService** — existiert noch nicht (Story 2.2). Morgen-Modus zeigt nur Kalender-Luecken + existierende "Next Up" Tasks, keine KI-Vorschlaege
4. **Leerer State** — Spec verlangt: "Keine Vorschlaege — plan deinen Tag selbst" mit Link zu Backlog
5. **macOS** — Phase B aendert nur shared Code in Sources/Views. macOS DayView nutzt dieselbe View
6. **Bestehende UI Tests** — DayViewUITests pruefen aktuell auf Platzhalter-Texte ("Kalender-Uebersicht kommt bald"). Diese muessen angepasst werden
7. **macOS: UIApplication.openSettingsURLString** ist iOS-only — `#if os(iOS)` Guard noetig beim Permission-Button

---

## Analysis

### Type
Feature

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/DayView.swift` | MODIFY | Morning-Platzhalter ersetzen durch echten Content (Kalender + Gaps + Tasks + Loading/Permission/Empty States) |
| `FocusBloxUITests/DayViewUITests.swift` | MODIFY | Bestehende Platzhalter-Tests anpassen + neue Verhaltens-Tests fuer Morning Content |

### Scope Assessment
- Files: 2 (keine neuen Dateien)
- Estimated LoC: +~160 (120 DayView + 40 Tests)
- Risk Level: LOW

### Technical Approach

**Alles inline in DayView.swift — kein MorningCoachingSection.swift noetig.**

**Part A — State + Loading:**
- `@Environment(\.eventKitRepository)` + `@Environment(\.modelContext)` hinzufuegen
- `@State` fuer calendarEvents, focusBlocks, nextUpTasks, freeSlots, isLoading, isPermissionDenied
- `.task { if phase == .morning { await loadMorningData() } }` auf NavigationStack

**Part B — morningContent View:**
1. Loading: `ProgressView("Lade Kalender...")`
2. Permission denied: `ContentUnavailableView` + Settings-Button (`#if os(iOS)`)
3. Empty: `ContentUnavailableView("Keine Vorschlaege")` + Link zu Backlog
4. Content: `ScrollView { VStack { Kalender-Events, Freie Luecken, Next Up Tasks } }`

**Part C — loadMorningData():**
- BlockPlanningView-Pattern: requestAccess → fetchCalendarEvents → fetchFocusBlocks → SyncEngine.sync() → GapFinder
- Filter: nextUpTasks = tasks.filter { $0.isNextUp && !$0.isCompleted && $0.isActionable }
- Kein cleanOrphanedBlockAssignments (nicht noetig fuer read-only Anzeige)

**Part D — Tests:**
- Bestehender test_dayView_showsPhaseContent geht RED (erwartet Platzhalter-Text)
- Neue Tests: Morning-Content sichtbar, Empty-State bei keine Events/Tasks

### Dependencies
- Upstream: EventKitRepository, SyncEngine, LocalTaskSource, GapFinder, PlanItem, CalendarEvent, FocusBlock, TimeSlot
- Downstream: RW_2.1c (Timeline), RW_2.1d (Abend), RW_2.2 (NextUpSuggestions)

### Open Questions
Keine — alles klar.
