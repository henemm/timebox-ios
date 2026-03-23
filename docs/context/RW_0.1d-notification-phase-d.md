# Context: RW_0.1d — Smart Notification Engine Phase D (Review/Nudge + Settings UI)

## Request Summary
Phase D fuellt die leeren Stub-Methoden `buildReviewRequests()` und `buildNudgeRequests()` in der SmartNotificationEngine mit echtem Inhalt und fuegt einen Notification-Profil-Picker in die Settings UI (iOS + macOS) ein. Profil-Wechsel triggert reconcile.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/SmartNotificationEngine.swift` | Haupt-Datei: `buildReviewRequests()` (Z311-313) und `buildNudgeRequests()` (Z317-319) sind leere Stubs |
| `Sources/Services/NotificationService.swift` | Enthaelt `build*Request`-Methoden als Referenz-Pattern. Phase D koennte neue `build*`-Methoden hier ergaenzen ODER direkt in der Engine bauen |
| `Sources/Models/AppSettings.swift` | Hat bereits `notificationProfile` Property (Z56-67). Braucht ggf. neue Settings fuer Review-Zeit und Nudge-Intervalle |
| `Sources/Views/SettingsView.swift` | iOS Settings — braucht neue Section fuer Profil-Picker + ggf. Review-Time-Picker |
| `FocusBloxMac/MacSettingsView.swift` | macOS Settings — Notifications Tab (Z259-320) braucht Profil-Picker |
| `Sources/FocusBloxApp.swift` | Ruft reconcile bei scenePhase-Wechsel auf — Profil-Wechsel sollte auch reconcile triggern |
| `FocusBloxTests/SmartNotificationEngineTests.swift` | Phase A Tests |
| `FocusBloxTests/SmartNotificationEnginePhaseBTests.swift` | Phase B Tests |
| `FocusBloxTests/SmartNotificationEnginePhaseCTests.swift` | Phase C Tests |

## Existing Patterns
- Engine nutzt `NotificationService.build*Request()` fuer testbare Request-Erstellung
- Alle build*-Methoden haben `now: Date = Date()` Parameter fuer Testbarkeit
- Budget-Konstanten: budgetReview = 2, budgetNudges = 10
- Reconcile-on-Event: Jede Daten-Mutation triggert Full-Reconcile
- Profil bestimmt welche Prio-Stufen aktiv sind:
  - quiet: nur Prio 1 (Timer)
  - balanced: Prio 1 + 2 (Tasks) + 3 (Review)
  - active: Prio 1 + 2 + 3 + 4 (Nudges)

## Was Review/Nudge laut Story-Spec sein sollen
- **Prio 3 — Review (max 2 Slots):**
  - Evening Reset Nudge ("Zeit fuer dein Tagesreview")
  - Morning Coaching Nudge ("Guten Morgen — dein Tag wartet")
  - ID-Schema: `focusblox.review.{date}`, `focusblox.morning.{date}`
- **Prio 4 — Nudges (max 10 Slots):**
  - Luecken-Vorschlaege (wenn lange nichts passiert)
  - Micro-Task-Nudges (bei Prokrastination)
  - ID-Schema: `focusblox.nudge.{type}.{date}`
  - NUR bei Profil "active"

## Dependencies
- Upstream: `AppSettings` (Profil + neue Review/Nudge-Settings), `NotificationService` (build-Pattern)
- Downstream: Alle Views die `reconcile()` aufrufen (aendern sich NICHT)

## Existing Specs
- `docs/specs/rework/0.1-smart-notification-engine.md` — Original Story
- `docs/specs/rework/0.1-smart-notification-engine-impl.md` — Phase A Spec (done)
- `docs/specs/rework/0.1b-smart-notification-phase-b-impl.md` — Phase B Spec (done)
- `docs/specs/rework/0.1c-smart-notification-phase-c-impl.md` — Phase C Spec (done)

## Analysis

### Type
Feature

### Affected Files (Production Code)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/SmartNotificationEngine.swift | MODIFY | Fill buildReviewRequests() + buildNudgeRequests() stubs, change private→internal, add now: parameter |
| Sources/Views/SettingsView.swift | MODIFY | Add profile picker section + @AppStorage + onChange reconcile trigger |
| FocusBloxMac/MacSettingsView.swift | MODIFY | Add profile picker to notifications tab + @AppStorage + onChange reconcile trigger |

### Test Files (CREATE)
| File | Description |
|------|-------------|
| FocusBloxTests/SmartNotificationEnginePhaseDTests.swift | Unit tests for buildReviewRequests + buildNudgeRequests |
| FocusBloxUITests/SmartNotificationPhaseDUITests.swift | UI tests for profile picker |

### Scope Assessment
- Files: 3 production + 2 test
- Estimated LoC: +130 production, +170 tests
- Risk Level: LOW

### Technical Approach
1. Hardcoded review times (20:00 evening, 08:00 morning) — configurable = later phase
2. Fixed-interval nudges every 2h during work hours (9-19 Uhr) — no ModelContext needed
3. Veralterungssichere Notification-Texte (keine Vorwuerfe, zeitunabhaengig)
4. private static → internal static + now: Date parameter fuer Testbarkeit
5. Profile picker in both Settings with onChange → reconcile(.profileChanged)

### Dependencies
- Upstream: AppSettings (notificationProfile already exists), NotificationService (build-Pattern reference)
- Downstream: No changes to reconcile callers

### Open Questions
- [x] Review-Zeiten hardcoded (20:00 + 08:00) oder konfigurierbar? → Empfehlung: hardcoded
- [x] Nudge-Strategie: feste Intervalle vs. Activity-Gap-Detection? → Empfehlung: feste Intervalle
- [ ] Nudge-Texte auf Deutsch — Henning muss bestätigen

## Risks & Considerations
- Notification-Texte muessen "veralterungssicher" sein (kein "Du hast heute nichts gemacht" das morgen peinlich klingt)
- Nudge-Logik braucht Wissen ueber letzte Aktivitaet — wo kommt das her? Koennte Tasks mit `modifiedAt` oder `completedDate` nutzen
- Review/Morning-Zeiten muessen konfigurierbar sein (AppSettings)
- Settings UI muss auf BEIDEN Plattformen ergaenzt werden (iOS + macOS)
- Profil-Wechsel muss reconcile triggern (`.profileChanged` Reason existiert bereits)
- Budget: Review = 2 Slots, Nudges = 10 Slots — reicht fuer geplanten Inhalt
