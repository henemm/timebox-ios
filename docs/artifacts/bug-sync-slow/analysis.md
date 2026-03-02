# Bug-Analyse: Sync zwischen macOS und iOS langsam/nicht automatisch

## Symptom
- Sync zwischen macOS und iOS funktioniert nicht automatisch bei Aenderungen
- Weder FocusBlox noch NextUp werden synchronisiert
- Sync dauert sehr lange

---

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- **6 bisherige Sync-Bugs** gefunden (Bug 32, 33, 34, 38, 57, 60)
- Bug 38 war der wichtigste: iOS BacklogView aktualisiert sich nicht automatisch nach CloudKit-Import
- Bug 38 Fix: `modelContext.save()` vor Fetch + `remoteChangeCount` Observer + 200ms Delay
- Bug 33: CloudKit war auf iOS deaktiviert — GEFIXT
- **Kritisch:** Bug 38 nur TEILWEISE geloest — iOS hat Workaround, macOS wurde nie adressiert

### Agent 2 (Datenfluss-Trace)
- SwiftData + CloudKit: Automatischer Export bei jedem `modelContext.save()`
- Import: `NSPersistentStoreRemoteChange` feuert wenn Remote-Daten ankommen
- **iOS:** Manueller Fetch via `SyncEngine.sync()` + `refreshLocalTasks()`
- **macOS:** `@Query` (auto-update) — ABER kein expliziter Merge-Trigger
- **KRITISCH:** macOS hat KEINEN `scenePhase` Handler

### Agent 3 (Sync-Trigger)
- iOS: `scenePhase == .active` → `triggerSync()` (korrekt)
- macOS: NUR bei initialem `.task` Load + manueller Sync-Button
- macOS: KEIN `onChange(of: scenePhase)` in FocusBloxMacApp
- macOS ContentView: KEIN `onChange(of: remoteChangeCount)`

### Agent 4 (Szenarien)
- 10 Szenarien analysiert
- Top-Ursache: Kein UI-Refresh nach Remote-Change auf macOS
- CloudKit Config ist korrekt und identisch auf beiden Plattformen

### Agent 5 (Blast Radius)
- 3 Sync-Systeme: SwiftData/CloudKit, EventKit/iCloud Calendar, UserDefaults/iCloud KV
- NextUp ist Teil von LocalTask (synct via CloudKit)
- macOS MenuBarView hat KEINEN CloudKitSyncMonitor in der Environment

---

## Hypothesen

### H1: macOS ContentView reagiert nicht auf Remote-Changes (HOCH)

**Beschreibung:** Der `CloudKitSyncMonitor` registriert `NSPersistentStoreRemoteChange` bereits im `init()` und inkrementiert `remoteChangeCount`. ABER: macOS ContentView hat KEINEN `.onChange(of: cloudKitMonitor.remoteChangeCount)` Observer. Der Counter zaehlt hoch, aber niemand lauscht darauf.

**Beweis DAFUER:**
- `CloudKitSyncMonitor.swift:102-110`: `remoteChangeTask` in `init()` — Observer existiert
- `CloudKitSyncMonitor.swift:131`: `remoteChangeCount += 1` bei jedem Remote-Change
- `ContentView.swift`: 0 Treffer fuer `remoteChangeCount` oder `onChange`
- iOS `BacklogView.swift:328`: HAT `.onChange(of: cloudKitMonitor.remoteChangeCount)` — macOS nicht

**Beweis DAGEGEN:**
- macOS nutzt `@Query` das sich theoretisch automatisch aktualisieren sollte

**Wahrscheinlichkeit:** HOCH

### H2: macOS @Query sieht keine CloudKit-Imports (Bug 38 Pattern) (HOCH)

**Beschreibung:** CloudKit-Import schreibt in den Persistent Store, aber der ModelContext-Cache ist stale. `@Query` beobachtet den ModelContext, nicht den Store. Ohne `modelContext.save()` (No-Op) wird der Cache nicht invalidiert.

**Beweis DAFUER:**
- Bug 38 Root Cause (bewiesen auf iOS): `modelContext.fetch()` gibt stale Daten zurueck
- iOS Fix: `BacklogView.swift:431`: `try modelContext.save()` vor jedem Fetch
- macOS: KEIN entsprechender Mechanismus
- `checkForChanges()` (CloudKitSyncMonitor:142-146) macht `context.fetch()` OHNE vorheriges `save()` — liest also ebenfalls stale Daten

**Beweis DAGEGEN:**
- Apple-Dokumentation sagt @Query aktualisiert automatisch bei ModelContext-Aenderungen
- Unklar ob `@Query` den Persistent Store direkt beobachtet oder nur den ModelContext

**Wahrscheinlichkeit:** HOCH — identisches Pattern wie Bug 38

### H3: macOS hat keinen scenePhase/Foreground-Trigger (HOCH)

**Beschreibung:** macOS `FocusBloxMacApp` hat KEINEN `onChange(of: scenePhase)` Handler. Beim App-Wechsel zum Vordergrund wird kein Sync ausgeloest.

**Beweis DAFUER:**
- `FocusBloxMacApp.swift`: 0 Treffer fuer scenePhase, onChange, triggerSync
- iOS `FocusBloxApp.swift:253-255`: HAT `onChange(of: scenePhase) { if .active → triggerSync() }`
- macOS `ContentView.swift:509`: NUR `.task { triggerSync() }` (einmalig bei View-Load)

**Wahrscheinlichkeit:** HOCH

### H4: CloudKit-Infrastruktur-Latenz (MITTEL)

**Beschreibung:** Selbst wenn der Code korrekt waere, dauert der CloudKit-Roundtrip:
1. Export auf Geraet A
2. CloudKit-Verarbeitung
3. Silent Push an Geraet B
4. Import auf Geraet B

Ohne explizite `CKSubscription`/`CKDatabaseSubscription` (0 Treffer im Code) verlaesst sich die App auf SwiftDatas implizite Subscription-Registrierung.

**Wahrscheinlichkeit:** MITTEL — systembedingte Verzoegerung, nicht direkt fixbar

### H5: MenuBarView hat keinen CloudKitSyncMonitor (NIEDRIG)

**Beschreibung:** macOS MenuBarView bekommt den `ModelContainer` und `EventKitRepository` injiziert, aber KEINEN `CloudKitSyncMonitor`. Falls NextUp in der MenuBar angezeigt wird, ist diese View komplett vom Sync-Feedback abgeschnitten.

**Beweis DAFUER:**
- `FocusBloxMacApp.swift:49-53`: `MenuBarView().modelContainer(container).environment(\.eventKitRepository, eventKitRepository)` — kein syncMonitor

**Wahrscheinlichkeit:** NIEDRIG fuer das Hauptsymptom, aber relevant fuer macOS-Gesamtbild

---

## Wahrscheinlichste Ursache: H1 + H2 + H3 zusammen

**iOS → macOS Richtung (Hauptproblem):**
1. User aendert Task auf iOS → `save()` → CloudKit Export (funktioniert)
2. CloudKit sendet Push an macOS → Import in Persistent Store (funktioniert)
3. `NSPersistentStoreRemoteChange` feuert → `remoteChangeCount` wird inkrementiert
4. **ABER:** macOS ContentView hat keinen `.onChange(of: remoteChangeCount)` → kein Refresh
5. **ABER:** @Query sieht stale ModelContext-Cache → zeigt alte Daten
6. **ABER:** Kein `scenePhase` Trigger → auch App-Wechsel hilft nicht
7. **Ergebnis:** Daten sind im Store, aber UI aktualisiert sich nicht

**macOS → iOS Richtung:**
1. User aendert Task auf macOS → `save()` → CloudKit Export (funktioniert)
2. iOS empfaengt Push → `remoteChangeCount` inkrementiert
3. iOS `BacklogView:328` reagiert → 200ms Delay → `refreshLocalTasks()` mit `save()` vor Fetch
4. **SOLLTE funktionieren** — aber CloudKit-Infrastruktur-Latenz kann sich langsam anfuehlen

---

## Offene Fragen an Henning (Devil's Advocate)

1. **Richtung:** Ist das Problem primaer iOS→macOS (macOS zeigt Aenderungen von iOS nicht)? Oder auch macOS→iOS?
2. **Was genau synct nicht:** Neue Tasks? Aenderungen an bestehenden? NextUp-Status? Oder alles?
3. **Timing:** War das Problem schon immer da oder ist es seit einem bestimmten Update aufgetreten?
4. **MenuBar:** Nutzt du die macOS MenuBar-Ansicht? Synct die auch nicht?

---

## Blast Radius

**Direkt betroffen:**
- macOS ContentView (Task-Liste) — kein Sync-Refresh
- macOS MenuBarView — kein CloudKitSyncMonitor
- Alle macOS Views die auf @Query basieren

**Indirekt betroffen:**
- NextUp-Status (isNextUp auf LocalTask)
- FocusBlock-Zuweisungen (assignedFocusBlockID)

**NICHT betroffen:**
- iOS BacklogView (hat Bug 38 Fix)
- EventKit/Kalender-Sync (separater Pfad)
- Settings-Sync (iCloud KV Store)

---

## Challenge-Verdict: LUECKEN (adressiert)

Devil's Advocate hat folgende Luecken gefunden und sie wurden in die Analyse eingearbeitet:
1. remoteChangeCount Observer existiert im init() — das Problem ist dass ContentView nicht darauf lauscht (korrigiert in H1)
2. checkForChanges() in CloudKitSyncMonitor liest ohne save() — stale Data (eingearbeitet in H2)
3. MenuBarView hat keinen CloudKitSyncMonitor (neue H5)
4. Frage nach Richtung und Timing (in offene Fragen aufgenommen)
