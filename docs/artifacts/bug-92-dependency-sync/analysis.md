# Bug 92: Dependency-Sync iOS → macOS — Analyse

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- 6 Dependency-Bugs (DEP-1 bis DEP-7) bereits gefixt — keiner betraf Sync
- 3 CloudKit-Sync-Bugs gefixt (Bug 38, 80, 90) — keiner betraf blockerTaskID
- Kein frueherer Bug hat Dependency-Sync cross-platform adressiert

### Agent 2: Datenfluss-Trace
- `blockerTaskID` ist ein normales `String?` Stored Property auf `@Model` LocalTask (Zeile 102-105)
- SwiftData synct ALLE Stored Properties automatisch zu CloudKit
- iOS + macOS nutzen DASSELBE LocalTask-Model aus `Sources/Models/`
- Beide nutzen `.cloudKitDatabase: .private("iCloud.com.henning.focusblox")`
- WatchLocalTask hat blockerTaskID ebenfalls (Schema-Paritaet)

### Agent 3: Alle Schreiber
- 7 produktive Schreibstellen gefunden (createTask, TaskFormSheet, TaskInspector, SyncEngine.freeDependents, FocusBlockActionService, WatchNotificationDelegate, NotificationActionDelegate)
- Alle Schreibstellen enden mit `modelContext.save()` → CloudKit-Export

### Agent 4: Sync-Szenarien
- Alle 12 Szenarien analysiert — kein Szenario bei dem Sync architekturbedingt fehlschlagen wuerde
- `forceCloudKitFieldSync()` enthaelt blockerTaskID NICHT — aber irrelevant (siehe Hypothese 2)

### Agent 5: Blast Radius + macOS Views
- macOS ContentView: `blockedDependents(of:)` korrekt implementiert
- MacBacklogRow: Indent (20pt) + Dimming (0.5) + Lock-Icon korrekt
- TaskInspector: BlockerPickerSheet + Cycle Detection korrekt
- Guards (Completion/NextUp) auf macOS korrekt

---

## Hypothesen

### Hypothese 1: blockerTaskID synct NICHT ueber CloudKit (UNWAHRSCHEINLICH)

**Beweis DAGEGEN:**
- blockerTaskID ist ein normales `String?` Stored Property auf `@Model`
- SwiftData synct ALLE Stored Properties automatisch — kein Opt-in noetig
- Kein `@Transient`, kein `@Attribute(.ephemeral)` Marker
- Andere String?-Felder (taskDescription, recurrencePattern, tags) synchen nachweislich
- Default-Wert `nil` ist CloudKit-kompatibel

**Wahrscheinlichkeit:** NIEDRIG (< 5%)

### Hypothese 2: forceCloudKitFieldSync() fehlt blockerTaskID → Feld nicht im Schema (IRRELEVANT)

**Was die Funktion tut:** Einmalige Migration (UserDefaults-Key "cloudKitFieldSyncV2") die BESTEHENDE Feldwerte "anfasst" um CloudKit zum Sync zu zwingen.

**Beweis DAGEGEN:**
- Die Funktion ist fuer Felder die VOR dem CloudKit-Feature bereits Werte hatten
- blockerTaskID startet als `nil` — es gibt nichts zu "touchen"
- Sobald ein User blockerTaskID SETZT, pusht `modelContext.save()` es automatisch
- Die Migration hat nichts mit neuen Feld-Writes zu tun

**Wahrscheinlichkeit:** IRRELEVANT — kein Bug

### Hypothese 3: Timing — macOS zeigt kurzzeitig stale Daten nach Blocker-Completion (MOEGLICH)

**Szenario:**
1. iOS: Blocker-Task erledigt → `freeDependents()` setzt blockerTaskID = nil lokal
2. CloudKit synct `isCompleted = true` an macOS
3. Aber `blockerTaskID = nil` hat macOS NOCH NICHT erhalten
4. macOS zeigt: Blocker erledigt, aber Dependent noch "blockiert"

**Beweis DAFUER:**
- CloudKit ist eventually consistent — Felder koennen in unterschiedlicher Reihenfolge ankommen
- macOS filtert nach `blockerTaskID == nil` (nicht: "ist Blocker erledigt?")

**Beweis DAGEGEN:**
- Beide Aenderungen (isCompleted + blockerTaskID=nil) werden im gleichen `save()` gepusht
- CloudKit synct in der Regel den kompletten Record, nicht einzelne Felder
- Das Problem loest sich automatisch nach wenigen Sekunden

**Wahrscheinlichkeit:** NIEDRIG fuer dauerhaftes Problem, MOEGLICH fuer kurzzeitiges Flackern

### Hypothese 4: Bug 92 ist KEIN Bug — es ist eine Verifikations-Aufgabe (HOCH)

**Beweis DAFUER:**
- Bug-Beschreibung sagt "Unklar ob..." — kein beobachtetes Symptom
- Code-Analyse zeigt: Alle Pfade korrekt implementiert
- Gleiche Architektur wie andere synchende Felder die nachweislich funktionieren
- 7 Dependency-Bugs bereits gefixt (DEP-1 bis DEP-7) — Sync war nie das Problem

**Wahrscheinlichkeit:** HOCH (> 85%)

---

## Wahrscheinlichste Ursache

**Bug 92 ist kein Bug.** Die Dependency-Daten synchen korrekt ueber CloudKit weil:
1. `blockerTaskID` ein normales Stored Property ist (automatischer Sync)
2. iOS und macOS dasselbe Model nutzen (kein Schema-Mismatch)
3. macOS die Dependency-Daten korrekt anzeigt (Indent, Dimming, Lock-Icon, Guards)
4. Kein Code-Pfad existiert der blockerTaskID beim Sync verliert

---

## Nebenfunde (KEINE Bug-92-Issues, aber dokumentierenswert)

### Nebenfund A: SyncEngine.updateNextUp() hat keinen Blocker-Guard
- View-Layer-Guards auf iOS + macOS verhindern UI-Interaktion
- Aber der Service-Layer (SyncEngine.updateNextUp) hat KEINEN Guard
- Risiko: Siri-Shortcuts oder externe Aufrufe koennten blockierte Tasks in NextUp packen
- **Eigener Bug-Ticket wert** (aber sehr geringes Risiko)

### Nebenfund B: Watch ignoriert blockerTaskID in der UI
- WatchLocalTask hat das Feld (Schema-Paritaet)
- Aber Watch-UI zeigt keine Blockierung an (kein Indent, kein Lock-Icon)
- Watch ist primair Completion-Device — geringes Risiko
- **Backlog-Item** fuer spaeter

---

## Challenge-Ergebnisse (Devil's Advocate)

**Verdict:** LUECKEN → nach Nachpruefung geschlossen

### Geprueft und bestaetigt:
- macOS Completion geht durch `SyncEngine.completeTask()` → `freeDependents()` wird aufgerufen (ContentView.swift:891-892)
- `forceCloudKitFieldSync` Begruendung korrigiert: Irrelevant weil normale Writes `modelContext.save()` nutzen (nicht weil nil)

### Transientes Edge-Case (akzeptiert):
- Zombie-Blocker nach plattformuebergreifendem Delete: Wenn iOS einen Blocker loescht und CloudKit den nil-Sync verzoegert, ist der Dependent auf macOS kurzzeitig unsichtbar (weder in blocker-Gruppe noch in regulaerer Liste). Loest sich automatisch nach CloudKit-Sync (Sekunden). Gleiche Eventual-Consistency wie bei ALLEN CloudKit-Feldern.

---

## Empfehlung

**Bug 92 schliessen als "Kein Bug — durch Code-Analyse verifiziert".**

Die Architektur garantiert Sync: SwiftData + CloudKit synct automatisch alle Stored Properties. Kein manueller Sync-Code noetig, kein Code-Pfad der das Feld verliert.

Falls gewuenscht: Die Nebenfunde als eigene Backlog-Items erfassen.

---

## Blast Radius

Kein Fix noetig → kein Blast Radius.
