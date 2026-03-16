# Context: TD-03 — Services ohne Unit Tests absichern

## Request Summary
Drei Services haben keine Unit Tests: NotificationService, FocusBlockActionService, GapFinder. Sicherheitsnetz fehlt — Regressionen werden nicht erkannt.

## Related Files

### Service-Dateien
| File | Relevance | LoC |
|------|-----------|-----|
| `Sources/Services/NotificationService.swift` | Hauptziel — 40+ statische Methoden, Notifications scheduling | 694 |
| `Sources/Services/FocusBlockActionService.swift` | Hauptziel — Task complete/skip waehrend FocusBlock | 140 |
| `Sources/Models/GapFinder.swift` | Hauptziel — Freie Zeitslots im Kalender finden | 153 |

### Abhaengigkeiten (upstream)
| File | Relevance |
|------|-----------|
| `Sources/Models/CoachType.swift` | NotificationService nutzt Coach-Persoenlichkeit fuer Nudges |
| `Sources/Models/CoachGap.swift` | NotificationService nutzt Gap-Typen fuer Nudge-Texte |
| `Sources/Models/LocalTask.swift` | FocusBlockActionService aendert Task-Status |
| `Sources/Models/FocusBlock.swift` | FocusBlockActionService + GapFinder arbeiten mit Blocks |
| `Sources/Models/CalendarEvent.swift` | GapFinder liest Kalender-Events |
| `Sources/Services/RecurrenceService.swift` | FocusBlockActionService erzeugt wiederkehrende Tasks |
| `Sources/Services/AppSettings.swift` | NotificationService liest Einstellungen (Singleton) |
| `Sources/Testing/MockEventKitRepository.swift` | Mock fuer EventKitRepositoryProtocol (existiert bereits!) |

### Aufrufer (downstream)
| File | Nutzt |
|------|-------|
| `Sources/Views/FocusLiveView.swift` | FocusBlockActionService.completeTask/skipTask |
| `Sources/Views/BlockPlanningView.swift` | GapFinder.findFreeSlots |
| `Sources/Views/BacklogView.swift` | NotificationService (Due-Date Notifications) |
| `Sources/Views/MorningIntentionView.swift` | NotificationService (Coach Reminders) |
| `Sources/FocusBloxApp.swift` | NotificationService (Badge, Permissions) |
| + 5 weitere Views | NotificationService (diverse Notifications) |

## Existing Patterns

### Test-Konventionen im Projekt
- **Ort:** `FocusBloxTests/`
- **Naming:** `test_[subject]_[scenario]_[expectation]`
- **Setup:** `@MainActor`, `ModelContainer(isStoredInMemoryOnly: true)`
- **Mocks:** `MockEventKitRepository` mit Call-Tracking (`deleteCalendarEventCalled`, `lastDeletedEventID`)
- **Imports:** `import XCTest`, `import SwiftData`, `@testable import FocusBlox`

### Referenz-Tests
| Test-Datei | Relevant weil |
|------------|---------------|
| `FocusBloxTests/BadgeOverdueNotificationTests.swift` | Testet bereits NotificationService build-Methoden! |
| `FocusBloxTests/CoachMissionServiceTests.swift` | Factory-Pattern, GIVEN/WHEN/THEN |
| `FocusBloxTests/MockEventKitRepositoryTests.swift` | Mock-Nutzung + Call-Tracking |

## Testbarkeit pro Service

### NotificationService (694 LoC) — MITTEL
- **Gut testbar:** `build*Request()` Methoden (12+) — geben `UNNotificationRequest?` zurueck, kein Seiteneffekt
- **Schwer testbar:** `schedule*()` Methoden — rufen `UNUserNotificationCenter.current().add()` auf
- **Strategie:** build-Methoden testen (Request-Inhalt, Trigger, UserInfo). schedule-Methoden sind Thin-Wrapper.
- **Blocker:** `AppSettings.shared` Singleton — evtl. Testbarkeit eingeschraenkt

### FocusBlockActionService (140 LoC) — MITTEL
- **Gut testbar:** Logik (complete/skip) mit MockEventKitRepository + In-Memory ModelContainer
- **Komplex:** Aendert gleichzeitig Calendar + SwiftData, erzeugt Recurring Tasks
- **Strategie:** MockEventKitRepository injizieren, In-Memory Container, Ergebnis-Enum pruefen

### GapFinder (153 LoC) — EINFACH
- **Pure Logic:** Struct mit Value-Semantik, keine Seiteneffekte
- **Strategie:** CalendarEvent/FocusBlock Fixtures erstellen, Zeitfenster-Arithmetik pruefen
- **Edge Cases:** Heute vs. morgen, ueberlappende Events, leerer Kalender, komplett voller Tag

## Risks & Considerations
- **AppSettings.shared** ist Singleton — Tests koennten sich gegenseitig beeinflussen
- **UNUserNotificationCenter** ist nicht mockbar — deshalb nur build-Methoden testen
- **SwiftData @MainActor** — Tests muessen auf MainActor laufen
- **Scope:** ~987 LoC Service-Code. Tests sollten kritische Pfade abdecken, nicht 100% Coverage anstreben

## Analysis

### Type
Tech Debt — Unit Tests fuer bestehende Services nachruesten

### Reihenfolge (Empfehlung)
1. **GapFinder** — Pure Logic, null Risiko, kein Mock noetig
2. **NotificationService** — 5 untestete build-Methoden, Pattern aus BadgeOverdueNotificationTests folgen
3. **FocusBlockActionService** — MockEventKitRepository muss erweitert werden (updateFocusBlock Call-Tracking fehlt)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxTests/GapFinderTests.swift` | CREATE | ~12-15 Tests: Gap-Erkennung, Duration-Filter, Defaults, Edge Cases |
| `FocusBloxTests/NotificationServiceBuildTests.swift` | CREATE | ~18-22 Tests: 5 build-Methoden + Nudge-Algorithmus + CoachGap-Texte |
| `FocusBloxTests/FocusBlockActionServiceTests.swift` | CREATE | ~10-12 Tests: complete/skip Logik, Blocker, Recurring, Dependents |
| `Sources/Testing/MockEventKitRepository.swift` | MODIFY | updateFocusBlock Call-Tracking hinzufuegen |

### Scope Assessment
- Files: 3 neue + 1 Aenderung = **4 Dateien**
- Estimated: **~40-49 Tests**, +400-500 LoC Test-Code
- Risk Level: **LOW** (nur Tests + Mock-Erweiterung, kein Produktiv-Code)

### Testbare vs. untestbare Methoden

**NotificationService — testbar (build-Methoden):**
- `buildFocusBlockNotificationRequest()` — Trigger, Content, Guard (past dates)
- `buildFocusBlockEndNotificationRequest()` — Content mit completedCount/totalCount
- `buildIntentionReminderRequest()` — Calendar Trigger, repeats, Coach-Attachment
- `buildEveningReminderRequest()` — Time-passed Guard, Calendar Trigger
- `buildDailyNudgeRequests()` — Verteilungs-Algorithmus, 7 CoachGap-Texte, Edge Cases
- Bereits getestet: buildDueDateMorningRequest, buildDueDateAdvanceRequest (in BadgeOverdueNotificationTests)

**NotificationService — NICHT testbar (schedule/cancel):**
- Alle `schedule*()` und `cancel*()` Methoden — rufen UNUserNotificationCenter direkt auf

**FocusBlockActionService — testbar:**
- `completeTask()` — Happy Path, Blocker-Check, Recurring, Dependents
- `skipTask()` — Queue-Reorder, Last-Task-Auto-Complete

**GapFinder — vollstaendig testbar:**
- `findFreeSlots()` — alle Pfade, keine Einschraenkungen
