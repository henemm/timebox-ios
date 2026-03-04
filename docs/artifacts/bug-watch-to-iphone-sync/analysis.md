# Bug-Analyse: Watch-Task erscheint nicht auf iPhone

**Symptom:** Task auf Apple Watch erstellt → erscheint NIE im iPhone-Backlog.

---

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check):
- Bug 38 (CloudKit Sync Race) war ein verwandter Bug — iOS BacklogView aktualisierte nicht nach CloudKit-Import
- Bug Fix 4b413e7 (3. März 2026): Watch-Schema-Mismatch mit 3 fehlenden Feldern behoben
- Watch hat KEINEN CloudKitSyncMonitor, verlässt sich komplett auf @Query
- Historisch: modelContext.save() vor fetch = Pflicht (Bug 38 Pattern)

### Agent 2 (Datenfluss-Trace):
- Watch → ContentView.saveTask() → modelContext.insert() → modelContext.save()
- FocusBloxWatchApp.swift: ModelContainer mit `try?` — Fehler werden VERSCHLUCKT
- Fallback: `cloudKitDatabase: .none` → komplett OHNE Sync
- Watch-Entitlements: NUR App Group, KEINE CloudKit-Einträge

### Agent 3 (Alle Schreiber):
- Kein WatchConnectivity (kein direkter Watch↔iPhone Kanal)
- Alle Plattformen nutzen gleichen CloudKit-Container-String
- Watch hat separates WatchLocalTask.swift (NICHT shared Sources/Models/LocalTask.swift)

### Agent 4 (Szenarien):
- 10 Failure-Szenarien identifiziert
- Top 3: Fallback CloudKit disabled (60%), Model-Mismatch (40%), fehlende Entitlements (35%)

### Agent 5 (Blast Radius):
- Watch hat KEIN Logging über CloudKit-Status
- Watch hat KEINEN CloudKitSyncMonitor
- iOS BacklogView nutzt manuellen Fetch (nicht @Query) — braucht expliziten Refresh-Trigger

---

## Hypothesen

### Hypothese 1: Watch fällt STILL auf cloudKitDatabase: .none zurück (HOCH — 80%)

**Beschreibung:**
Die Watch-App versucht einen ModelContainer mit CloudKit zu erstellen (Zeile 23, FocusBloxWatchApp.swift). Dieser Aufruf ist in `try?` gewickelt — wenn er fehlschlägt, fällt die App OHNE Fehlermeldung auf `cloudKitDatabase: .none` zurück (Zeile 32). Tasks werden dann NUR lokal gespeichert und NIEMALS an CloudKit exportiert.

**Beweis DAFÜR:**
1. Watch-Entitlements (`FocusBloxWatch Watch App.entitlements`) enthalten NUR `com.apple.security.application-groups` — KEINE CloudKit-Einträge (`icloud-container-identifiers`, `icloud-services`)
2. iOS-Entitlements (`Resources/FocusBlox.entitlements`) haben BEIDE CloudKit-Einträge
3. Ohne CloudKit-Entitlements wird `ModelContainer(cloudKitDatabase: .private("iCloud.com.henning.focusblox"))` wahrscheinlich fehlschlagen
4. Der `try?` (Zeile 23) verschluckt den Fehler → kein Crash, kein Log, kein Hinweis
5. Fallback (Zeile 32): `cloudKitDatabase: .none` = kein Sync

**Beweis DAGEGEN:**
- watchOS KÖNNTE CloudKit vom Companion-iPhone erben (undokumentiertes Verhalten)
- Der `try?` KÖNNTE erfolgreich sein, wenn Xcode die Entitlements automatisch konfiguriert
- Der kürzliche Watch-Crash-Fix (4b413e7) funktionierte auf echtem Gerät — das spricht dafür, dass CloudKit grundsätzlich erreichbar war

**Wahrscheinlichkeit: HOCH (80%)**

---

### Hypothese 2: Watch-LocalTask hat keine Stored-Property-Defaults → CloudKit-Schema-Fehler (MITTEL — 40%)

**Beschreibung:**
Die Watch-Version von `LocalTask` (WatchLocalTask.swift) hat KEINE Default-Werte auf den gespeicherten Properties — nur im `init()`. CloudKit erfordert aber Default-Werte auf allen Attributen (steht sogar als Kommentar in Zeile 6 von WatchLocalTask.swift!).

**Beweis DAFÜR:**
1. WatchLocalTask.swift Zeile 9: `var uuid: UUID` (kein Default)
   iOS LocalTask.swift Zeile 10: `var uuid: UUID = UUID()` (hat Default)
2. Gleiches Muster für: `title`, `isCompleted`, `tags`, `createdAt`, `sortOrder`, `taskType`, `recurrencePattern`, `isTemplate`, `isNextUp`, `rescheduleCount`, `needsTitleImprovement`, `sourceSystem`
3. Der eigene Kommentar (Zeile 6) sagt: "CloudKit requires all attributes to have default values"
4. Fehlende Defaults könnten dazu führen, dass SwiftData den CloudKit-Export ablehnt

**Beweis DAGEGEN:**
- SwiftData's `@Model` Macro könnte die init()-Defaults als Schema-Defaults verwenden
- Der kürzliche Schema-Fix (4b413e7) hat nur 3 fehlende FELDER hinzugefügt, nicht Defaults — und der Fix hat funktioniert
- Die fehlenden Defaults würden eher den IMPORT (iPhone→Watch) als den EXPORT (Watch→iPhone) stören

**Wahrscheinlichkeit: MITTEL (40%)**

---

### Hypothese 3: Watch-Task wird erstellt aber iPhone-BacklogView refresht nicht (NIEDRIG — 15%)

**Beschreibung:**
Der Task erreicht CloudKit und die iPhone-Datenbank, aber BacklogView bemerkt es nicht, weil kein Refresh ausgelöst wird.

**Beweis DAFÜR:**
1. iOS BacklogView nutzt manuellen Fetch (nicht @Query) — braucht aktiven Refresh-Trigger
2. Refresh kommt über `cloudKitMonitor.remoteChangeCount` (onChange, Zeile 327)
3. Wenn iPhone-App im Hintergrund ist, wird onChange nicht gefeuert

**Beweis DAGEGEN:**
- Henning sagt der Task erscheint NIE — auch nicht nach App-Neustart oder Pull-to-Refresh
- Wenn der Task in der DB wäre, würde er beim nächsten App-Start via `loadTasks()` erscheinen
- Pull-to-Refresh ruft `refreshLocalTasks()` auf, was `modelContext.save()` + fetch macht

**Wahrscheinlichkeit: NIEDRIG (15%)** — "Nie sichtbar" schließt "nur kein Refresh" aus

---

## Wahrscheinlichste Ursache

**Hypothese 1 (fehlende CloudKit-Entitlements → stiller Fallback)** ist mit 80% die wahrscheinlichste Ursache.

Die Kausalkette:
```
Watch-Entitlements fehlen CloudKit-Einträge
    → ModelContainer(cloudKitDatabase: .private(...)) schlägt fehl
    → try? verschluckt den Fehler
    → Fallback: cloudKitDatabase: .none
    → Tasks werden NUR lokal auf der Watch gespeichert
    → Kein Export zu CloudKit
    → iPhone bekommt keine Daten
    → Task erscheint nie
```

Hypothese 2 (fehlende Defaults) könnte ZUSÄTZLICH ein Problem sein, aber Hypothese 1 allein erklärt das Symptom vollständig.

---

## Debugging-Plan (wie beweise ich es?)

### Zum BESTÄTIGEN:
1. **Logging in FocusBloxWatchApp.swift:** Vor und nach dem `try?` einen Print setzen:
   - "CloudKit ModelContainer: CREATING..."
   - Im `if let container` Block: "CloudKit ModelContainer: SUCCESS"
   - Nach dem if-Block (Fallback): "CloudKit ModelContainer: FAILED — using .none"
2. Watch auf echtem Gerät starten, Console öffnen → wenn "FAILED — using .none" erscheint, ist die Hypothese bestätigt.

### Zum WIDERLEGEN:
- Wenn "SUCCESS" erscheint, ist Hypothese 1 falsch → dann Hypothese 2 oder 3 prüfen
- Dann Logging in `ContentView.saveTask()` prüfen: "Task saved, checking sync..."

### Auf welcher Plattform?
- **Watch** (dort liegt das Problem) + **iPhone Console** (um zu sehen ob NSPersistentStoreRemoteChange überhaupt feuert)

---

## Blast Radius

1. **Watch → iPhone Sync:** KOMPLETT GEBROCHEN (kein Export)
2. **iPhone → Watch Sync:** WAHRSCHEINLICH GEBROCHEN (Watch CloudKit-Import braucht ebenfalls Entitlements)
3. **iPhone ↔ Mac Sync:** NICHT BETROFFEN (Mac hat eigene CloudKit-Entitlements)
4. **Bidirektionale Watch-Isolation:** Watch ist ein "Data Island" — Daten gehen rein (lokal erstellt) aber nicht raus (kein CloudKit-Export)

---

## Fix-Vorschlag (Überblick)

**Primär:** CloudKit-Entitlements zur Watch hinzufügen:
- `com.apple.developer.icloud-container-identifiers: iCloud.com.henning.focusblox`
- `com.apple.developer.icloud-services: CloudKit`

**Sekundär:** Stored-Property-Defaults in WatchLocalTask.swift hinzufügen (Parität mit iOS)

**Tertiär:** Logging in Watch-ModelContainer-Setup für zukünftige Diagnose
