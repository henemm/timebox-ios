# Bug-Analyse: Watch NextUp-Aktion kommt nicht bei iOS/macOS an

## Bug-Beschreibung (Symptome)
1. **Problem A:** Watch-Notification → "NextUp" Aktion → Task erscheint NICHT in NextUp auf iOS/macOS
2. **Problem B:** iOS zeigt einen *anderen* Task in NextUp, der auf macOS nicht sichtbar ist

## Bisherige Fix-Versuche
- **Commit `5202817` (9. Marz 2026):** WatchNotificationDelegate erstellt + in `.onAppear` registriert
- **Status:** Henning meldet: "erfolglos" — das Problem besteht weiterhin

---

## Agenten-Ergebnisse (5 parallele Untersuchungen)

### Agent 1: Wiederholungs-Check
- 13 NextUp-bezogene Commits, 7 Watch-bezogene Commits gefunden
- Letzter relevanter Fix: `5202817` — WatchNotificationDelegate erstellt
- Davor: Watch hatte GAR KEINEN Notification-Handler → Aktionen waren komplett wirkungslos
- Fix-Ansatz war korrekt (Delegate erstellen), aber Registrierung moeglicherweise zu spaet

### Agent 2: Datenfluss-Trace
- Watch: `WatchNotificationDelegate.handleAction()` → `task.isNextUp = true` → `context.save()`
- iOS: `BacklogView` liest via `SyncEngine.sync()` → manuelles Refresh bei `cloudKitMonitor.remoteChangeCount`
- macOS: `ContentView` liest via `@Query` → auto-refresh bei `cloudKitMonitor.remoteChangeCount` + `modelContext.save()`
- Kette: Watch save() → CloudKit → iOS/macOS empfaengt Remote-Change → Refresh

### Agent 3: Alle Schreiber
- 18 Produktions-Schreibstellen fuer `isNextUp`
- Watch schreibt direkt auf Properties (kein SyncEngine)
- iOS-Notification-Handler schreibt ebenfalls direkt (gleicher Pattern wie Watch)

### Agent 4: Failure-Szenarien
- **Kritisch:** Watch `try? context.save()` schluckt Fehler still
- **Kritisch:** Watch hat KEINEN CloudKitSyncMonitor → empfaengt keine Remote-Changes
- **Kritisch:** Watch-Complete nutzt NICHT SyncEngine → keine RecurrenceService-Aufrufe
- Watch kann in lokalen-only Modus fallen (`.cloudKitDatabase: .none` Fallback)

### Agent 5: Blast Radius
- 3 von 4 Watch-Notification-Aktionen haben Implementierungs-Divergenz zu iOS
- Nur `actionNextUp` ist identisch implementiert (direkte Property-Zuweisung)
- `actionPostpone` fehlt `rescheduleCount` Inkrement
- `actionComplete` fehlt RecurrenceService + UndoService

---

## Hypothesen

### Hypothese 1: Delegate-Registrierung zu spaet (HOECHSTE Wahrscheinlichkeit)

**Beschreibung:** `WatchNotificationDelegate` wird in `.onAppear` des ContentView registriert. Wenn die Watch-App NICHT im Vordergrund ist (Standard-Fall bei Notification-Aktionen), feuert `.onAppear` moeglicherweise NACH dem Notification-Action-Dispatch.

**Apple-Dokumentation:**
> "You must assign your delegate object to the UNUserNotificationCenter object before your app finishes launching."

In SwiftUI bedeutet das: im `init()` des `@main` App-Struct, NICHT in `.onAppear`.

**Beweis DAFUER:**
- `FocusBloxWatchApp.swift` Zeile 54-58: Delegate wird in `.onAppear` gesetzt
- Wenn Watch-App nicht laeuft und Notification-Aktion kommt → App wird gestartet → `didReceive` wird VOR `.onAppear` aufgerufen → Delegate ist nil → Aktion wird still verworfen
- Erklaert KOMPLETTEN Ausfall der Watch-Notification-Aktionen
- Der gleiche Pattern existiert auf iOS (`FocusBloxApp.swift` Zeile 289-291), funktioniert dort aber "zufaellig" weil iOS die View schneller rendert

**Beweis DAGEGEN:**
- Wenn der User die Watch-App offen hat WAEHREND er die Notification bekommt, wuerde `.onAppear` schon gefeuert haben und es wuerde funktionieren
- iOS nutzt denselben Pattern und dort scheinen Notification-Aktionen zu funktionieren (kein Complaint)

**Wahrscheinlichkeit: HOCH**

### Hypothese 2: Task nicht im Watch-SwiftData-Store (CloudKit-Sync-Verzoegerung)

**Beschreibung:** Die Notification wird von iOS geplant, aber der zugehoerige Task ist moeglicherweise noch nicht auf die Watch synchronisiert. `context.fetch(descriptor).first` liefert nil → stille Rueckkehr ohne Aktion.

**Beweis DAFUER:**
- CloudKit-Sync zur Watch ist bekannt fuer Verzoegerungen
- Watch-App muss mindestens einmal geoeffnet worden sein damit CloudKit synct
- `guard let task = try? context.fetch(descriptor).first else { return }` (Zeile 77) — stille Rueckkehr bei nil
- WatchOS killt Apps aggressiver → weniger Sync-Moeglichkeiten im Hintergrund

**Beweis DAGEGEN:**
- Wenn die Watch die Notification empfaengt, war sie mit dem iPhone verbunden
- Tasks die schon laenger existieren sollten synchronisiert sein
- Der User erhaelt die Notification = er interagiert mit der Watch = App wird gestartet = CloudKit sollte synchen

**Wahrscheinlichkeit: MITTEL**

### Hypothese 3: Watch-Container im lokalen-only Fallback (kein CloudKit)

**Beschreibung:** `FocusBloxWatchApp.swift` Zeile 33-34: Wenn App Group nicht verfuegbar, faellt Container auf `.cloudKitDatabase: .none` zurueck. Alle Saves sind lokal und synchen nie.

**Beweis DAFUER:**
- Expliziter Fallback-Code existiert
- `try?` schluckt Container-Erstellungsfehler
- Kein User-Feedback wenn Fallback aktiviert wird

**Beweis DAGEGEN:**
- App Group sollte bei korrektem Provisioning immer verfuegbar sein
- Watch-App kann grundsaetzlich Tasks empfangen (zeigt sie an) → CloudKit funktioniert zumindest zum LESEN
- Betrifft eher Entwicklungsumgebung als Production

**Wahrscheinlichkeit: NIEDRIG**

### Hypothese 4: iOS/macOS NextUp-Divergenz (erklaert Problem B)

**Beschreibung:** iOS und macOS nutzen verschiedene Daten-Zugriffsmuster:
- iOS: Manuelles Fetch via `SyncEngine.sync()`, aktualisiert bei `remoteChangeCount`
- macOS: `@Query` mit Auto-Refresh, Cache-Invalidierung via `modelContext.save()`

Wenn CloudKit-Sync zeitversetzt ankommt oder einer der Refresh-Mechanismen versagt, zeigen iOS und macOS unterschiedliche NextUp-Tasks.

**Beweis DAFUER:**
- Unterschiedliche Implementierungen (manuell vs. @Query)
- iOS `BacklogView` hat 200ms Delay vor Refresh (Zeile 343)
- macOS `ContentView` hat eigenen 200ms Delay + `modelContext.save()` (Zeile 574-575)
- Keine Garantie dass beide gleichzeitig den gleichen State sehen

**Beweis DAGEGEN:**
- Beide ueberwachen `cloudKitMonitor.remoteChangeCount`
- CloudKit-Sync sollte innerhalb von Sekunden auf verbundenen Geraeten ankommen
- Wenn es NUR um Timing geht, wuerde ein manuelles Refresh (Pull-to-Refresh) das Problem loesen

**Wahrscheinlichkeit: MITTEL (erklaert Symptom B, nicht Symptom A)**

---

## Wahrscheinlichste Ursachenkombination

### Problem A (Watch-Aktion kommt nicht an):
**Hypothese 1** (Delegate zu spaet) ist die primaere Ursache. Wenn das nicht reicht, Hypothese 2 als sekundaerer Faktor.

### Problem B (iOS/macOS zeigen unterschiedliche NextUp):
**Hypothese 4** (verschiedene Refresh-Mechanismen) + natuerliche CloudKit-Latenz zwischen Geraeten.

---

## Debugging-Plan (Beweis-Strategie)

### Hypothese 1 bestaetigen:
1. Print-Log in `WatchNotificationDelegate.init()` und in `userNotificationCenter(:didReceive:)`
2. Print-Log in `FocusBloxWatchApp.body` → `.onAppear` Block
3. Watch-App schliessen → Notification-Aktion ausfuehren → Xcode Console pruefen
4. **ERWARTETES Ergebnis wenn H1 stimmt:** `didReceive` Log VOR oder OHNE `.onAppear` Log
5. **ERGEBNIS wenn H1 falsch:** `.onAppear` Log VOR `didReceive` Log

### Hypothese 2 bestaetigen:
1. Print-Log in `handleAction()` bei Zeile 77: "Task \(taskID) not found in Watch store"
2. Wenn dieses Log erscheint → CloudKit-Sync hat den Task noch nicht zur Watch gebracht

### Fix ohne Debugging:
- Delegate-Registrierung in `init()` verschieben statt `.onAppear` (sicher, kein Nachteil)
- Fehler-Logging statt `try?` beim Save
- Gilt fuer BEIDE Plattformen (iOS + Watch)

---

## Blast Radius

### Direkt betroffen:
- ALLE 4 Watch-Notification-Aktionen (NextUp, Postpone x2, Complete)
- NextUp-Anzeige auf allen 3 Plattformen

### Sekundaer betroffen (gleicher Delegate-Timing-Bug auf iOS):
- iOS Notification-Aktionen (gleicher `.onAppear` Pattern) — funktioniert "zufaellig" wegen schnellerem App-Start

### Weitere Watch-Divergenzen (Bonus-Fixes):
- `actionPostpone`: Fehlt `rescheduleCount` Inkrement
- `actionComplete`: Fehlt RecurrenceService.createNextInstance()

---

## Empfohlener Fix

1. **Delegate-Registrierung in `init()` verschieben** (Watch + iOS)
2. **Fehler-Logging statt `try?` bei `context.save()`** (Watch)
3. **Optional:** Watch-Postpone um `rescheduleCount` erweitern, Watch-Complete um RecurrenceService
