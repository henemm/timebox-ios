# Bug 69: FocusBlock Cross-Platform Sync zu langsam

## Symptom

- **Plattform:** iOS <-> macOS
- **Screen:** Blox-Tab (Kalenderansicht)
- **Verhalten:** FocusBlock auf iOS erstellt -> erscheint auf macOS erst nach 1-2 Minuten statt erwarteter ~10 Sekunden
- **Hennings Aussage:** "Ich erwarte dass es zeitnah synchronisiert. Zeitnah ist etwas im Bereich von 10 sec."

## Agenten-Ergebnisse (5 parallele Investigations)

### Agent 1: Wiederholungs-Check
- **Bug 38 (CloudKit Sync):** SwiftData-Tasks syncten nicht wegen stale ModelContext. Fix: `modelContext.save()` vor Fetch. GELOEST.
- **Bug 66 (MenuBar Deadlock):** MenuBar-Icon aktualisierte nicht waehrend aktiver Blocks. Fix: refreshCounter + 15s Polling. GELOEST.
- **Erkenntnis:** Alle bisherigen Sync-Fixes betreffen **SwiftData/CloudKit** (Tasks). FocusBlocks (EventKit) wurden NIE gefixt.

### Agent 2: Datenfluss-Trace
- FocusBlocks = EKEvent (EventKit Calendar Events) mit serialisierten Daten in `event.notes`
- Sync-Kanal: Apple iCloud Calendar (NICHT CloudKit/SwiftData)
- **KEIN EKEventStoreChangedNotification Listener** im gesamten Code
- Refresh nur durch: `.task {}` (erster Load), `.onChange(selectedDate)`, Pull-to-Refresh
- **Kein scenePhase-Handler** fuer EventKit in BlockPlanningView oder MacPlanningView

### Agent 3: Alle Schreiber
- 11 EKEventStore.save()/remove() Stellen — alle in EventKitRepository.swift
- Aufrufer: BlockPlanningView (iOS), MacPlanningView (macOS), FocusBlockActionService
- **Bestaetigt:** Kein EKEventStoreChangedNotification Listener

### Agent 4: Alle Szenarien
- 12 Failure-Szenarien identifiziert, davon 4 CRITICAL:
  1. Kein EventKit Notification Listener
  2. iOS: Kein scenePhase-Refresh fuer EventKit
  3. macOS: Kein scenePhase-Refresh fuer EventKit
  4. Kein Polling waehrend Tab offen ist
- MenuBar-Icon: 15s Polling (bereits implementiert, aber nur fuer MenuBar)

### Agent 5: Blast Radius
- 99+ Dateien referenzieren EventKit/FocusBlock System
- Migration zu SwiftData = XL (100+ Dateien betroffen)
- **EKEventStoreChangedNotification Listener hinzufuegen = S** (4-5 Dateien)
- Betroffene Views bei Listener: BlockPlanningView, MacPlanningView, FocusLiveView, MenuBarView

## Hypothesen

### Hypothese 1: Fehlender EKEventStoreChangedNotification Listener (HOCH)

**Beschreibung:** EventKit feuert `EKEventStoreChangedNotification` wenn Kalender-Events sich aendern (lokal oder via iCloud). Kein Code hoert darauf. Views zeigen daher IMMER stale Daten bis der User manuell refresht.

**Beweis DAFUER:**
- Grep nach `EKEventStoreChangedNotification` = 0 Treffer im gesamten Code
- Grep nach `eventStoreChanged` = 0 Treffer
- Alle Views laden nur bei: erster Load, Date-Change, Pull-to-Refresh
- Apple Docs: "Register for EKEventStoreChangedNotification to be told when the database changes" (Standard-Pattern)

**Beweis DAGEGEN:**
- Selbst MIT Listener koennte der Sync langsam sein, wenn Apple's iCloud Calendar Sync selbst 1-2 Minuten braucht
- Aber: Die Notification feuert erst wenn die LOKALE EventKit-DB aktualisiert wurde — also genau dann wenn Daten verfuegbar sind

**Wahrscheinlichkeit:** HOCH — Das ist das Standard-Pattern das Apple empfiehlt und das hier komplett fehlt

### Hypothese 2: Fehlender scenePhase-Refresh fuer EventKit (HOCH)

**Beschreibung:** Wenn die App in den Vordergrund kommt, wird `syncMonitor.triggerSync()` aufgerufen — aber das synct nur SwiftData. EventKit wird NICHT neu geladen. User oeffnet App -> sieht alte FocusBlocks.

**Beweis DAFUER:**
- `FocusBloxApp.swift:259-265`: scenePhase Handler ruft nur SwiftData-Sync auf
- `FocusBloxMacApp.swift:224-228`: Identisches Problem
- BlockPlanningView hat KEINEN `.onChange(of: scenePhase)` Handler

**Beweis DAGEGEN:**
- Wenn der Tab gewechselt wird, koennte `.task {}` erneut feuern — aber nur beim ERSTEN Erscheinen, nicht bei jedem Foreground

**Wahrscheinlichkeit:** HOCH — Einfacher, beweisbarer Fehler

### Hypothese 3: Apple iCloud Calendar Sync ist inherent langsam (MITTEL)

**Beschreibung:** Apple's iCloud Calendar Sync (der Transport-Layer) braucht selbst 1-2 Minuten fuer Cross-Device-Sync.

**Beweis DAFUER:**
- iCloud Calendar Sync ist known-to-be langsamer als CloudKit Push
- Apple kontrolliert den Sync-Zeitpunkt, nicht wir
- Keine API um iCloud Calendar Sync zu beschleunigen

**Beweis DAGEGEN:**
- Wenn Henning sagt "1-2 Minuten", koennte das auch sein weil er die App im Vordergrund hat und kein Auto-Refresh passiert
- Apple Calendar App zeigt Aenderungen deutlich schneller (hat eigene Notifications)
- Selbst wenn der Transport 30s dauert, sollte der EKEventStoreChangedNotification Listener den Rest abdecken

**Wahrscheinlichkeit:** MITTEL — Moeglicherweise ein Faktor, aber wahrscheinlich nicht die Hauptursache

### Hypothese 4: EventKit -> SwiftData Migration noetig (NIEDRIG)

**Beschreibung:** FocusBlock-Storage muss komplett von EventKit auf SwiftData migriert werden fuer volle Sync-Kontrolle.

**Beweis DAFUER:**
- SwiftData/CloudKit Sync ist schneller und kontrollierbarer
- Wir koennten Push-Notifications + remoteChangeCount nutzen
- Keine Abhaengigkeit von Apple's iCloud Calendar Timing

**Beweis DAGEGEN:**
- Massiver Umbau (99+ Dateien, XL Scope)
- EventKit bietet Kalender-Integration gratis (Apple Calendar App zeigt unsere Blocks)
- Der einfachere Fix (Notification Listener) wurde noch nie probiert
- Migration loest nicht das Problem wenn es ein App-seitiges Refresh-Problem ist

**Wahrscheinlichkeit:** NIEDRIG — Overkill wenn der Listener das Problem loest

## Wahrscheinlichste Ursache

**Kombination aus Hypothese 1 + 2:**

Die App hoert nicht auf EventKit-Aenderungen UND laedt EventKit nicht neu wenn sie in den Vordergrund kommt. Das bedeutet:
- FocusBlock auf iOS erstellt -> iCloud Calendar synct in ~5-30s zur macOS EventKit-DB
- macOS FocusBlox hat die Daten LOKAL VERFUEGBAR, zeigt sie aber NICHT AN weil kein Refresh getriggert wird
- User muss manuell Date wechseln oder Pull-to-Refresh machen

## Debugging-Plan

### Bestaetigung der Hypothese:
1. **Test:** FocusBlock auf iOS erstellen, 30s warten, dann auf macOS im Apple Calendar nachschauen
   - Wenn dort sichtbar → Daten sind da, FocusBlox App refresht nur nicht (Hypothese 1+2 bestaetigt)
   - Wenn NICHT dort sichtbar → Apple iCloud Calendar Sync ist langsam (Hypothese 3)

2. **Test:** Auf macOS in FocusBlox die Date wechseln (morgen -> heute) nach dem der Block auf iOS erstellt wurde
   - Wenn Block erscheint → Daten waren da, nur kein Auto-Refresh (Hypothese 1+2 bestaetigt)
   - Wenn Block NICHT erscheint → EventKit-DB noch nicht aktualisiert (Hypothese 3)

### Widerlegung:
- Wenn BEIDE Tests zeigen dass Daten nicht in der lokalen EventKit-DB sind → Migration (Hypothese 4) wuerde auch nicht helfen, da Apple Calendar Sync der Bottleneck ist

## Fix-Vorschlag (bei bestaetigter Hypothese 1+2)

**Scope: 4-5 Dateien, ~80-100 LoC**

1. **EventKitRepository.swift:** `EKEventStoreChangedNotification` Observer + Published Property (`@Published var eventStoreChangeCount = 0`)
2. **BlockPlanningView.swift:** `.onChange(of: eventKitRepo.eventStoreChangeCount)` -> `loadData()`
3. **MacPlanningView.swift:** Identisch
4. **FocusBloxApp.swift:** Im scenePhase Handler auch EventKit-Views refreshen (oder Notification posten)
5. Optional: **FocusLiveView.swift:** Auch Listener fuer aktive Blocks

## Blast Radius des Fixes

- **Direkt betroffen:** 4-5 Dateien (klein, kontrollierbar)
- **Kein Risiko fuer:** SwiftData, CloudKit, Watch, Widgets (anderer Sync-Kanal)
- **Zu testen:** iOS Blox-Tab, macOS Blox-Tab, MenuBar Icon (hat eigenes 15s Polling)
