# BUG-DEP-4b: Blockierte Tasks ueber Siri/Shortcuts + Notification erledigen

## Bug-Beschreibung
**Symptom:** Blockierte Tasks (blockerTaskID != nil) koennen ueber Siri, Shortcuts, Notification-Actions und Focus-Block-UI erledigt werden, ohne dass der Blocker-Guard greift.

**Plattform:** iOS + macOS + watchOS

**Zweites Problem entdeckt:** CompleteTaskIntent, NotificationActionDelegate, WatchNotificationDelegate und FocusBlockActionService rufen `freeDependents()` NICHT auf. Wenn ein BLOCKER-Task ueber diese Pfade erledigt wird, bleiben seine Dependents dauerhaft blockiert.

---

## Agenten-Ergebnisse (Zusammenfassung)

### Agent 1: Wiederholungs-Check
- DEP-4 fixte 4 UI-Level Guards (TaskInspector, nextUpTasks Filter, Context Menu, FocusBlock-Zuweisung)
- DEP-4b wurde bewusst als separates Ticket ausgelagert
- macOS Keyboard Shortcut ist BEREITS geschuetzt (geht durch markTasksCompleted() mit Guard)

### Agent 2: Datenfluss-Trace
- CompleteTaskIntent.perform(): Setzt isCompleted direkt ohne Guard UND ohne freeDependents
- SyncEngine.completeTask(): Kein Guard, ABER hat freeDependents-Aufruf
- macOS Keyboard -> markTasksCompleted() -> HAT Guard

### Agent 3: Alle Schreiber (korrigiert nach Devil's Advocate)

| # | Pfad | Datei:Zeile | Guard | freeDependents | Status |
|---|------|-------------|-------|----------------|--------|
| 1 | SyncEngine.completeTask() | SyncEngine.swift:160 | NEIN | JA | Fix noetig |
| 2 | CompleteTaskIntent.perform() | CompleteTaskIntent.swift:30 | NEIN | NEIN | Fix noetig |
| 3 | NotificationActionDelegate | NotificationActionDelegate.swift:78 | NEIN | NEIN | Fix noetig |
| 4 | WatchNotificationDelegate | WatchNotificationDelegate.swift:113 | NEIN | NEIN | Fix noetig |
| 5 | FocusBlockActionService | FocusBlockActionService.swift:50 | NEIN | NEIN | Fix noetig |
| 6 | BacklogView.completeTask() (iOS) | BacklogView.swift:755 | UI geschuetzt | via SyncEngine | OK (blockedRow hat kein onComplete) |
| 7 | LocalTaskSource.markComplete() | LocalTaskSource.swift:75 | NEIN | NEIN | Dead Code (nur Tests) |
| 8 | markTasksCompleted() (macOS) | ContentView.swift:864 | JA | via SyncEngine | OK |

### Agent 4: Szenarien
5 echte Bypass-Szenarien (korrigiert):
1. Siri Sprachbefehl / Shortcuts App (CompleteTaskIntent)
2. Notification "Erledigt"-Button (iOS)
3. Watch Notification "Erledigt"-Action
4. Focus Block Complete-Button (iOS + macOS — MacFocusView:461 bestaetigt)
5. FocusBlockActionService direkt

### Agent 5: Blast Radius
- Root Cause: Guard nur im UI-Layer (macOS ContentView), nicht im Domain-Layer
- Intents/Notifications umgehen SyncEngine komplett — kein Guard UND kein freeDependents
- MacFocusView nutzt FocusBlockActionService.completeTask() (bestaetigt Zeile 461)

---

## Devil's Advocate Korrekturen

1. **BacklogView.completeTask() (iOS) ist NICHT ungeschuetzt** — blockedRow() uebergibt kein onComplete-Callback. Schutz liegt im View-Rendering, nicht im Function-Guard. Aus Fix-Liste entfernt.
2. **LocalTaskSource.markComplete() ist Dead Code** — kein Produktions-Aufrufer, nur Tests. Ignoriert.
3. **Verwaiste Abhaengigkeiten:** Wenn ein Guard `blockerTaskID == nil` in SyncEngine eingefuegt wird, koennten Tasks mit verwaistem blockerTaskID (Blocker ist schon erledigt aber freeDependents lief nie) dauerhaft gesperrt sein. Loesung: Guard prueft ob der Blocker EXISTIERT UND NICHT erledigt ist.

---

## Hypothesen

### Hypothese A: Completion-Pfade umgehen SyncEngine — HOCH (100%)
CompleteTaskIntent, NotificationActionDelegate, WatchNotificationDelegate setzen isCompleted direkt. Kein Guard, kein freeDependents. Bewiesen durch Code-Inspektion.

### Hypothese B: SyncEngine selbst hat keinen Guard — HOCH (100%)
SyncEngine.completeTask() prueft blockerTaskID nicht. Bewiesen durch Code Zeile 160.

### Hypothese C: Direkte Pfade fehlen auch freeDependents — HOCH (100%)
NEUER BEFUND: Grep nach freeDependents/blockerTaskID in allen 4 direkten Pfaden = 0 Treffer. Wenn ein Blocker-Task ueber Siri erledigt wird, bleiben Dependents dauerhaft blockiert.

---

## Fix-Empfehlung (aktualisiert)

**Beste Loesung: Direkte Pfade durch SyncEngine leiten** (Zentralisierung statt Guard-Duplikation)

| # | Aenderung | Datei | Was |
|---|-----------|-------|-----|
| 1 | Guard in completeTask() | SyncEngine.swift | `guard task.blockerTaskID == nil` (mit Orphan-Check) |
| 2 | SyncEngine nutzen statt direkt | CompleteTaskIntent.swift | perform() ruft SyncEngine.completeTask() auf |
| 3 | SyncEngine nutzen statt direkt | NotificationActionDelegate.swift | actionComplete ruft SyncEngine auf |
| 4 | SyncEngine nutzen statt direkt | WatchNotificationDelegate.swift | actionComplete ruft SyncEngine auf |
| 5 | Guard in completeTask() | FocusBlockActionService.swift | Kann SyncEngine nicht nutzen (EventKit), Guard + freeDependents |

**Vorteile:**
- Guard NUR an einer Stelle (SyncEngine) — kein Auseinanderlaufen
- freeDependents automatisch fuer alle Pfade
- Undo-Capture automatisch fuer alle Pfade
- Siri-Intent-Donation automatisch

**Geschaetzt:** ~5 Dateien, ~50-80 LoC

---

## Blast Radius

- SyncEngine-Guard schuetzt alle zukuenftigen Aufrufer automatisch
- FocusBlockActionService braucht eigenen Guard (EventKit-Update nicht in SyncEngine)
- Siri: Soll Dialog "Task ist blockiert durch [Blocker-Name]" zurueckgeben
- Notification: Stilles Ignorieren (kein Dialog moeglich bei Notification-Action)
- Orphan-Schutz: Guard prueft ob Blocker existiert UND nicht erledigt — verwaiste blockerTaskIDs werden toleriert
