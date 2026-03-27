# Context: RW_2.2 — KI-gestuetzte Tagesvorschlaege

## Request Summary
Morgens 3-5 Task-Vorschlaege basierend auf freien Kalender-Slots, Verhaltens-Profil und Task-Prioritaet generieren. Vorschlaege erscheinen in der bestehenden DayView (Morning-Modus).

## Related Files

### Neue Dateien (zu erstellen)
| Datei | Beschreibung |
|-------|-------------|
| `Sources/Services/NextUpSuggestionService.swift` | Orchestriert BehavioralProfile + GapFinder + TaskPriorityScoringService |
| `Sources/Views/MorningCoachingSection.swift` | UI fuer Vorschlaege im Morning-Modus |

### Bestehende Services (werden konsumiert, nicht geaendert)
| Datei | Relevanz |
|-------|----------|
| `Sources/Services/BehavioralProfileService.swift` | Liefert timeAffinity, capacity, procrastinationPatterns |
| `Sources/Services/TaskPriorityScoringService.swift` | Deterministisches Scoring (0-100) mit Eisenhower + Deadline + Neglect |
| `Sources/Services/AITaskScoringService.swift` | Optional: Apple Intelligence Scoring (nicht Kern-Logik) |
| `Sources/Models/GapFinder.swift` | Findet freie Kalender-Slots (TimeSlot) |

### Bestehende Models (werden konsumiert)
| Datei | Relevanz |
|-------|----------|
| `Sources/Models/LocalTask.swift` | Core Model: estimatedDuration, blockerTaskID, rescheduleCount, isNextUp, taskType |
| `Sources/Models/PlanItem.swift` | Read-only ViewModel mit computed priorityScore |
| `Sources/Models/BehavioralProfile.swift` | Profil-Struct: categoryTimeAffinity, capacityByMeetingLoad, procrastinationPatterns |
| `Sources/Models/TaskCategory.swift` | income/maintenance/recharge/learning/giving_back |

### Bestehende Views (werden geaendert)
| Datei | Aenderung |
|-------|-----------|
| `Sources/Views/DayView.swift` | Morning-Modus: MorningCoachingSection einbinden, loadMorningData erweitern |

### Bestehende Services (Daten-Zugriff)
| Datei | Relevanz |
|-------|----------|
| `Sources/Services/SyncEngine.swift` | sync() liefert [PlanItem], updateNextUp() setzt isNextUp-Flag |

## Existing Patterns

- **GapFinder** wird bereits in DayView.loadMorningData() genutzt — gleicher Aufruf fuer Suggestions
- **TaskPriorityScoringService** wird in PlanItem.priorityScore aufgerufen — Score ist bereits berechnet
- **BehavioralProfileService** hat In-Memory-Cache mit Tages-Invalidierung — passt zu "einmal pro Tag berechnen"
- **SyncEngine.updateNextUp()** setzt isNextUp-Flag + scheduledDate — Aktion bei Tap auf Suggestion
- **NextUpSection** zeigt Tasks mit isNextUp-Flag — Suggestions nutzen gleichen Mechanismus

## Dependencies

### Upstream (was der neue Service braucht)
- `BehavioralProfileService.profile()` → categoryTimeAffinity, capacityByMeetingLoad
- `GapFinder.findFreeSlots()` → [TimeSlot]
- `PlanItem.priorityScore` → Int (0-100)
- `SyncEngine.sync()` → [PlanItem] (alle offenen Tasks)

### Downstream (was den neuen Service konsumiert)
- `DayView` Morning-Modus → zeigt MorningCoachingSection
- `SyncEngine.updateNextUp()` → wird bei Tap auf Suggestion aufgerufen

## Existing Specs
- `docs/specs/rework/2.2-next-up-suggestions.md` — Haupt-Spec (bereits gelesen)
- `docs/specs/rework/0.2-behavioral-profile-impl.md` — BehavioralProfile Implementation

## Existing Tests (Referenz)
- `FocusBloxTests/BehavioralProfileServiceTests.swift`
- `FocusBloxTests/GapFinderTests.swift`
- `FocusBloxTests/TaskPriorityScoringServiceTests.swift`
- `FocusBloxUITests/DayViewUITests.swift`

## Scoring-Formel (aus Spec)
```
score = priorityScore (0-100)
      x timeAffinityBonus (aus BehavioralProfile.categoryTimeAffinity)
      x rescheduleBonus (chronic procrastination boost)
```

## Risiken & Ueberlegungen
- **Leere Vorschlaege:** Ohne Tasks oder ohne Kalender-Zugriff gibt es keine Suggestions → Graceful Empty State
- **Performance:** < 200ms Berechnung laut Spec — deterministisches Scoring ist schnell genug
- **Cache-Invalidierung:** Bei Task-Aenderungen (isNextUp, completed) muss Cache invalidiert werden
- **Meeting-Load-Korrelation:** An Meeting-lastigen Tagen weniger/kuerzere Tasks vorschlagen
- **Tasks ohne estimatedDuration:** Muessen gefiltert oder mit Default behandelt werden
- **BehavioralProfile braucht [LocalTask]:** loadMorningData() hat nur [PlanItem] — braucht zusaetzlichen SwiftData-Fetch fuer rohe LocalTask-Objekte (~5 LoC)

---

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/NextUpSuggestionService.swift` | CREATE | Orchestriert Scoring: priorityScore x timeAffinityBonus x rescheduleBonus, ~80 LoC |
| `Sources/Views/MorningCoachingSection.swift` | CREATE | UI fuer Suggestions mit Tap-to-confirm + Swipe-to-dismiss, ~70 LoC |
| `Sources/Views/DayView.swift` | MODIFY | @State suggestions + Service-Call in loadMorningData() + MorningCoachingSection rendern, ~25 LoC |
| `FocusBloxTests/NextUpSuggestionServiceTests.swift` | CREATE | Unit Tests fuer Scoring-Logik + Filterung + Cache, ~60 LoC |
| `FocusBloxUITests/DayViewUITests.swift` | MODIFY | Morning-Coaching-Tests erweitern, ~30 LoC |

### Scope Assessment
- Files: 5 (3 new, 2 modified)
- Estimated LoC: ~265 (knapp am 250-Limit)
- Risk Level: LOW

### Technical Approach
- NextUpSuggestionService als `enum` mit static methods (Pattern von BehavioralProfileService)
- In-memory Cache mit Tages-Invalidierung (gleiche Strategie wie BehavioralProfileService)
- NextUpSuggestion als Value-Type (struct) im selben File
- MorningCoachingSection als eigene View mit `[NextUpSuggestion]` Input + Callbacks
- Confirm-Action nutzt bestehendes `SyncEngine.updateNextUp()`
- Accessibility IDs: `morningCoachingSection`, `suggestionRow_<taskID>`, `confirmSuggestion_<taskID>`

### Dependencies (alle ERLEDIGT)
- RW_0.2 BehavioralProfileService ✅
- RW_0.2b Kalender-Korrelation ✅
- RW_2.1a DayView Skeleton ✅
- RW_2.1b DayView Morning Mode ✅

### Open Questions
Keine — alle Abhaengigkeiten sind fertig, Spec ist klar.
