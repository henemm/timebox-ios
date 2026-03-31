# Context: FEATURE_021 — OrganizeMyDay Intent

## Request Summary
App Intent fuer Shortcuts.app / Siri, der automatisch den Tag plant: Kalender-Luecken finden, passende Tasks zuweisen, Next-Up-Liste erstellen. Alles ohne App zu oeffnen.

## Related Files

### Existing Intents Infrastructure (Sources/Intents/)
| File | Relevance |
|------|-----------|
| `Sources/Intents/FocusBloxShortcuts.swift` | AppShortcutsProvider — hier muss neuer Shortcut registriert werden |
| `Sources/Intents/CreateTaskIntent.swift` | Referenz-Intent (einfach, gut strukturiert) |
| `Sources/Intents/GetNextUpIntent.swift` | Gibt Next-Up Tasks zurueck — aehnliche Logik noetig |
| `Sources/Intents/TaskEntity.swift` | TaskEntity + SharedModelContainer — wiederverwendbar |
| `Sources/Intents/FocusBlockEntity.swift` | FocusBlockEntity + Query — evtl. nuetzlich fuer Output |
| `Sources/Intents/TaskEnums.swift` | AppEnum-Definitionen (Importance, Urgency, Category) |

### Day Planning Services (Kernlogik bereits vorhanden)
| File | Relevance |
|------|-----------|
| `Sources/Services/NextUpSuggestionService.swift` | Kernalgorithmus: Ranking von Tasks nach Scoring (Prioritaet, Affinitaet, Reschedule-Bonus) |
| `Sources/Models/GapFinder.swift` | Findet freie Zeitslots zwischen Kalender-Events (06:00-22:00, min 30 Min) |
| `Sources/Services/BehavioralProfileService.swift` | Nutzer-Profil: Kapazitaet, Affinitaeten, Schaetzgenauigkeit (28 Tage Analyse) |
| `Sources/Services/LimitationGuardService.swift` | Warnt bei Ueberplanung (>1.5x historischer Durchschnitt) |

### Data Models
| File | Relevance |
|------|-----------|
| `Sources/Models/PlanItem.swift` | Zentrale Task-Repraesentation mit Scheduling-Feldern |
| `Sources/Models/BehavioralProfile.swift` | Profil-Struct (categoryTimeAffinity, avgTasksPerDay, etc.) |
| `Sources/Views/DayView.swift` | iOS DayView — nutzt dieselbe Logik, die der Intent braucht |

### Infrastructure
| File | Relevance |
|------|-----------|
| `Sources/FocusBloxApp.swift` | App-Init, Container-Setup, Dependency Injection |
| `docs/context/app-group-swiftdata.md` | App Group SwiftData Migration (SharedModelContainer) |
| `docs/context/phase-3f-siri-integration.md` | Etablierte Intent-Patterns und Architektur-Entscheidungen |

## Existing Patterns

### Intent-Architektur
- **4 registrierte Shortcuts** (CreateTask, GetNextUp, CompleteTask, CountOpenTasks)
- **SharedModelContainer** fuer App-Group-Datenzugriff (`group.com.henning.focusblox`)
- **TaskEntity + EntityQuery** fuer Siri/Spotlight Discovery
- **IntentDonationManager** fuer Predictive Shortcuts
- **Error Handling** via `LocalizedStringResource`-basierte Enums

### Day Planning Algorithmus (DayView Morning Mode)
1. `GapFinder.findSlots()` → freie Zeitslots aus Kalender
2. `NextUpSuggestionService.suggestions()` → Tasks nach Score ranken
3. `BehavioralProfileService.profile()` → Nutzer-Affinitaeten einbeziehen
4. `LimitationGuardService.evaluate()` → Ueberplanung pruefen
5. Ergebnis: Liste von Suggestions (Task + Slot + Score)

### Scoring-Algorithmus (NextUpSuggestionService)
- Base: `PlanItem.priorityScore`
- Time Affinity Bonus (1.5-2.0x): Kategorie × Tageszeit aus BehavioralProfile
- Reschedule Bonus (1.0-1.5x): Tasks mit 3+ Verschiebungen
- Max Suggestions: 3-5 (abhaengig von Meeting-Load)

## Dependencies

### Upstream (was der Intent braucht)
- **SwiftData/ModelContainer** via App Group (SharedModelContainer)
- **EventKit** fuer Kalender-Events (Calendar Permission)
- **NextUpSuggestionService** fuer Task-Ranking
- **GapFinder** fuer Zeitslot-Erkennung
- **BehavioralProfileService** fuer Nutzer-Profil
- **LimitationGuardService** fuer Kapazitaets-Check

### Downstream (was den Intent nutzt)
- **FocusBloxShortcuts** (Registrierung der Siri Phrases)
- **Shortcuts.app** (User-sichtbar)
- **Siri** (Sprachsteuerung)
- **Automations** (Shortcuts-Automationen, z.B. morgens um 7)

## Existing Specs
- Kein existierender Spec fuer FEATURE_021
- `docs/context/ITB-F-CaptureContextIntent.md` — FEATURE_022 Analyse (WONT DO wegen iOS Sandbox)
- `docs/context/phase-3f-siri-integration.md` — Intent-Infrastruktur Patterns

## Analysis

### Type
Feature (neuer AppIntent)

### PO-Entscheidungen
- **Read-only:** Intent schlaegt vor, aendert keine Daten
- **Output:** Beides — Sprachausgabe + TaskEntity-Liste fuer Shortcuts-Weiterverarbeitung

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Intents/OrganizeMyDayIntent.swift` | CREATE | Neuer AppIntent: Orchestriert GapFinder + NextUpSuggestion + BehavioralProfile |
| `Sources/Intents/FocusBloxShortcuts.swift` | MODIFY | Neuen AppShortcut mit Siri Phrases registrieren |
| `FocusBloxTests/OrganizeMyDayIntentTests.swift` | CREATE | Unit Tests fuer Kompositionslogik |

### Scope Assessment
- Files: 3 (1 MODIFY, 2 CREATE)
- Estimated LoC: ~220 (+90 Intent, +10 Shortcuts, +120 Tests)
- Risk Level: LOW

### Technical Approach
**Folgt exakt dem GetNextUpIntent-Pattern:**
1. `SharedModelContainer.create()` → `ModelContext` → fetch `[LocalTask]`
2. `EventKitRepository()` → `fetchCalendarEvents()` + `fetchFocusBlocks()`
3. `LocalTask` → `PlanItem` Konvertierung (Initializer existiert)
4. `BehavioralProfileService.profile()` → Nutzer-Affinitaeten
5. `GapFinder(...).findFreeSlots()` → freie Zeitslots
6. `NextUpSuggestionService.suggestions()` → geranktes Ergebnis
7. Return: `[TaskEntity]` + deutscher Dialog

**Alle Services sind Intent-kompatibel ohne Aenderungen:**
- Reine static/struct Methoden, kein SwiftUI, kein @MainActor
- Caches starten kalt im Intent-Prozess (korrekt)
- EventKitRepository: @Observable ignorieren, fetch-Methoden funktionieren standalone

### Dialog-Format (Vorschlag)
- Keine Slots: "Heute sind keine freien Zeitfenster verfuegbar."
- Keine Suggestions: "Du hast N freie Zeitfenster, aber keine passenden Tasks im Backlog."
- Normal: "Du hast N freie Slots heute. Ich schlage vor: Task A, Task B, Task C."
- Max 3 Titel gesprochen, bei mehr: "und N weitere"

### Risiken (alle LOW)
1. **EventKit im Intent-Prozess:** Falls Kalender-Zugriff verweigert → Graceful Degradation (GapFinder hat Default-Fallback fuer leere Tage)
2. **Laufzeit:** Caches starten kalt, aber alle Services sind schnell (<1s). Kein Risiko fuer Intent-Timeout.
3. **LimitationGuard:** Bewusst ausgescoped fuer v1. Spaeter trivial ergaenzbar.

### Dependencies
- Upstream: SharedModelContainer, EventKitRepository, NextUpSuggestionService, GapFinder, BehavioralProfileService (alle existieren)
- Downstream: FocusBloxShortcuts (Registrierung), Shortcuts.app, Siri
- Keine neuen Permissions, Entitlements oder Dependencies noetig

### Open Questions
- [x] Read-only oder Daten aendern? → **Read-only** (PO-Entscheidung)
- [x] Output-Format? → **Beides: Dialog + TaskEntity-Liste** (PO-Entscheidung)
- [ ] Dialog-Wording bestaetigen (siehe Vorschlag oben)
