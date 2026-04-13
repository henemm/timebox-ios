# Spec: Bug #218 — Sprint-Review Notification Cleanup

## Problem
Push-Notification "Zeit für dein Sprint Review!" bleibt im Notification Center, obwohl der User das Sprint Review bereits in-app abgeschlossen hat. Ursache: Kein `removeDeliveredNotifications()` im gesamten Codebase.

## Acceptance Criteria

1. **AC1:** Nach Schließen des Sprint Review Sheets wird die Block-End-Notification aus dem Notification Center entfernt (delivered + pending)
2. **AC2:** Wenn Sprint Review VOR Block-Ende gestartet wird (Early Review / Abort), wird die noch ausstehende (pending) Notification gecancelled
3. **AC3:** Fix gilt für iOS (`FocusLiveView`) UND macOS (`MacFocusView`)
4. **AC4:** Bestehende Notification-Logik (reconcile, andere Notification-Typen) bleibt unverändert

## Technical Approach

### Neue Methode: `NotificationService.cleanupBlockEndNotification(blockID:)`

```swift
static func cleanupBlockEndNotification(blockID: String) {
    let identifier = "\(focusBlockEndPrefix)\(blockID)"
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
}
```

### Call-Sites

**iOS — FocusLiveView.swift:**
- `checkBlockEnd()` (Zeile ~720): Wenn Block endet und Review öffnet
- Abort-Button (Zeile ~368): Wenn User Block abbricht
- "Sprint Review starten" Button (Zeile ~505): Early Review
- `.sheet(onDismiss:)` (Zeile ~146): Swipe-Down Dismiss
- `SprintReviewSheet(onDismiss:)` (Zeile ~160): "Fertig" Button Dismiss

**macOS — MacFocusView.swift:**
- `checkBlockEnd()` (Zeile ~553): Wenn Block endet und Review öffnet
- "Sprint Review starten" Button (Zeile ~319): Early Review
- `loadData()` (Zeile ~431): Wenn past Block gefunden und Review geöffnet
- `MacSprintReviewSheet(onDismiss:)` (Zeile ~73): Dismiss

## Expected Behavior

- Nach Sprint Review Dismiss (Fertig-Button oder Swipe-Down) ist die Block-End-Notification nicht mehr im Notification Center sichtbar
- Wenn alle Tasks vor Block-Ende erledigt sind und der User "Sprint Review starten" klickt, wird die geplante Block-End-Notification gecancelled
- Wenn der User einen Block abbricht, wird die geplante Block-End-Notification gecancelled
- Bei App-Neustart nach Block-Ende wird die delivered Notification beim Öffnen des Sprint Reviews entfernt
- Alle bestehenden Notification-Typen (Morning, Evening, DueDate, Hygiene) funktionieren weiterhin unverändert

## Test Plan

- testCleanupBlockEndNotificationUsesCorrectIdentifier: Methode existiert und ist aufrufbar
- testCleanupIdentifierMatchesBuildIdentifier: Cleanup-Identifier stimmt mit Build-Identifier überein
- testCleanupWithEmptyBlockIDDoesNotCrash: Leere blockID führt nicht zum Crash
- testCleanupIsCallableFromMainActor: Methode ist von MainActor aufrufbar

## Affected Files

| File | Change |
|------|--------|
| `Sources/Services/NotificationService.swift` | +1 Methode (~5 LoC) |
| `Sources/Views/FocusLiveView.swift` | +5 Aufrufe (~5 LoC) |
| `FocusBloxMac/MacFocusView.swift` | +4 Aufrufe (~4 LoC) |
| `FocusBloxTests/BlockEndNotificationCleanupTests.swift` | Unit Tests |

## Scope
- ~20 LoC Produktionscode, 3 Dateien
- ~50 LoC Tests, 1 neue Datei
