# Bug-Analyse: Watch Notification "NextUp" Action wirkt nicht

## Symptom
User klickt auf "NextUp" Button in einer Apple Watch Notification (Task faellig heute).
Nach 1 Stunde ist der Task auf KEINER Plattform (iOS, macOS) in NextUp.

---

## Root Cause (95% Sicherheit)

**Die Watch App hat KEINEN Notification Action Handler.**

Die Watch App (`FocusBloxWatchApp.swift`, 55 Zeilen) registriert:
- KEINEN `UNUserNotificationCenterDelegate`
- KEINE `NotificationActionDelegate`-Instanz
- KEINE `NotificationService.registerDueDateActions()`

**Vergleich:**
| | iOS | macOS | Watch |
|--|-----|-------|-------|
| Delegate registriert | Ja (Zeile 284-287) | Ja (Zeile 218-221) | **NEIN** |
| Actions registriert | Ja | Ja | **NEIN** |
| Handler aktiv | Ja | Ja | **NEIN** |

**Ablauf des Bugs:**
1. iOS plant Notification mit Kategorie `DUE_DATE_INTERACTIVE` + Actions (NextUp, Postpone, Complete)
2. iPhone ist gesperrt → Notification wird an Watch gespiegelt MIT den Action-Buttons
3. User klickt "NextUp" auf Watch
4. watchOS sucht `UNUserNotificationCenterDelegate` in Watch App → **keiner vorhanden**
5. Action wird still ignoriert, Task bleibt unveraendert
6. Auf KEINER Plattform aendert sich etwas

### Warum NICHT iPhone-verarbeitet?
Wenn iPhone die Action verarbeitet haette, waere der Task auf iPhone SOFORT in NextUp
(keine Sync-Verzoegerung fuer lokale Aenderung). User sagt "weder iOS noch macOS" →
Action wurde NIRGENDWO verarbeitet.

---

## Technische Komplikation: Watch Target Isolation

**Kritischer Befund aus dem Challenge:**

Die Watch App nutzt `fileSystemSynchronizedGroups` und kompiliert NUR Dateien aus dem Ordner
`FocusBloxWatch Watch App/`. Der Shared-Code aus `Sources/` ist NICHT im Watch-Target.

Das bedeutet:
- `NotificationActionDelegate` (in `Sources/Services/`) existiert NICHT im Watch-Target
- `NotificationService` (in `Sources/Services/`) existiert NICHT im Watch-Target
- Ein einfaches "4 Zeilen hinzufuegen" reicht NICHT

### Watch hat eigenes LocalTask Model
- `WatchLocalTask.swift` spiegelt das iOS-`LocalTask` 1:1 (gleicher Klassenname, gleiche Felder)
- `isNextUp: Bool`, `nextUpSortOrder: Int?`, `modifiedAt: Date?` — alle vorhanden
- `var id: String { uuid.uuidString }` — kompatibel mit Notification `userInfo["taskID"]`

---

## Fix-Vorschlag

**Neues File im Watch-Target:** `WatchNotificationDelegate.swift`

Minimaler, Watch-spezifischer Handler (~40 Zeilen):
1. `UNUserNotificationCenterDelegate` konform
2. `didReceive response:` Handler extrahiert `taskID` und `actionIdentifier`
3. Holt Task per `FetchDescriptor<LocalTask>(predicate: id == taskID)`
4. Setzt `task.isNextUp = true` / `task.isCompleted = true` / `task.dueDate += 1 Tag`
5. Setzt `task.modifiedAt = Date()`
6. Ruft `context.save()` auf → CloudKit Sync propagiert automatisch

**Plus in `FocusBloxWatchApp.swift`:**
- `@State private var notificationDelegate: WatchNotificationDelegate?`
- Im `.onAppear` von ContentView: Delegate erstellen + registrieren
- Notification-Kategorien registrieren (damit watchOS die Actions kennt)

**Dateien:** 1 neue Datei + 1 Datei aendern = 2 Dateien, ~50 LoC

---

## Blast Radius

### Direkt betroffen (ALLE Watch Notification Actions):
| Action | Status |
|--------|--------|
| "Next Up" | Funktioniert NICHT auf Watch |
| "Morgen" (Postpone) | Funktioniert NICHT auf Watch |
| "Erledigt" (Complete) | Funktioniert NICHT auf Watch |

### Sekundaere Issues (separater Scope):
- `SyncEngine.updateNextUp()` setzt kein `modifiedAt` (betrifft iOS Drag-Drop)
- `CompleteTaskIntent` (Siri) setzt kein `modifiedAt` (betrifft Siri-Completion)

---

## Challenge-Ergebnis

**Verdict nach Challenge: LUECKEN → adressiert**

Offene Punkte die adressiert wurden:
1. Watch Target kompiliert `Sources/` nicht → eigener Watch-Handler noetig (kein Shared-Code-Reuse)
2. `#if !os(macOS)` in NotificationActionDelegate wuerde `updateOverdueBadge` auf watchOS aufrufen → Watch-Handler braucht das nicht
3. watchOS `UNUserNotificationCenterDelegate` funktioniert seit watchOS 7+ identisch
