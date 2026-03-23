# Context: RW_0.2b — BehavioralProfileService Phase B

## Request Summary
Erweiterung des bestehenden BehavioralProfileService um zwei fehlende Komponenten:
**Kalender-Korrelation** (Meeting-Dichte vs. Produktivitaet) und **Verschiebungs-Muster** (chronisch verschobene Tasks).

## Was ist bereits implementiert (RW_0.2)
- Tageszeit-Affinitaet pro Kategorie (`categoryTimeAffinity`)
- Taegliche Kapazitaet (`avgTasksPerDay`, `avgMinutesPerDay`)
- Schaetz-Genauigkeit (`estimationFactor`)
- Cache-Mechanismus (Tages-basiert, in-memory)
- 28-Tage Rolling Window
- Minimum-Schwellen-System (nil bei zu wenig Daten)

## Was fehlt (Scope von 0.2b)
1. **Kalender-Korrelation** (`capacityByMeetingLoad: [MeetingLoad: Double]`)
   - Wie viele Tasks erledigt der User an Tagen mit wenig/mittel/vielen Meetings?
   - MeetingLoad: low (0-2), medium (3-4), high (5+)
2. **Verschiebungs-Muster** (`procrastinationPatterns: [ProcrastinationPattern]`)
   - Tasks mit rescheduleCount >= 3
   - Gemeinsame Merkmale: Kategorie, Importance, Tageszeit

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Models/BehavioralProfile.swift` | Struct erweitern um neue Felder |
| `Sources/Services/BehavioralProfileService.swift` | Neue Berechnungs-Methoden |
| `FocusBloxTests/BehavioralProfileServiceTests.swift` | Tests fuer neue Komponenten |
| `Sources/Models/LocalTask.swift` | Datenquelle: `rescheduleCount`, `importance`, `taskType`, `completedAt` |
| `Sources/Models/CalendarEvent.swift` | Datenquelle: Kalender-Events (startDate, endDate, isAllDay) |
| `Sources/Services/EventKitRepository.swift` | `fetchCalendarEvents(for:)` — liefert Events pro Tag |
| `Sources/Models/TaskCategory.swift` | 5 Kategorien: income, maintenance, recharge, learning, giving_back |

## Existing Patterns
- Service ist `enum` mit `static` methods (kein Instanz-State)
- Schwellen-System: Minimum-Daten-Anzahl, darunter nil
- Methoden-Signatur: `static func compute*(from tasks:, ...) -> Type?`
- Cache: `nonisolated(unsafe) private static var _cache`
- Tests: Helper-Methoden `makeTask()` und `makeBlock()`, klare Kommentare

## Dependencies
- **Upstream:** `LocalTask` (rescheduleCount, importance, taskType, completedAt, isCompleted), `CalendarEvent` (startDate, endDate, isAllDay)
- **Downstream:** Konsumierende Services (NextUpSuggestionService, EmotionalNudgeService, SuccessStoryService — noch nicht implementiert)

## Datenquellen-Details
- `LocalTask.rescheduleCount: Int` — wird bei jedem Postpone inkrementiert
- `LocalTask.importance: Int?` — 1-3 (nil = nicht gesetzt)
- `CalendarEvent` braucht Datum-Range-Query via `EventKitRepository.fetchCalendarEvents(for: Date)`
  - **Achtung:** EventKitRepository braucht Calendar-Permission und ist @Observable
  - Fuer BehavioralProfileService besser: CalendarEvents als Parameter reingeben (wie tasks/focusBlocks), nicht direkt fetchen

## Risks & Considerations
- EventKit-Abhaengigkeit: Service soll kein Netzwerk/externe Dependency haben → CalendarEvents als Input-Parameter, nicht selbst fetchen
- `fetchCalendarEvents(for:)` liefert Events pro einzelnen Tag — fuer 28 Tage braeuchte man 28 Aufrufe. Effizienter: Events als Array reingeben
- MeetingLoad-Klassifikation: Nur Nicht-AllDay-Events zaehlen als "Meetings"
- `rescheduleCount` wird NUR durch `LocalTask.postpone()` erhoeht — Tasks ohne dueDate akkumulieren nie rescheduleCount
- `taskType` kann leer sein ("") — bei Kategorie-Clustering muss nil-Fall behandelt werden

## Analysis

### Type
Feature (Erweiterung bestehender Service)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/BehavioralProfile.swift` | MODIFY | +MeetingLoad enum, +ProcrastinationPattern struct, +2 Felder |
| `Sources/Services/BehavioralProfileService.swift` | MODIFY | +2 compute-Methoden, Signatur-Aenderung compute()/profile() |
| `FocusBloxTests/BehavioralProfileServiceTests.swift` | MODIFY | +6-8 Tests fuer K4+K5 |

### Scope Assessment
- Files: 3
- Estimated LoC: ~209 (Profile: +26, Service: +68, Tests: +115)
- Risk Level: LOW (keine downstream Consumer, reine Erweiterung)

### Technical Approach
1. Neue Types in BehavioralProfile.swift: `MeetingLoad` enum, `ProcrastinationPattern` struct
2. `compute()`/`profile()` Signatur um `calendarEvents: [CalendarEvent]` erweitern
3. `computeCapacityByMeetingLoad()`: Non-AllDay Events pro Tag zaehlen → MeetingLoad-Bucket → avg Tasks pro Bucket
4. `computeProcrastinationPatterns()`: Alle Tasks (nicht nur completed) mit rescheduleCount >= 3 → pro Kategorie clustern

### Design-Entscheidungen
- **ProcrastinationPatterns:** Alle Tasks (auch nicht-completed), kein 28-Tage-Fenster
- **Clustering:** Pro TaskCategory ein Pattern (nicht Kategorie x Importance)
- **MeetingLoad-Schwelle:** Min 3 Tage pro Bucket, fehlende Buckets = absent im Dict
- **ProcrastinationPattern:** Minimum 3 Tasks mit rescheduleCount >= 3 insgesamt, sonst nil

### Dependencies
- Upstream: LocalTask, CalendarEvent, TaskCategory (alle existieren)
- Downstream: Keine (noch keine Consumer implementiert)

### Open Questions
- Keine — alle Design-Fragen beantwortet
