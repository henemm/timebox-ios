# Context: EPIC_170c — Smart Nudges

## Request Summary
Nudge-Notifications von 6 festen Uhrzeiten auf konfigurierbares Budget (1-3/Tag) umbauen, mit Stille bei Erfolg, konfigurierbaren Zeiten und intelligentem Timing via BehavioralProfileService.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/SmartNotificationEngine.swift` | `buildNudgeRequests()` (Z.375-415) — 6 feste Slots, muss komplett ersetzt werden. `buildReviewRequests()` (Z.318-371) — Morning 08:00/Evening 20:00 hardcoded, muss konfigurierbar werden |
| `Sources/Models/AppSettings.swift` | Bestehende Nudge-Properties (Z.55-59): `nudgeDailyCount`, `nudgeLastDate`, `nudgeTaskIDs`. Notification-Profile (Z.88-98): quiet/balanced/active |
| `Sources/Services/NotificationContentService.swift` | AI-Content für Morning/Evening existiert. `nudgeFallback()` (Z.138-147) existiert aber wird nicht genutzt |
| `Sources/Services/BehavioralProfileService.swift` | `computeTimeAffinity()` (Z.81-114) — Tageszeit-Affinität pro Kategorie. Nicht mit Nudges verbunden |
| `Sources/Views/SettingsView.swift` | Notification-Profile-Picker (Z.37-48). Keine Nudge-Detail-Settings |
| `FocusBloxTests/SmartNotificationEnginePhaseDTests.swift` | Tests für 6-Slot-Logik (Z.80-148) — müssen angepasst werden |
| `Sources/Services/EmotionalNudgeService.swift` | In-App Modal-Nudges (NICHT Push). Eigenes Budget-System |

## Existing Patterns
- `buildXRequest()` sind pure functions mit `now:` Parameter für Testbarkeit
- Notification-Budget-Caps pro Typ (timers=4, tasks=20, review=14, nudges=10)
- AI-Content via Foundation Models mit Fallback-Templates
- `NotificationProfile` steuert welche Notification-Typen aktiv sind

## Dependencies (Upstream)
- `NotificationContentService` — für Nudge-Inhalte
- `BehavioralProfileService` — für intelligentes Timing
- `AppSettings` — für Konfiguration
- `UNUserNotificationCenter` — für Push-Delivery

## Dependents (Downstream)
- `SmartNotificationEnginePhaseDTests` — Tests müssen angepasst werden
- `SettingsView` — muss neue Nudge-Settings anzeigen
- `NotificationProfile` enum — Definition von "active" ändert sich

## Risks & Considerations
- Budget-Cap `budgetNudges=10` muss auf max 3*7=21 (3 Nudges * 7 Tage) angepasst werden
- `NotificationProfile.active` Definition ändert sich (nicht mehr "alle 2h")
- BehavioralProfile braucht Mindest-Daten (`minTasksForAffinity=10`) — Fallback für neue User nötig
