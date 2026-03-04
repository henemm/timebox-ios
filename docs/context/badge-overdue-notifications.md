# Context: #29 Badge-Zahl (Overdue) + Interaktive Frist-Notifications

## Request Summary
App-Icon Badge soll Anzahl ueberfaelliger Tasks anzeigen. Frist-Notifications (Morgen-Erinnerung + Vorlauf) bekommen 3 interaktive Buttons: NextUp, Verschieben (+1 Tag), Erledigt.

## Analysis

### Type
Feature (NEU)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/NotificationService.swift` | MODIFY | Categories registrieren, userInfo an Due-Date-Notifs, Badge-Update-Methode |
| `Sources/FocusBloxApp.swift` | MODIFY | Delegate setzen, Badge bei Foreground aktualisieren, Category-Registration |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | Delegate setzen, Category-Registration (kein Badge) |

### Scope Assessment
- **Files:** 3 (MODIFY)
- **Estimated LoC:** +120-150
- **Risk Level:** LOW-MEDIUM

### Technical Approach

**1. NotificationService.swift (~60-80 LoC)**
- Neue Methode `registerDueDateActions()`: 3 UNNotificationAction + 1 UNNotificationCategory registrieren
- Neue Methode `updateOverdueBadge(modelContainer:)`: Overdue-Count fetchen + `setBadgeCount()`
- `buildDueDateMorningRequest()` + `buildDueDateAdvanceRequest()`: `categoryIdentifier` + `userInfo["taskID"]` hinzufuegen

**2. FocusBloxApp.swift (~40-50 LoC)**
- `NotificationActionDelegate` als Klasse mit `UNUserNotificationCenterDelegate`
- Delegate haelt Referenz auf `ModelContainer` (fuer SwiftData-Zugriff im Action-Handler)
- 3 Actions routen: NextUp → `isNextUp = true`, Verschieben → `dueDate += 1 Tag`, Erledigt → `isCompleted = true`
- Badge-Update bei `scenePhase == .active` + nach jeder Action
- Category-Registration in `.onAppear`

**3. FocusBloxMacApp.swift (~20-30 LoC)**
- Gleicher Delegate (Notification-Actions funktionieren auf macOS)
- Kein Badge-Update (macOS hat keine App-Icon-Badges)
- Category-Registration in `.onAppear`

**Architektur-Entscheidung: Delegate-Klasse**
- Eigenstaendige Klasse `NotificationActionDelegate: NSObject, UNUserNotificationCenterDelegate`
- Bekommt `ModelContainer` im init → erstellt eigenen `ModelContext` fuer Action-Handling
- Grund: Delegate-Callbacks kommen ausserhalb der SwiftUI View-Hierarchie

### Dependencies
- **Upstream:** UNUserNotificationCenter, SwiftData ModelContainer, LocalTask Model
- **Downstream:** FocusBloxApp + FocusBloxMacApp muessen Delegate setzen
- **Keine neuen Frameworks** noetig (UserNotifications bereits importiert)

### Existing Patterns
- NotificationService ist `@MainActor enum` mit static Methoden
- Due-Date-Notifications haben testbare Builder-Funktionen (`now: Date` Parameter)
- SyncEngine injiziert ModelContext via init
- Badge-Permission wird bereits angefragt (`.badge` in requestAuthorization)
- Overdue-Filter existiert in BacklogView: `dueDate < startOfToday && !isCompleted`

### Existing Specs
- `docs/specs/features/due-date-notifications.md` (draft) — beschreibt aktuelle Notification-Architektur
- `docs/specs/features/focus-block-start-notification.md` (draft) — Builder-Pattern Referenz

### Risks & Considerations
1. **Delegate-Lifecycle:** Delegate-Objekt muss als @State gehalten werden (sonst wird es deallokiert)
2. **Background-Context:** Action-Handler braucht eigenen ModelContext (mainContext evtl. nicht verfuegbar)
3. **macOS:** Kein Badge, aber Actions muessen funktionieren — `#if !os(macOS)` fuer Badge-Code
4. **Badge nach CloudKit-Sync:** Badge auch nach Remote-Changes aktualisieren (remoteChangeCount Observer)
5. **Notification-Limit:** 64 max — aktuell ~61 genutzt, kein Problem (Actions aendern Limit nicht)

### Open Questions
- Keine — alle PO-Fragen bereits geklaert (Badge = Overdue-Count, 3 Buttons, nur Frist-Notifications)
