---
entity_id: badge-overdue-notifications
type: feature
created: 2026-03-04
updated: 2026-03-04
status: draft
version: "1.0"
tags: [notifications, badge, overdue, interactive]
---

# Badge-Zahl (Overdue) + Interaktive Frist-Notifications

## Approval

- [ ] Approved

## Purpose

Zwei Erweiterungen des bestehenden Notification-Systems:
1. **App-Icon Badge:** Zeigt Anzahl ueberfaelliger Tasks als rote Zahl am App-Icon (nur iOS)
2. **Interaktive Frist-Notifications:** Due-Date-Notifications bieten 3 Buttons: NextUp, Verschieben (+1 Tag), Erledigt

## Scope

| File | Change Type | Est. LoC | Description |
|------|-------------|----------|-------------|
| `Sources/Services/NotificationService.swift` | MODIFY | ~60 | Category-Registration, userInfo an Due-Date-Notifs, Badge-Update |
| `Sources/FocusBloxApp.swift` | MODIFY | ~50 | NotificationActionDelegate, Badge bei Foreground + Remote-Change |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | ~25 | NotificationActionDelegate (ohne Badge) |
| `FocusBloxTests/BadgeOverdueNotificationTests.swift` | CREATE | ~80 | Unit Tests |
| `FocusBloxUITests/BadgeOverdueUITests.swift` | CREATE | ~40 | UI Tests |

- **Estimated total:** ~130 LoC (ohne Tests), ~250 LoC (mit Tests)
- **Risk Level:** LOW-MEDIUM

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NotificationService` | module | Bestehende Due-Date-Notification-Builder erweitern |
| `LocalTask` | model | dueDate, isCompleted, isNextUp fuer Overdue-Query + Actions |
| `UNUserNotificationCenter` | system | Categories, Actions, Badge, Delegate |
| `ModelContainer` | system | SwiftData-Zugriff im Action-Handler |

## Implementation Details

### Teil 1: Notification Categories + Actions

Neue Methode in `NotificationService`:

```swift
// MARK: - Interactive Due Date Actions

private static let dueDateInteractiveCategory = "DUE_DATE_INTERACTIVE"

static let actionNextUp = "ACTION_NEXT_UP"
static let actionPostpone = "ACTION_POSTPONE"
static let actionComplete = "ACTION_COMPLETE"

/// Registriert Notification-Category mit 3 Actions fuer Due-Date-Notifications.
/// Muss einmal beim App-Start aufgerufen werden.
static func registerDueDateActions() {
    let nextUp = UNNotificationAction(
        identifier: actionNextUp,
        title: "Next Up",
        options: []
    )
    let postpone = UNNotificationAction(
        identifier: actionPostpone,
        title: "Morgen",
        options: []
    )
    let complete = UNNotificationAction(
        identifier: actionComplete,
        title: "Erledigt",
        options: .destructive
    )

    let category = UNNotificationCategory(
        identifier: dueDateInteractiveCategory,
        actions: [nextUp, postpone, complete],
        intentIdentifiers: [],
        options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([category])
}
```

### Teil 2: userInfo + categoryIdentifier an Due-Date-Notifications

Bestehende Builder-Methoden erweitern:

```swift
// In buildDueDateMorningRequest():
content.categoryIdentifier = dueDateInteractiveCategory
content.userInfo = ["taskID": taskID]

// In buildDueDateAdvanceRequest():
content.categoryIdentifier = dueDateInteractiveCategory
content.userInfo = ["taskID": taskID]
```

### Teil 3: Badge-Update (nur iOS)

Neue Methode in `NotificationService`:

```swift
/// Zaehlt ueberfaellige Tasks und setzt App-Icon-Badge.
/// Overdue = dueDate < startOfToday AND !isCompleted AND !isTemplate
#if !os(macOS)
static func updateOverdueBadge(container: ModelContainer) {
    let context = ModelContext(container)
    let startOfToday = Calendar.current.startOfDay(for: Date())

    let descriptor = FetchDescriptor<LocalTask>(
        predicate: #Predicate<LocalTask> {
            $0.dueDate != nil && !$0.isCompleted && !$0.isRecurringTemplate
        }
    )

    do {
        let tasks = try context.fetch(descriptor)
        let overdueCount = tasks.filter { $0.dueDate! < startOfToday }.count
        UNUserNotificationCenter.current().setBadgeCount(overdueCount)
    } catch {
        print("Failed to update overdue badge: \(error)")
    }
}
#endif
```

**Hinweis:** `#Predicate` kann keine lokalen Variablen (startOfToday) verwenden, daher wird im Predicate nur auf `dueDate != nil` gefiltert und der Vergleich mit `< startOfToday` im Swift-Code gemacht.

### Teil 4: NotificationActionDelegate

Eigenstaendige Klasse in `FocusBloxApp.swift` (iOS) und `FocusBloxMacApp.swift` (macOS):

```swift
final class NotificationActionDelegate: NSObject, UNUserNotificationCenterDelegate {
    let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let taskID = userInfo["taskID"] as? String else {
            completionHandler()
            return
        }

        Task { @MainActor in
            let context = container.mainContext
            let descriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate { $0.id == taskID }
            )
            guard let task = try? context.fetch(descriptor).first else {
                completionHandler()
                return
            }

            switch response.actionIdentifier {
            case NotificationService.actionNextUp:
                task.isNextUp = true
                task.nextUpSortOrder = (try? context.fetch(
                    FetchDescriptor<LocalTask>(
                        predicate: #Predicate { $0.isNextUp && !$0.isCompleted },
                        sortBy: [SortDescriptor(\LocalTask.nextUpSortOrder, order: .reverse)]
                    )
                ).first?.nextUpSortOrder ?? 0) + 1 ?? 1

            case NotificationService.actionPostpone:
                if let currentDue = task.dueDate {
                    let newDue = Calendar.current.date(byAdding: .day, value: 1, to: currentDue)!
                    task.dueDate = newDue
                    NotificationService.cancelDueDateNotifications(taskID: taskID)
                    NotificationService.scheduleDueDateNotifications(
                        taskID: taskID, title: task.title, dueDate: newDue
                    )
                }

            case NotificationService.actionComplete:
                task.isCompleted = true
                task.completedAt = Date()
                task.assignedFocusBlockID = nil
                task.isNextUp = false
                NotificationService.cancelDueDateNotifications(taskID: taskID)

            default:
                break
            }

            task.modifiedAt = Date()
            try? context.save()

            #if !os(macOS)
            NotificationService.updateOverdueBadge(container: container)
            #endif

            completionHandler()
        }
    }

    // Notification im Vordergrund anzeigen (optional, aber gutes UX)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

### Teil 5: Integration in FocusBloxApp.swift (iOS)

```swift
// Property:
@State private var notificationDelegate: NotificationActionDelegate?

// In .onAppear:
NotificationService.registerDueDateActions()
let delegate = NotificationActionDelegate(container: sharedModelContainer)
UNUserNotificationCenter.current().delegate = delegate
notificationDelegate = delegate  // retain

// In .onChange(of: scenePhase) bei .active:
NotificationService.updateOverdueBadge(container: sharedModelContainer)

// In .onChange(of: syncMonitor.remoteChangeCount):
NotificationService.updateOverdueBadge(container: sharedModelContainer)
```

### Teil 6: Integration in FocusBloxMacApp.swift (macOS)

```swift
// Property:
@State private var notificationDelegate: NotificationActionDelegate?

// In .onAppear:
NotificationService.registerDueDateActions()
let delegate = NotificationActionDelegate(container: container)
UNUserNotificationCenter.current().delegate = delegate
notificationDelegate = delegate  // retain

// Kein Badge-Update (macOS hat keine App-Icon-Badges)
```

## Expected Behavior

### Badge
- **Input:** App wird aktiv (Foreground) oder Remote-Change kommt
- **Output:** Rote Zahl am App-Icon = Anzahl Tasks mit `dueDate < heute` AND `!isCompleted` AND `!isRecurringTemplate`
- **Sonderfaelle:** 0 ueberfaellige → Badge verschwindet, macOS → kein Badge

### Notification Actions
- **Input:** User tippt auf Action-Button in Frist-Notification
- **Output:**
  - "Next Up": Task wird zu NextUp hinzugefuegt (`isNextUp = true`, sortOrder = max+1)
  - "Morgen": Due-Date wird um 1 Tag verschoben, Notifications rescheduled
  - "Erledigt": Task wird als abgeschlossen markiert, Notifications storniert
- **Side Effects:** Badge wird nach jeder Action aktualisiert (iOS)

## Edge Cases

- **Task bereits geloescht:** Action-Handler findet Task nicht → silent ignore
- **Task bereits completed:** Erledigt-Action ist No-Op (schon erledigt)
- **Task bereits NextUp:** NextUp-Action ist idempotent (sortOrder wird aktualisiert)
- **Task ohne dueDate:** Kann nicht passieren (Notifications werden nur fuer Tasks mit dueDate gescheduled)
- **Recurring Task completed:** Keine neue Instanz erzeugt (RecurrenceService laeuft nur ueber SyncEngine.completeTask, nicht hier). **Akzeptabler Trade-off:** User muss App oeffnen fuer naechste Instanz, oder Recurring-Support wird spaeter ergaenzt.

## Known Limitations

- **macOS:** Kein App-Icon-Badge (Plattform-Limitation). Notification-Actions funktionieren.
- **Recurring Tasks:** "Erledigt"-Action erzeugt keine naechste recurring Instanz (dafuer muesste SyncEngine.completeTask aufgerufen werden, was einen vollstaendigen SyncEngine braucht). Kann als Follow-up ergaenzt werden.
- **Background App Refresh:** Badge wird nur bei Foreground + Remote-Change aktualisiert, nicht periodisch im Background.

## Test Plan

### Unit Tests — `FocusBloxTests/BadgeOverdueNotificationTests.swift`

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 1 | `buildDueDateMorningRequest_hasCategoryAndUserInfo` | taskID "abc", dueDate morgen | `buildDueDateMorningRequest()` | `categoryIdentifier == "DUE_DATE_INTERACTIVE"`, `userInfo["taskID"] == "abc"` |
| 2 | `buildDueDateAdvanceRequest_hasCategoryAndUserInfo` | taskID "xyz", dueDate in 2h | `buildDueDateAdvanceRequest()` | `categoryIdentifier == "DUE_DATE_INTERACTIVE"`, `userInfo["taskID"] == "xyz"` |
| 3 | `registerDueDateActions_registersCategory` | — | `registerDueDateActions()` | `UNUserNotificationCenter` hat 1 Category mit 3 Actions |
| 4 | `postponeAction_shiftsDueDateByOneDay` | Task mit dueDate heute 18:00 | Postpone-Action ausgefuehrt | `task.dueDate == morgen 18:00` |
| 5 | `completeAction_marksTaskCompleted` | Task mit isCompleted == false | Complete-Action ausgefuehrt | `task.isCompleted == true`, `task.isNextUp == false` |
| 6 | `nextUpAction_setsIsNextUp` | Task mit isNextUp == false | NextUp-Action ausgefuehrt | `task.isNextUp == true`, `task.nextUpSortOrder > 0` |

### UI Tests — `FocusBloxUITests/BadgeOverdueUITests.swift`

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 1 | `testOverdueTasksVisibleInBacklog` | Task mit dueDate gestern existiert | Backlog oeffnen, Priority View | "Ueberfaellig" Section sichtbar mit Task |
| 2 | `testCompletingOverdueTaskRemovesFromSection` | Overdue Task in Backlog | Task als erledigt markieren (Swipe) | Task verschwindet aus "Ueberfaellig" Section |

## Acceptance Criteria

- [ ] Due-Date-Notifications haben `categoryIdentifier` "DUE_DATE_INTERACTIVE"
- [ ] Due-Date-Notifications enthalten `userInfo["taskID"]`
- [ ] 3 Action-Buttons sichtbar: "Next Up", "Morgen", "Erledigt"
- [ ] "Next Up" setzt `isNextUp = true` mit korrektem `nextUpSortOrder`
- [ ] "Morgen" verschiebt `dueDate` um +1 Tag und rescheduled Notifications
- [ ] "Erledigt" setzt `isCompleted = true` und storniert Notifications
- [ ] App-Icon-Badge zeigt Anzahl ueberfaelliger Tasks (iOS)
- [ ] Badge aktualisiert bei Foreground + Remote-Change
- [ ] Badge = 0 entfernt die rote Zahl
- [ ] macOS: Actions funktionieren, kein Badge
- [ ] Alle Unit Tests gruen
- [ ] Alle UI Tests gruen

## Changelog

- 2026-03-04: Initial spec created
