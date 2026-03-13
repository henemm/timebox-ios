# Bug-Analyse: Keine Einrueckung bei abhaengigen Tasks im Backlog

## Bug-Beschreibung
Feature "Abhaengige Tasks eingereuckt und ausgegraut darstellen" — Einrueckung ist nicht sichtbar. Beide Plattformen (iOS + macOS), Backlog-View.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- Feature vollstaendig implementiert am 2026-03-10 in 3 Commits
- Phase 1: Daten-Layer (blockerTaskID, isBlocked, Scoring-Bonus)
- Phase 2: iOS Views (BacklogRow 24pt Indent + 0.5 Opacity + Lock-Icon)
- Phase 2b: macOS Views (MacBacklogRow 20pt Indent)
- 7 Follow-up Bugs — ALLE bezogen auf Logik/Guards, KEINER auf Einrueckung
- **Kein vorheriger Bug zur Einrueckung bekannt**

### Agent 2 (Datenfluss-Trace)
- Kette: LocalTask.blockerTaskID -> PlanItem.isBlocked -> topLevelTasks-Filter -> blockedTasks(for:) -> blockedRow(isBlocked:true) -> BacklogRow .padding(.leading, 24)
- Beide Plattformen haben parallele Implementierungen
- `allBacklogTasks` ENTHAELT blockierte Tasks, `backlogTasks` (topLevelTasks) SCHLIESST sie aus
- `blockedTasks(for:)` findet sie in `allBacklogTasks` und rendert sie unter dem Blocker

### Agent 3 (Alle Schreiber)
- GENAU 2 Stellen setzen Einrueckung:
  - iOS: BacklogRow.swift:77 `.padding(.leading, isBlocked ? 24 : 0)`
  - macOS: MacBacklogRow.swift:98 `.padding(.leading, isBlocked ? 20 : 0)`
- Modifier-Reihenfolge: `.padding(12)` -> `.background()` -> `.opacity()` -> `.padding(.leading, 24)` -> `.contentShape()`
- Die Einrueckung ist AUSSERHALB des Hintergrund-Rechtecks = Karte verschiebt sich nach rechts

### Agent 4 (Szenarien)
- Feature IST implementiert (kein Phantom-Feature)
- 7 Szenarien untersucht, hoechste Wahrscheinlichkeit:
  - Padding durch .listRowInsets ueberlagert (70%)
  - blockerTaskID nicht gesetzt in Daten (40%)
  - isBlocked nie true (20%)

### Agent 5 (Blast Radius)
- 6 Views nutzen Dependency-Informationen (BacklogRow, MacBacklogRow, BacklogView, ContentView, TaskFormSheet, TaskAssignmentView)
- Keine visuellen Tests fuer Einrueckung vorhanden
- Keine anderen Einrueckungs-Patterns im Code

## Hypothesen

### H1: Einrueckung ist zu subtil / nicht sichtbar in List-Kontext (HOCH)

**Beschreibung:** `.padding(.leading, 24)` innerhalb einer List-Row produziert theoretisch eine 24pt-Verschiebung. Aber in `.listStyle(.plain)` mit `.listRowInsets(leading: 16)` koennte die Einrueckung visuell untergehen, weil:
- Der Padding-Bereich ist transparent (kein Hintergrund)
- 24pt auf einem iPhone (375pt+) sind ~6% der Breite
- Ohne Referenz-Linie schwer wahrzunehmen

**Beweis DAFUER:**
- Code ist korrekt — `.padding(.leading, 24)` wird gesetzt wenn `isBlocked: true`
- Modifier-Reihenfolge ist korrekt (nach `.background()`)
- User sagt "keine Einrueckung" — koennte "zu wenig" bedeuten

**Beweis DAGEGEN:**
- 24pt ist ein signifikanter Wert (ca. eine Fingerbreite)
- Die Karte verschiebt sich MIT Hintergrund — sollte klar sichtbar sein
- Lock-Icon + Dimming + Indent zusammen sollten auffallen

**Wahrscheinlichkeit: MITTEL**

### H2: blockerTaskID ist nicht gesetzt/gespeichert (HOCH)

**Beschreibung:** Die Tasks haben kein `blockerTaskID` in der Datenbank, daher erscheinen sie als normale Top-Level-Tasks ohne jegliche Blockade-Anzeige (kein Lock-Icon, kein Dimming, keine Einrueckung).

**Beweis DAFUER:**
- Edit-Pfad (TaskFormSheet.swift:518): `#Predicate<LocalTask> { $0.id == editID }` nutzt die **computed property** `id` (= `uuid.uuidString`). SwiftData-Predicates koennen Probleme mit computed properties haben. Wenn der Fetch fehlschlaegt, wird `blockerTaskID` NICHT gespeichert, und `try?` schluckt den Fehler.
- Wenn `blockerTaskID == nil`: isBlocked = false, Task erscheint als normaler Top-Level-Task
- Das wuerde erklaeren warum BEIDE Plattformen betroffen sind (gemeinsame Datenbank)

**Beweis DAGEGEN:**
- Create-Pfad (LocalTaskSource.swift:121) setzt `blockerTaskID` direkt vor `modelContext.insert()` + `save()` — sollte funktionieren
- Der gleiche Predicate-Pattern (`$0.id == ...`) wird an anderen Stellen erfolgreich benutzt

**Wahrscheinlichkeit: MITTEL-HOCH (fuer Edit-Pfad)**

### H3: Tasks werden DOPPELT gerendert (als Top-Level UND als Blocked) (NIEDRIG)

**Beschreibung:** `allBacklogTasks` enthaelt blockierte Tasks. `backlogTasks` = `allBacklogTasks.topLevelTasks` schliesst sie aus. Aber falls `blockerTaskID` gesetzt ist, sollten sie in `backlogTasks` NICHT erscheinen.

**Beweis DAFUER:**
- Logik ist klar: topLevelTasks filtert `blockerTaskID == nil`
- Wenn blockerTaskID gesetzt: Task erscheint NUR unter seinem Blocker

**Beweis DAGEGEN:**
- Kein Code-Pfad der das erlauben wuerde
- `topLevelTasks.filter { $0.blockerTaskID == nil }` ist eindeutig

**Wahrscheinlichkeit: NIEDRIG (0%)**

### H4: Blocker wurde erledigt -> freeDependents() hat blockerTaskID zurueckgesetzt (NIEDRIG)

**Beschreibung:** Wenn der Blocker-Task erledigt wird, ruft SyncEngine.completeTask() `freeDependents()` auf, die `blockerTaskID = nil` setzt. Danach sind alle Dependents wieder normale Top-Level-Tasks.

**Beweis DAFUER:**
- freeDependents() existiert und wird bei Completion aufgerufen
- User koennte den Blocker erledigt haben

**Beweis DAGEGEN:**
- User erwartet AKTUELL blockierte Tasks zu sehen (sonst kein Bug-Report)
- Waere ein User-Error, kein Code-Bug

**Wahrscheinlichkeit: NIEDRIG**

## Wahrscheinlichste Ursache(n)

**Primaer: H2 — blockerTaskID wird nicht korrekt gespeichert (Edit-Pfad)**

Begruendung: Wenn `blockerTaskID` nil ist, erklaert das ALLE Symptome:
- Keine Einrueckung (isBlocked = false)
- Keine Ausgrauung (opacity bleibt 1.0)
- Kein Lock-Icon (normales Circle-Icon)
- Tasks erscheinen als normale Top-Level-Tasks
- Betrifft BEIDE Plattformen (gleiche Datenbank)

**Sekundaer: H1 — Visuelle Einrueckung zu subtil**

Falls blockerTaskID DOCH gesetzt ist, koennte die 24pt-Einrueckung visuell nicht ausreichend sein. Aber dann muessten Lock-Icon und Dimming sichtbar sein.

## Debugging-Plan (WIE BEWEISE ICH MEINE HYPOTHESE?)

### H2 bestaetigen/widerlegen:
1. **Logging einbauen:** In `BacklogView.blockedTasks(for:)` einen Print einfuegen: `print("[DEPENDENCY] blockedTasks for \(blockerID): \(result.count) found")`
2. **Logging in BacklogRow:** `print("[DEPENDENCY] BacklogRow isBlocked=\(isBlocked) for task=\(item.title)")`
3. **Datenbank pruefen:** In `loadTasks()` nach sync: `print("[DEPENDENCY] Tasks with blockerTaskID: \(planItems.filter { $0.blockerTaskID != nil }.map { "\($0.title) blocked by \($0.blockerTaskID!)" })")`

**Erwartetes Ergebnis wenn H2 stimmt:** Keine Tasks mit blockerTaskID != nil im Log
**Erwartetes Ergebnis wenn H2 falsch:** Tasks mit blockerTaskID vorhanden, blockedTasks gibt Ergebnisse zurueck

### H1 bestaetigen/widerlegen:
1. Wenn H2 widerlegt (Tasks HABEN blockerTaskID), dann pruefen ob blockedRow() aufgerufen wird
2. Screenshot vergleichen: normaler Task vs. blockierter Task

## Blast Radius

- Fix an der Einrueckung betrifft: BacklogRow.swift, MacBacklogRow.swift
- Fix an der Datenspeicherung betrifft: TaskFormSheet.swift (Edit-Pfad)
- Keine anderen Features direkt betroffen
- Tests vorhanden fuer Data-Layer (TaskDependencyTests), aber KEINE visuellen Tests fuer Einrueckung

## Offene Frage an Henning

**Zentrale Frage:** Siehst du das **Lock-Icon** (Schloss statt Kreis) und sind die Tasks **ausgegraut** (halbtransparent)? Oder sehen sie KOMPLETT normal aus wie nicht-abhaengige Tasks?

- Wenn Lock-Icon + Dimming sichtbar: Problem ist NUR die Einrueckung (H1)
- Wenn alles normal aussieht: Problem ist die Datenspeicherung (H2)
