# Context: Bug #218 — Sprint-Review Hinweis kommt obwohl erledigt

## Request Summary
Push-Notification "Zeit für dein Sprint Review!" erscheint, obwohl der User das Sprint Review bereits abgeschlossen hat.

## Root Cause Hypothese
`SmartNotificationEngine.buildTimerRequests()` plant eine "focus-block-end-{blockID}" Notification für den Block-Ende-Zeitpunkt. Wenn der Block endet und der User das Sprint Review in-app abschließt, bleibt die **bereits zugestellte** Notification im Notification Center. `reconcile()` ruft nur `removeAllPendingNotificationRequests()` auf — **delivered Notifications werden nie entfernt**.

Zusätzlich: Wenn der User das Sprint Review VOR Block-Ende startet (z.B. über "Sprint Review starten" Button bei "Alle Tasks erledigt"), wird die geplante End-Notification trotzdem noch zugestellt.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/SmartNotificationEngine.swift` | Baut block-end Notifications in `buildTimerRequests()` |
| `Sources/Services/NotificationService.swift` | `buildFocusBlockEndNotificationRequest()` — "Zeit für dein Sprint Review!" Text |
| `Sources/Views/FocusLiveView.swift:146-175` | Sprint Review Sheet dismiss — setzt `reviewDismissed = true` aber entfernt keine Notifications |
| `Sources/Views/FocusLiveView.swift:710-747` | `checkBlockEnd()` — zeigt Sprint Review automatisch, entfernt keine Notifications |
| `FocusBloxMac/MacFocusView.swift` | macOS-Pendant — gleiches Problem |

## Existing Patterns
- `reconcile()` entfernt alle PENDING Notifications und baut neu
- `cancelFocusBlockNotification()` existiert in NotificationService, entfernt pending (nicht delivered)
- Kein `removeDeliveredNotifications()` irgendwo im Codebase

## Dependencies
- Upstream: `UNUserNotificationCenter` (Apple API)
- `EventKitRepository` für Block-Daten

## Risks & Considerations
- Fix muss BEIDE Plattformen abdecken (iOS + macOS)
- `removeDeliveredNotifications(withIdentifiers:)` ist die Apple API um zugestellte Notifications zu entfernen
- Muss auch den Fall abdecken, wo User Sprint Review VOR Block-Ende startet (Early-Review)
