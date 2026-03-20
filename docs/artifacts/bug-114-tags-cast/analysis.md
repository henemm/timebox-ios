# BUG_114 Analyse: SwiftData Cast-Fehler in LocalTask.tags

## Bug-Beschreibung

macOS App startet, aber Tasks werden nicht geladen. App haengt.
Stack Trace: `ContentView.overdueTasks.getter` -> `scoreFor(_:)` -> `coachBoostedIDs.getter` -> `planItems.getter` -> `PlanItem.init(localTask:)` (Zeile 178) -> `LocalTask.tags.getter` -> SwiftData `swift_dynamicCastFailure` -> `fatalError`

Tritt nach Clean Build Folder + Build + Run auf.

---

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- **5 verwandte Bugs** gefunden: BUG_112, BUG_78, BUG_113, Watch-Crash, Bug 62
- BUG_112 + BUG_78: BackingData-Detachment nach Loeschung — Guards (`modelContext != nil`) eingefuegt
- Watch-Crash: Schema-Mismatch (fehlende Felder in WatchLocalTask) — **aehnlichstes Pattern**
- **tags-Typ war IMMER `[String]`** — keine Typ-Aenderung in Git-History

### Agent 2: Datenfluss-Trace
- Crash-Chain klar: `overdueTasks` -> `scoreFor` -> `coachBoostedIDs` -> `planItems` -> `PlanItem.init(localTask:)` Zeile 178: `self.tags = localTask.tags`
- `visibleTasks` (Zeile 119) prueft `$0.modelContext != nil` — Tasks SIND im Context
- **Objekte sind NICHT detached** — die Daten selbst koennen nicht deserialisiert werden

### Agent 3: Alle Schreiber
- 10+ Schreibstellen, ALLE schreiben `[String]`
- Keine Typ-Inkonsistenz in Schreibern
- CloudKit Field Sync (Zeile 511): `if !task.tags.isEmpty { task.tags = task.tags }` — liest tags beim App-Start

### Agent 4: Szenarien
- 10 Szenarien identifiziert
- Top-Kandidaten: Schema-Mismatch nach Clean Build, CloudKit-Typ-Inkompatibilitaet, nil/NSNull Deserialisierung

### Agent 5: Blast Radius
- macOS ContentView: `matchesSearch` (Zeile 111) + `planItems` (Zeile 366) greifen auf tags zu
- iOS ist geschuetzt durch PlanItem-Struct-Konvertierung im SyncEngine
- **11 ungeschuetzte tags-Zugriffe** in Services und macOS Views
- **KEIN error handling** um tags-Zugriff irgendwo im Code

---

## Hypothesen

### Hypothese A: SwiftData kann gespeicherte Array-Daten nach Clean Build nicht korrekt deserialisieren (HOCH)

**Beschreibung:** SwiftData speichert `[String]` intern als Transformable (Binary Plist). Nach Clean Build Folder wird das Model-Metadata neu generiert. Wenn die interne Serialisierungs-Zuordnung sich unterscheidet (z.B. durch Xcode-Update oder Schema-Re-Inferenz), scheitert der Cast von den gespeicherten Rohdaten zurueck zu `[String]`.

**Beweis DAFUER:**
- Bug tritt NUR nach Clean Build Folder auf
- Kein `VersionedSchema` / `SchemaMigrationPlan` im Code — App verlaesst sich auf Auto-Migration
- Watch-Crash hatte exakt das gleiche Pattern (Schema-Mismatch)
- `tags` Typ hat sich nie geaendert — Problem ist NICHT der Quellcode sondern die gespeicherten Daten vs. neue Schema-Inferenz

**Beweis DAGEGEN:**
- `[String]` ist ein Standard-SwiftData-Typ — sollte stabil sein
- Wenn dies ein generelles SwiftData-Problem waere, muessten ALLE Array-Properties betroffen sein (z.B. `recurrenceWeekdays: [Int]?`)

**Wahrscheinlichkeit:** HOCH

### Hypothese B: CloudKit Sync liefert inkompatible Typ-Kodierung (MITTEL-HOCH)

**Beschreibung:** CloudKit speichert Arrays als `NSArray`. Beim Deserialisieren durch SwiftData koennte der Bridge von `NSArray<NSString>` zu `[String]` fehlschlagen, wenn die Array-Elemente unerwartet sind (z.B. NSNull, gemischte Typen, oder ein einzelner String statt Array).

**Beweis DAFUER:**
- CloudKit aktiv auf beiden Plattformen
- `forceCloudKitFieldSync` (Zeile 511) greift bei App-Start auf `task.tags` zu — wenn CloudKit-Daten korrupt sind, crasht es dort
- iOS und macOS teilen CloudKit-Datenbank — unterschiedliche SDK-Versionen koennten unterschiedlich serialisieren

**Beweis DAGEGEN:**
- Beide Plattformen verwenden denselben `LocalTask` Typ
- CloudKit Sync funktionierte vorher (Bug tritt erst nach Clean Build auf)

**Wahrscheinlichkeit:** MITTEL-HOCH

### Hypothese C: BackingData-Detachment waehrend @Query-Enumeration trotz modelContext-Guard (MITTEL)

**Beschreibung:** Obwohl `visibleTasks` mit `modelContext != nil` filtert, koennte sich der Context-Status ZWISCHEN dem Filter und dem Zugriff in `PlanItem.init` aendern (Race Condition mit CloudKit-Sync im Hintergrund).

**Beweis DAFUER:**
- BUG_112 und BUG_78 waren BackingData-Probleme
- CloudKit Sync laeuft im Hintergrund und kann jederzeit Objekte detachen
- `planItems` ist ein Computed Property — wird bei jedem Zugriff neu berechnet, inkl. alle `PlanItem.init` Aufrufe

**Beweis DAGEGEN:**
- Bug tritt "nach Clean Build" auf, nicht waehrend einer bestimmten Aktion
- `visibleTasks` und `planItems` werden auf dem Main Thread berechnet — SwiftData @Query ist Actor-isolated
- Wenn es ein Race Condition waere, waere es nicht deterministisch reproduzierbar

**Wahrscheinlichkeit:** MITTEL

### Hypothese D: Corrupted/nil Daten im SQLite Store (NIEDRIG-MITTEL)

**Beschreibung:** Einzelne Tasks haben korrupte tags-Daten (z.B. NULL Blob, leerer String statt leeres Array). SwiftData castet `nil`/`NULL` -> `[String]` scheitert weil Default-Wert nur fuer NEUE Objekte gilt.

**Beweis DAFUER:**
- Clean Build koennte Cache-Recovery-Mechanismen zuruecksetzen die korrupte Daten vorher maskiert haben
- Alte Tasks koennten vor der tags-Einfuehrung erstellt worden sein (tags existiert seit Anfang, aber moeglicherweise nicht in allen Migrationen)

**Beweis DAGEGEN:**
- `tags: [String] = []` hat Default — SwiftData sollte nil als `[]` behandeln
- Wenn Daten korrupt waeren, wuerde es auch OHNE Clean Build crashen

**Wahrscheinlichkeit:** NIEDRIG-MITTEL

---

### Hypothese E: NULL-Wert in SQLite fuer tags (NEU — vom Challenger) (HOCH)

**Beschreibung:** `tags: [String] = []` setzt den Default nur im Swift-Initializer. Wenn ein Task in SQLite NULL als tags-Blob hat (nicht leeres Array, sondern echtes NULL), versucht SwiftData beim Fault-Resolution NULL zu `[String]` zu casten — das schlaegt fehl. Default-Werte greifen nur bei `init()`, nicht beim Deserialisieren.

**Beweis DAFUER:**
- Alte Tasks koennten vor vollstaendiger Migration NULL behalten haben
- CloudKit koennte Tasks ohne tags-Feld synchronisiert haben → NULL im lokalen Store
- `swift_dynamicCastFailure` passt exakt zu: "kann NULL nicht zu [String] casten"
- Clean Build Trigger erklaerbar: Cache-Clearing entfernt In-Memory-Defaults die NULL vorher maskierten

**Beweis DAGEGEN:**
- SwiftData SOLLTE Default-Werte auch beim Deserialisieren anwenden — aber ob es das tatsaechlich tut ist unklar
- Wenn ALLE Tasks NULL-tags haetten, waere der Bug schon frueher aufgefallen

**Wahrscheinlichkeit:** HOCH

### Hypothese F: onAppear-Services modifizieren Tasks vor erstem Render (NEU — vom Challenger) (NIEDRIG)

**Beschreibung:** `refreshTasks()` in `.task {}` (Zeile 220-221) laeuft VOR dem ersten UI-Render. Wenn CloudKit-Sync oder andere Services gleichzeitig Tasks loeschen/modifizieren, koennten faulted Objects im tasks-Array landen die beim Zugriff crashen.

**Beweis DAFUER:**
- `.task {}` und `.onChange(of: cloudKitMonitor.remoteChangeCount)` koennten konkurrieren
- `refreshTasks()` macht `modelContext.save()` (Zeile 95) — koennte CloudKit-Merge-Konflikte ausloesen

**Beweis DAGEGEN:**
- `.task {}` laeuft einmalig, nicht konkurrierend mit onChange
- Crash muesste dann auch ohne Clean Build auftreten

**Wahrscheinlichkeit:** NIEDRIG

---

## Wahrscheinlichste Ursache (aktualisiert nach Challenge)

**Hypothese E** (NULL in SQLite) ist am wahrscheinlichsten, moeglicherweise in Kombination mit **Hypothese A** (Clean Build entfernt Cache der NULL maskierte).

Begruendung:
- `swift_dynamicCastFailure` passt perfekt zu NULL → `[String]` Cast-Versuch
- Clean Build Trigger erklaerbar durch Cache-Clearing
- Tags-Typ hat sich nie geaendert → Problem sind die DATEN, nicht das Schema
- KEIN `VersionedSchema` im Code → keine explizite Null-Handling-Migration

Begruendung gegen die anderen:
- **Hypothese B** (CloudKit): Moeglich als URSACHE der NULL-Werte, aber nicht der direkte Crash-Mechanismus
- **Hypothese C** (Race Condition): `visibleTasks` Guard vorhanden, nicht reproduzierbar
- **Hypothese D** (Korrupte Daten): Subsumiert unter Hypothese E

---

## Debugging-Plan

### Wie beweise ich Hypothese E (NULL in SQLite)?

1. **SQLite direkt pruefen:**
   ```bash
   sqlite3 ~/Library/Group\ Containers/group.com.henning.focusblox/default.store \
     "SELECT ZTITLE, ZTAGS FROM ZLOCALTASK WHERE ZTAGS IS NULL LIMIT 10"
   ```
   **Erwartung bei E:** Mindestens 1 Task mit NULL tags

2. **Logging VOR dem Crash:** In `PlanItem.init(localTask:)` vor Zeile 178 einbauen:
   ```swift
   // Temporaeres Debug-Logging
   let mirror = Mirror(reflecting: localTask)
   if let tagsChild = mirror.children.first(where: { $0.label == "tags" }) {
       print("[DEBUG] Task \(localTask.title): tags mirror = \(tagsChild.value)")
   }
   ```
   **Erwartung bei E:** Mirror zeigt nil/NSNull bevor der Cast crasht

3. **Plattform:** macOS

### Wie widerlege ich Hypothese E?

- Wenn ALLE Tasks valide (nicht-NULL) tags-Blobs in SQLite haben → E widerlegt
- Wenn der Bug auch mit frischer Datenbank (keine alten Daten) auftritt → E widerlegt

---

## Blast Radius

### Direkt betroffen (macOS):
- `ContentView.matchesSearch()` (Zeile 111) — tags-Zugriff
- `ContentView.planItems` (Zeile 366) — PlanItem-Konvertierung
- `TaskInspector` (Zeile 143) — Tags-Editing
- `ContentView.updateRecurringSeries()` (Zeile 1016) — Series-Sync

### Direkt betroffen (Services, beide Plattformen):
- `SpotlightIndexingService` (Zeile 32)
- `AITaskScoringService` (Zeile 157)
- `SmartTaskEnrichmentService` (Zeile 192)
- `RecurrenceService` (Zeile 126, 357)
- `FocusBlockActionService` (Zeile 172)

### Nicht betroffen (iOS):
- iOS verwendet PlanItem-Structs (Value Types) — Konvertierung passiert im SyncEngine, nicht in der View

### Aehnliches Risiko:
- `recurrenceWeekdays: [Int]?` — gleicher Array-Typ, gleiche Deserialisierungs-Logik
