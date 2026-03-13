# Context: Phase 3f — Siri Integration / App Intents

## Request Summary
Zwei neue Siri-Intents fuer den Monster Coach: (1) "Wie war mein Tag?" liest die Abend-Auswertung vor, (2) "Setz meine Intention auf Fokus" setzt die Tages-Intention per Siri.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Intents/FocusBloxShortcuts.swift` | AppShortcutsProvider — hier kommen 2 neue Siri-Phrasen rein |
| `Sources/Intents/CreateTaskIntent.swift` | Referenz-Pattern fuer Intent mit SwiftData-Zugriff |
| `Sources/Intents/GetNextUpIntent.swift` | Referenz-Pattern fuer Intent mit ProvidesDialog |
| `Sources/Intents/TaskEnums.swift` | Pattern fuer AppEnum — brauchen IntentionOptionEnum |
| `Sources/Models/DailyIntention.swift` | Model mit IntentionOption Enum + UserDefaults save/load |
| `Sources/Services/IntentionEvaluationService.swift` | evaluateFulfillment() + fallbackTemplate() — Kern-Logik fuer Intent 1 |
| `Sources/Services/EveningReflectionTextService.swift` | AI-Text-Generierung — NICHT im Intent nutzbar (MainActor + FoundationModels) |
| `Sources/Views/EveningReflectionCard.swift` | UI-Referenz fuer angezeigte Daten |
| `Sources/Views/MorningIntentionView.swift` | Wie Intention aktuell gesetzt wird (UI-Flow) |
| `Sources/Views/DailyReviewView.swift` | Wo Abend-Auswertung angezeigt wird |
| `Sources/Models/AppSettings.swift` | coachModeEnabled + Coach-Settings |
| `Sources/Services/NotificationService.swift` | Nudge-Scheduling nach Intention-Set |
| `Sources/FocusBloxApp.swift` | updateAppShortcutParameters() Aufruf |

## Existing Patterns

### App Intents Pattern (etabliert)
- Alle Intents in `Sources/Intents/`
- `openAppWhenRun: false` fuer Hintergrund-Intents
- SwiftData via `SharedModelContainer.create()` (App Group)
- Return: `some IntentResult & ReturnsValue<X> & ProvidesDialog`
- `FocusBloxShortcuts` registriert Siri-Phrasen
- `AppEnum` fuer Parameter-Typen (siehe TaskEnums.swift)

### DailyIntention Persistence
- `UserDefaults.standard` mit Key `"dailyIntention_yyyy-MM-dd"`
- `IntentionOption` Enum: survival, fokus, bhag, balance, growth, connection
- `save()` / `load()` als statische Methoden

### Evaluation Pattern
- `IntentionEvaluationService.evaluateFulfillment()` — reine Funktion, nimmt Arrays
- `FulfillmentLevel`: fulfilled / partial / notFulfilled
- `fallbackTemplate(intention:level:)` — vorgefertigte deutsche Texte (17 Kombinationen)

## Dependencies
- **Upstream:** DailyIntention, IntentionEvaluationService, SharedModelContainer, LocalTask, FocusBlock
- **Downstream:** FocusBloxShortcuts (neue Phrasen), DailyIntention (UserDefaults-Migration)

## Existing Specs
- Keine Spec fuer Phase 3f vorhanden
- Monster Coach Story: `docs/project/stories/monster-coach.md`

## Risks & Considerations

### KRITISCH: UserDefaults.standard vs App Group
- `DailyIntention.save()/load()` nutzen `UserDefaults.standard`
- Intent-Prozess hat EIGENE `UserDefaults.standard` — kann App-Daten NICHT lesen
- **Muss migriert werden** auf `UserDefaults(suiteName: "group.com.henning.focusblox")`
- Betrifft: `DailyIntention.swift`, `MorningIntentionView.swift`, `DailyReviewView.swift`

### EventKit im Intent-Prozess
- `GetEveningSummaryIntent` braucht FocusBlocks fuer fokus-Evaluation
- EventKit-Zugriff im Intent-Prozess unklar (Entitlements muessen stimmen)
- **Fallback:** Leeres FocusBlock-Array → 5 von 6 Intentionen funktionieren trotzdem, nur "fokus" degradiert

### AppEnum fuer IntentionOption
- Neues `IntentionOptionEnum: AppEnum` noetig — Siri braucht typisierte Parameter
- Muss alle 6 Optionen mit deutschen Siri-Titeln abbilden

### Scope
- 3 neue Dateien + 2 modifizierte = 5 Dateien (innerhalb Limit)
- UserDefaults-Migration ist die groesste Aenderung (betrifft mehrere Stellen)

---

## Analysis

### Type
Feature (Phase 3f — Monster Coach Siri Integration)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/DailyIntention.swift` | MODIFY | App Group UserDefaults Migration (save/load) |
| `Sources/Intents/FocusBloxShortcuts.swift` | MODIFY | 2 neue AppShortcut-Eintraege |
| `Sources/Intents/GetEveningSummaryIntent.swift` | CREATE | Intent: "Wie war mein Tag?" |
| `Sources/Intents/SetDailyIntentionIntent.swift` | CREATE | Intent: "Setz meine Intention auf X" |
| `Sources/Intents/IntentionOptionEnum.swift` | CREATE | AppEnum fuer Siri-Parameter |

### Scope Assessment
- Files: 5 (3 CREATE + 2 MODIFY)
- Estimated LoC: +~180 / -~5
- Risk Level: MEDIUM (UserDefaults-Migration betrifft bestehende Funktionalitaet)

### Technical Approach

**Empfehlung: UserDefaults-Migration zuerst, dann Intents**

1. **DailyIntention.swift migrieren:** `save()/load()` auf `UserDefaults(suiteName: "group.com.henning.focusblox")` umstellen. Einmalige Migration bestehender Daten von `.standard` beim ersten Load.
2. **IntentionOptionEnum erstellen:** `AppEnum` mit allen 6 Optionen + deutschen DisplayRepresentations.
3. **GetEveningSummaryIntent:** Laedt Intention (App Group), Tasks (SharedModelContainer), FocusBlocks (EventKit mit Fallback). Nutzt `IntentionEvaluationService.evaluateFulfillment()` + `fallbackTemplate()`. Spricht kombiniertes Ergebnis per Dialog.
4. **SetDailyIntentionIntent:** Nimmt `IntentionOptionEnum` Parameter, speichert in App Group UserDefaults, bestaetigt per Dialog.
5. **FocusBloxShortcuts:** 2 neue `AppShortcut` Eintraege mit deutschen Siri-Phrasen.

**Kein Foundation-Models/AI im Intent:** Siri-Antworten nutzen die vorhandenen `fallbackTemplate()`-Texte (17 deutsche Templates). AI-Texte gibt es nur in der App-UI.

### Dependencies

**Upstream (was die neuen Intents brauchen):**
- `DailyIntention` — Model + Persistence (MUSS migriert werden)
- `IntentionEvaluationService` — Pure Functions, keine Aenderung noetig
- `SharedModelContainer` — SwiftData App Group Zugriff (existiert)
- `EventKitRepository` — FocusBlock-Fetch (existiert, Fallback bei Auth-Fehler)
- `LocalTask` / `FocusBlock` — Datenmodelle (existieren)

**Downstream (was sich aendert):**
- `MorningIntentionView` — liest/schreibt DailyIntention → automatisch korrekt nach Migration
- `DailyReviewView` — liest DailyIntention → automatisch korrekt nach Migration
- `FocusBloxApp` — Shortcut-Parameter Update (existiert bereits)

**Entitlements:** App Group `group.com.henning.focusblox` in allen 7 Targets vorhanden — keine Aenderung noetig.

### Open Questions
- Keine — alle Abhaengigkeiten geklaert, Patterns etabliert
