---
entity_id: bug-39-focusblock-lifecycle
type: bugfix
created: 2026-02-12
status: draft
workflow: bug-39-focusblock-lifecycle
---

# Bug 39: FocusBlock Lifecycle nach Block-Ende

## Approval

- [ ] Approved by PO

## Problem

Nach Ablauf eines FocusBlox passiert folgendes FALSCH:
1. Focus Tab zeigt nichts mehr an (Block verschwindet)
2. Unerledigte Tasks werden nicht nach "Next Up" zurueckgelegt
3. Abgelaufene Bloecke erscheinen noch im "Zuweisen" Tab
4. Keine Push-Notification fuer Sprint Review

## Root Cause

1. `FocusLiveView/MacFocusView`: `activeBlock = blocks.first { $0.isActive }` → Nach Ende ist `isActive = false`, also `activeBlock = nil`
2. Kein Mechanismus existiert um unerledigte Tasks zurueck nach Next Up zu verschieben
3. `TaskAssignmentView/MacAssignView`: Zeigt ALLE Bloecke ohne Filter
4. `NotificationService`: Hat keinen Notification-Typ fuer "Block beendet"

## Scope

- **Files:** 5 Dateien
- **Estimated:** ~150 LoC

## Implementation Details

### Fix 1: Focus Tab zeigt abgelaufenen Block fuer Review

`FocusLiveView.swift` + `MacFocusView.swift`: Block-Auswahl aendern:
```swift
// Statt nur isActive, auch kuerzlich abgelaufene Bloecke zeigen
activeBlock = blocks.first { $0.isActive }
    ?? blocks.filter { $0.isPast }.last // Letzter abgelaufener Block des Tages
```
Abgelaufener Block wird im "Review-Modus" gezeigt (Sprint Review Sheet automatisch oeffnen).

### Fix 2: Unerledigte Tasks nach Next Up

Nach Sprint Review Dismiss: Alle Tasks die NICHT in `completedTaskIDs` sind,
werden per `LocalTask.isNextUp = true` zurueck in Next Up verschoben.

Timing-Regel: Tasks werden zurueckgelegt wenn:
- Sprint Review Sheet geschlossen wird, ODER
- 15 Minuten nach Block-Ende (automatisch, falls Review uebersprungen)

### Fix 3: Zuweisen filtert abgelaufene Bloecke

`TaskAssignmentView.swift` + `MacAssignView.swift`:
```swift
// Nur zukuenftige und aktive Bloecke anzeigen
focusBlocks = allBlocks.filter { !$0.isPast }
```

### Fix 4: Push-Notification fuer Sprint Review

`NotificationService.swift`: Neue Methode `scheduleFocusBlockEndNotification()`:
- Trigger: Zum Block-Ende-Zeitpunkt
- Titel: "FocusBlox beendet"
- Body: "Zeit fuer dein Sprint Review! X/Y Tasks erledigt."
- Wird beim Erstellen/Bearbeiten eines FocusBlocks geplant

### Betroffene Dateien

1. `Sources/Views/FocusLiveView.swift` - Block-Auswahl + Task-Ruecklegung
2. `FocusBloxMac/MacFocusView.swift` - Block-Auswahl + Task-Ruecklegung
3. `Sources/Views/TaskAssignmentView.swift` - Filter abgelaufene Bloecke
4. `FocusBloxMac/MacAssignView.swift` - Filter abgelaufene Bloecke
5. `Sources/Services/NotificationService.swift` - Block-Ende Push

## Test Plan

### Unit Tests

- [ ] Test 1: Block-Ende Notification wird korrekt erstellt
- [ ] Test 2: Abgelaufene Bloecke werden aus Zuweisen gefiltert
- [ ] Test 3: Unerledigte Tasks haben isNextUp nach Review Dismiss

## Acceptance Criteria

- [ ] Focus Tab zeigt abgelaufenen Block nach Ende (fuer Sprint Review)
- [ ] Unerledigte Tasks gehen nach Review zurueck in Next Up
- [ ] Zuweisen zeigt keine abgelaufenen Bloecke
- [ ] Push-Notification bei Block-Ende
- [ ] Funktioniert auf iOS UND macOS
- [ ] Build kompiliert ohne Errors
- [ ] Alle Tests gruen
