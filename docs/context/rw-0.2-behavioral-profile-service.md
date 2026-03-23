# Context: RW_0.2 BehavioralProfileService

## Request Summary
Deterministischer Service, der aus bestehenden Task-/Kalender-Daten ein Verhaltensprofil berechnet (Tageszeit-Affinitaet, Kapazitaet, Kalender-Korrelation, Schaetzgenauigkeit, Verschiebungs-Muster). Kein LLM, reine Statistik. Wird von zukuenftigen Services konsumiert.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | Primaere Datenquelle: completedAt, taskType, estimatedDuration, rescheduleCount, importance |
| `Sources/Models/TaskCategory.swift` | Enum mit 5 Kategorien (income/maintenance/recharge/learning/giving_back) |
| `Sources/Models/CalendarEvent.swift` | Struct fuer Kalender-Events (startDate, endDate, isAllDay) |
| `Sources/Models/FocusBlock.swift` | FocusBlock mit taskTimes (tatsaechliche Dauer pro Task) |
| `Sources/Models/AppSettings.swift` | Wird erweitert: + lastProfileComputeDate fuer Cache-Invalidierung |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | Protocol fuer Kalender-Zugriff (fetchCalendarEvents) |
| `Sources/Services/CategoryStatsService.swift` | Aehnliches Pattern: statischer Service, arbeitet auf [LocalTask], filtert completed |
| `Sources/Services/SmartNotificationEngine.swift` | Aehnliches Pattern: enum-basierter Service, nutzt ModelContainer + EventKitRepo |
| `Sources/Testing/MockEventKitRepository.swift` | Fuer Unit Tests: Mock des EventKit-Zugriffs |

## Existing Patterns

- **Service als enum:** `CategoryStatsService`, `SmartNotificationEngine` — statische Methoden, kein State
- **Daten-Queries:** Tasks via SwiftData `#Predicate` + `FetchDescriptor`, Events via `EventKitRepositoryProtocol`
- **Testbarkeit:** EventKit wird per Protocol injiziert, SwiftData per in-memory `ModelContainer`
- **TaskCategory:** Enum mit rawValue-Strings matching `LocalTask.taskType`
- **completedAt:** Timestamp wann Task erledigt wurde (nil = nicht erledigt)
- **FocusBlock.taskTimes:** Dictionary [TaskID: Seconds] fuer tatsaechliche Zeiterfassung

## Dependencies (Upstream — was der Service nutzt)

- `LocalTask` (SwiftData Model): completedAt, taskType, estimatedDuration, rescheduleCount, importance
- `FocusBlock` (via EventKitRepository): taskTimes fuer tatsaechliche Dauer
- `CalendarEvent` (via EventKitRepository): Meeting-Counts pro Tag
- `TaskCategory` enum: Fuer Tageszeit-Affinitaet pro Kategorie
- `AppSettings`: Cache-Invalidierung (lastProfileComputeDate)

## Dependents (Downstream — was den Service nutzen wird)

- `NextUpSuggestionService` (RW_2.2): timeAffinityBonus, capacityByMeetingLoad
- `LimitationGuardService` (RW_2.3): avgTasksPerDay, avgMinutesPerDay
- `Tagesansicht` (RW_2.1): Morgen-Modus Task-Vorschlaege
- `EmotionalNudgeService` (RW_3.4): Nudge-Personalisierung
- `SuccessStoryService` (RW_4.2): Profil-Daten fuer Geschichten
- `SmartNotificationEngine` (Phase D Nudges): Spaeter Nudge-Personalisierung

## Existing Specs

- `docs/specs/rework/0.2-behavioral-profile-service.md` — Vollstaendige Spec mit Model-Definition

## Risks & Considerations

1. **Datensparsity:** Erste 14 Tage koennen nicht genug Daten haben → Defaults noetig
2. **Performance:** 28-Tage Rolling Window auf SwiftData-Queries muss < 500ms bleiben
3. **FocusBlock.taskTimes:** Nicht alle Tasks haben tatsaechliche Zeiterfassung → Fallback auf estimatedDuration
4. **EventKit-Zugriff:** Kalender-Berechtigung kann fehlen → graceful degradation bei MeetingLoad
5. **TaskFailureRecord:** Erst mit Epic 4 (RW_4.3) verfuegbar — jetzt noch nicht einbauen
6. **Keine UI:** Reiner Backend-Service, kein Screenshot moeglich/noetig
