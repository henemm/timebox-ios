---
entity_id: bug-216-sprint-ende
type: bugfix
created: 2026-04-14
updated: 2026-04-14
status: draft
version: "1.0"
tags: [sprint-review, focus-live, dismiss, platform-both]
---

# Bug #216: Sprint-Ende UX-Probleme

## Approval

- [ ] Approved

## Purpose

Behebt 4 UX-Probleme beim Sprint-Ende: (1) "Abbrechen"-Button nach Sprint-Ende sichtbar, (2) doppelter Dismiss im Review-Dialog, (3) Review-Loop bei Swipe-Down-Dismiss, (4) Review nach Schließen erneut startbar.

## Source

- **File:** `Sources/Views/FocusLiveView.swift`
- **Identifier:** `progressHeader()`, `allTasksCompletedView()`, `.sheet(isPresented: $showSprintReview)`
- **File:** `Sources/Views/SprintReviewSheet.swift`
- **Identifier:** `SprintReviewSheet.body` (Toolbar)
- **File:** `FocusBloxMac/MacFocusView.swift`
- **Identifier:** `allTasksCompletedView()`, `.sheet(isPresented: $showSprintReview)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| FocusBlock | Model | `isPast` Property bestimmt ob Sprint beendet |
| SprintReviewSheet | View | iOS Review-Dialog |
| MacSprintReviewSheet | View | macOS Review-Dialog |
| NotificationService | Service | Notification-Cleanup bei Dismiss |

## Implementation Details

### Fix 1: Abort-Button nur bei laufendem Sprint (iOS)

```swift
// FocusLiveView.swift — progressHeader()
// VORHER: Button immer sichtbar (Zeile 367-382)
// NACHHER: Button nur wenn Sprint noch läuft
if !block.isPast {
    Button {
        isAbortingBlock = true
        // ... existing abort logic
    } label: {
        Label("Abbrechen", systemImage: "xmark.circle")
    }
}
```

### Fix 2: Toolbar "Fertig" entfernen (iOS)

```swift
// SprintReviewSheet.swift — body
// VORHER: Toolbar mit "Fertig" Button (Zeile 83-90)
// NACHHER: Toolbar komplett entfernen
// "Sprint Review beenden" (Zeile 314-328) bleibt als einziger Dismiss-Weg
```

### Fix 3: Swipe-Down-Dismiss-Leck schließen (iOS)

```swift
// FocusLiveView.swift — .sheet(isPresented: $showSprintReview, onDismiss:)
// VORHER: reviewDismissed nur bei isAbortingBlock gesetzt (Zeile 152-155)
// NACHHER: reviewDismissed IMMER setzen
.sheet(isPresented: $showSprintReview, onDismiss: {
    NotificationService.cleanupBlockEndNotification(blockID: blockID)
    reviewDismissed = true  // IMMER setzen
    if isAbortingBlock {
        isAbortingBlock = false
    }
    Task { await loadData() }
})
```

### Fix 4: "Sprint Review starten" mit reviewDismissed-Guard (iOS + macOS)

```swift
// FocusLiveView.swift + MacFocusView.swift — allTasksCompletedView()
// VORHER: Button immer sichtbar
// NACHHER: Nach Review anderen Text zeigen
if reviewDismissed {
    Text("Sprint beendet")
        .font(.subheadline)
        .foregroundStyle(.secondary)
} else {
    Button { showSprintReview = true } label: {
        Text("Sprint Review starten")
    }
}
```

## Expected Behavior

- **Input:** Sprint endet (natürlich oder vorzeitig)
- **Output:**
  - Sprint Review öffnet sich automatisch
  - Ein Dismiss-Button ("Sprint Review beenden")
  - Nach Dismiss: Kein "Abbrechen", kein "Sprint Review starten", stattdessen "Sprint beendet"
  - Swipe-Down schließt Review OHNE Loop
- **Side effects:** Keine — bestehende Logik (Notification-Cleanup, Task-Rücksetzen) bleibt

## Acceptance Criteria

1. Nach Sprint-Ende ist der "Abbrechen"-Button NICHT sichtbar (iOS)
2. SprintReviewSheet hat NUR "Sprint Review beenden" als Dismiss-Weg (kein "Fertig" in Toolbar)
3. Swipe-Down-Dismiss des Review-Sheets öffnet den Dialog NICHT erneut
4. Nach geschlossenem Review zeigt die View "Sprint beendet" statt "Sprint Review starten"
5. Manueller Abort bei LAUFENDEM Sprint funktioniert weiterhin (Regression-Check)
6. macOS: "Sprint Review starten" nach Review nicht mehr verfügbar
7. macOS: Build erfolgreich

## Known Limitations

- Nach Sprint-Ende bleibt der Block als `activeBlock` in der UI bis ein neuer Block aktiv wird oder die App neu geladen wird — das ist bestehendes Verhalten und KEIN Teil dieses Fixes

## Changelog

- 2026-04-14: Initial spec created from Bug #216 analysis
