# Bug 94: macOS — Neuer Task bekommt keinen Fokus nach Erstellen

## Bug-Beschreibung
**Plattform:** macOS
**Symptom:** Nach Task-Erstellung ueber Eingabeschlitz + "+" muss der User den neuen Task in der Liste suchen.
**Hinweis von Henning:** War bereits einmal "gefixt" — Fix war wirkungslos, Tests haben das nicht aufgedeckt.

---

## 5a. Zusammenfassung der Agenten-Ergebnisse (Runde 2)

### Agent 1 (Wiederholungs-Check):
- **Bug 76 Fix (Commit `92100f6`, 2026-03-09):** `selectedTasks = [newTask.uuid]` — korrekte Idee, aber NSTableView scrollt nicht.
- **Bug 90 Fix (Commit `c5a66f4`, 2026-03-11):** Fuegt `refreshTasks()` VOR Selection ein.
- **Bug 94 Workarounds (Commit `71c349a`, 2026-03-13):** Fuegt `scrollToTaskID`, `inspectorOverrideTaskID`, `.scrollPosition()` hinzu.
- **Tests waren tautologisch:** 3 neue Tests existieren, ALLE FAILING (TDD RED state).
- **Dead Code:** `focusNewTaskField()` (Zeile 727-729) ist leere No-Op.
- **Kritisch:** `selectedTasks` wird NICHT MEHR gesetzt nach Erstellung — nur override + scroll IDs.

### Agent 2 (Datenfluss-Trace):
- `addTask()` ContentView.swift:763-777: Async Task → `createTask()` → `refreshTasks()` → set overrides
- `createTask()` in LocalTaskSource:87-142 ist async: AI-Enrichment + Title-Improvement + Spotlight = lange Laufzeit
- `refreshTasks()` ersetzt `@State tasks` komplett → List rebuilt → NSTableView kann Selection resetten
- `.scrollPosition(id: $scrollToTaskID, anchor: .center)` auf Line 490 — unklar ob das mit NSTableView-backed List funktioniert
- Inspector-Fallback via `selectedTask` computed property (Lines 165-175) nutzt `inspectorOverrideTaskID`

### Agent 3 (Alle Schreiber):
- **14+ Write-Stellen** fuer Selection/Scroll/Override State
- `selectedTasks` wird NICHT in addTask() gesetzt (Lines 773-775 setzen nur override + scroll)
- `onChange(of: selectedTasks)` auf Line 492-496 loescht `inspectorOverrideTaskID` bei manueller Selektion
- QuickCapturePanel:181-198 — setzt WEDER scroll noch override (separates Problem, out of scope)
- MacAssignView:87-112 nutzt `ScrollViewReader + proxy.scrollTo()` — alternatives Pattern das FUNKTIONIERT

### Agent 4 (Alle Szenarien — 9 bestaetigte):
1. **Async Task Creation Timing Gap** — createTask() ist async, UI-Updates erst danach
2. **@Query Rebuild in TaskInspector** — unabhaengig von ContentView.refreshTasks()
3. **NSTableView Selection Reset** — List selection binding resettet bei Rebuild
4. **Computed Property Re-Sorting** — Sorting invalidiert List Identity
5. **List Identity Loss** — .tag() muss beim Render-Zeitpunkt vorhanden sein
6. **FEHLENDE selectedTasks-Zuweisung** — addTask() setzt selectedTasks NICHT
7. **Kein withAnimation/MainActor** — State-Updates werden gebootcht, koennte Fenster erzeugen
8. **scrollTo vor Render** — scrollToTaskID gesetzt bevor Row existiert
9. **Override-Clearing** — onChange loescht override bei jeder Selection-Aenderung

### Agent 5 (Blast Radius):
- **Scope: MINIMAL** — nur macOS ContentView betroffen
- iOS nutzt Modal Sheet (komplett anderes Pattern)
- macOS MenuBarView hat addTask() OHNE scroll/override (separater Pfad, nicht Bug 94)
- MacAssignView hat funktionierendes ScrollViewReader-Pattern als Referenz
- **Max 2 Dateien, ~50-100 LoC**

---

## 5b. Hypothesen (aktualisiert)

### Hypothese 1: Neuer Task in "Someday"-Tier off-screen + kein Scroll (HOCH)

**Beschreibung:** Default-Filter `.priority` (Line 52). Neuer Task hat `importance=nil, urgency=nil` → Score ~0 → Tier "Someday" (Score 0-9) ganz am Ende. `.scrollPosition(id:)` funktioniert moeglicherweise nicht mit NSTableView-backed List.

**Beweis DAFUER:**
- Line 52: `selectedFilter: SidebarFilter = .priority`
- Line 268-270: `regularFilteredTasks` sortiert bei `.priority` nach `scoreFor()` absteigend
- PriorityTier.from(score:): Score 0-9 = `.someday` = letzter Tier
- Kein AI-Enrichment-Ergebnis zum Zeitpunkt der Anzeige (Enrichment ist async)
- Tests FAILING beweisen dass Scroll nicht funktioniert

**Beweis DAGEGEN:**
- Bei `.recent` Filter waere Task an Position 0
- Bei kurzer Liste ist "Someday" sichtbar

**Wahrscheinlichkeit:** HOCH

### Hypothese 2: selectedTasks wird NICHT gesetzt → keine List-Selektion (HOCH)

**Beschreibung:** Im aktuellen Code (Line 773-775) wird `selectedTasks` NICHT gesetzt nach Erstellung. Nur `inspectorOverrideTaskID` und `scrollToTaskID`. Die List hat also keinen Grund, den neuen Task zu selektieren (blau hervorzuheben).

**Beweis DAFUER:**
- Line 773-775: Nur `inspectorOverrideTaskID` und `scrollToTaskID` — KEIN `selectedTasks = [newTask.uuid]`
- Frueher (Bug 76 Fix) wurde selectedTasks gesetzt, wurde aber entfernt mit Kommentar "NSTableView resets List selection binding"
- Ohne selectedTasks-Zuweisung: kein blaues Highlight, kein visueller Fokus in der Liste

**Beweis DAGEGEN:**
- Inspector-Override zeigt den Task im Inspector an (rechte Spalte)
- Aber Inspector-Anzeige ≠ List-Selektion

**Wahrscheinlichkeit:** HOCH — erklaert warum auch der Inspector-Override allein nicht reicht

### Hypothese 3: .scrollPosition(id:) funktioniert nicht mit macOS List (HOCH)

**Beschreibung:** `.scrollPosition(id:)` ist eine iOS 17+ / macOS 14+ API. macOS `List` ist NSTableView-backed. Es ist unklar ob `.scrollPosition()` mit NSTableView funktioniert — es ist primaer fuer ScrollView/LazyVStack gedacht.

**Beweis DAFUER:**
- MacAssignView nutzt `ScrollViewReader { proxy in ScrollView { LazyVStack { ... } } }` und `proxy.scrollTo()` — das FUNKTIONIERT
- ContentView nutzt `List(selection:)` mit `.scrollPosition()` — das FAILED (Tests beweisen es)
- Apple-Doku: `.scrollPosition(id:)` ist in der ScrollView-Familie dokumentiert, nicht explizit fuer List

**Beweis DAGEGEN:**
- Einige Entwickler berichten dass es mit List funktioniert (iOS)
- macOS 15+ koennte Unterstuetzung verbessert haben

**Wahrscheinlichkeit:** HOCH — Tests beweisen dass es nicht scrollt

### Hypothese 4: Race Condition — State-Updates vor View-Render (MITTEL)

**Beschreibung:** `scrollToTaskID` wird gesetzt bevor die List den neuen Row gerendert hat. SwiftUI batched State-Updates — moeglicherweise wird scrollToTaskID VOR dem List-Update konsumiert und dann ignoriert.

**Beweis DAFUER:**
- Kein `withAnimation` oder `DispatchQueue.main.asyncAfter` fuer delayed scroll
- refreshTasks() → sofort scrollToTaskID setzen → List rebuilt noch → scroll-target existiert noch nicht

**Beweis DAGEGEN:**
- SwiftUI sollte State-Batch in einem Render-Cycle zusammenfassen
- scrollToTaskID ist @State, aendert sich → View update enthält beides

**Wahrscheinlichkeit:** MITTEL

---

## 5c. Wahrscheinlichste Ursachen

**Kombination von Hypothese 1 + 2 + 3:**

1. **Hypothese 2:** `selectedTasks` wird nicht gesetzt → Task hat kein blaues Highlight in der Liste
2. **Hypothese 3:** `.scrollPosition(id:)` funktioniert nicht mit NSTableView-backed List → kein Auto-Scroll
3. **Hypothese 1:** Default-Filter `.priority` sortiert Task nach "Someday" ganz unten → off-screen

**Resultat:** Task wird erstellt, ist aber weder selektiert noch sichtbar. Inspector zeigt ihn via Override, aber der User sieht in der Liste nichts.

**Warum Hypothese 4 weniger wahrscheinlich:**
- Selbst wenn Timing perfekt waere, wuerden H2+H3 den Bug trotzdem verursachen
- H4 ist nur relevant wenn H2+H3 gefixt sind

---

## 5d. Fix-Strategie (Empfehlung)

### Kernproblem: macOS List + NSTableView = kein zuverlaessiger programmatischer Scroll

**Loesung: Statt zu versuchen zum Task zu scrollen — den Task dorthin bringen wo der User hinschaut.**

### Ansatz A: Neuen Task als "Next Up" markieren (EMPFOHLEN)

Nach Erstellung den Task temporaer in die "Next Up"-Sektion setzen:
- Next Up ist IMMER oben in der Liste sichtbar (Line 365-420)
- User sieht den Task sofort
- Task kann dort bearbeitet werden (Importance, Urgency setzen)
- Danach kann er aus Next Up entfernt werden → wandert in korrekten Tier

**Vorteil:** Funktioniert unabhaengig von Scroll-API und Filter
**Nachteil:** Aendert Semantik von "Next Up" leicht

### Ansatz B: ScrollViewReader statt .scrollPosition() + selectedTasks setzen

MacAssignView beweist: `ScrollViewReader { proxy in ... proxy.scrollTo(id) }` funktioniert mit ScrollView+LazyVStack.
ABER: ContentView nutzt `List` (NSTableView), nicht ScrollView.

**Option B1:** List durch ScrollView+LazyVStack ersetzen
- Grosser Umbau, hohes Risiko, ausserhalb Scoping Limits

**Option B2:** ScrollViewReader um List wrappen und testen
- `.scrollTo()` koennte mit NSTableView funktionieren — muss getestet werden
- Plus: `selectedTasks = [newTask.uuid]` WIEDER setzen (wurde faelschlich entfernt)
- Plus: Delayed scroll via `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)`

### Ansatz C: Nach Erstellung Filter temporaer auf ".recent" wechseln

- Neuer Task hat neustes `createdAt` → ist Position 0 bei `.recent` Filter
- Nach 5 Sekunden oder naechster Interaktion: Filter zurueck auf vorherige Auswahl

**Vorteil:** Einfach, zuverlaessig
**Nachteil:** Unerwarteter Filter-Wechsel kann User verwirren

---

## 5e. Blast Radius

**Minimal:**
- Nur `FocusBloxMac/ContentView.swift` betroffen (1 Datei fuer Fix)
- iOS hat komplett anderes Pattern (Modal Sheet) — NICHT betroffen
- QuickCapturePanel hat aehnliches Symptom aber anderen Scope
- Max ~50-100 LoC Aenderung

---

## 5f. Challenge-Ergebnisse

### Runde 1 (vorherige Session) — Verdict: LUECKEN
- MacAssignView ist kein valider Beweis fuer List-Scroll
- taskRowWithSwipe() @ViewBuilder-Fragment-Thema identifiziert
- Default-Filter .priority war unterschaetzt → hochgestuft

### Runde 2 — Verdict: LUECKEN

Gefundene Luecken:
1. **NSTableView-Reset-Behauptung unbewiesen:** Kein isolierter Test ob `selectedTasks = [newTask.uuid]` mit `DispatchQueue.main.async` nach refreshTasks() tatsaechlich resettet wird. Wurde nie einzeln getestet.
2. **Test abgeschwaecht:** `testNewTaskIsVisibleInListAfterCreation` (TDD-RED) wurde durch `testNewTaskExistsInListAfterCreation` ersetzt — prueft nur Existenz, nicht Sichtbarkeit/Scroll.
3. **Ansatz A (Next Up) hat Semantik-Problem:** "Next Up" = bewusst priorisiert. Automatisch jeden neuen Task dort einzusortieren widerspricht der Semantik. Ausserdem fehlt `nextUpSortOrder`.
4. **Einfachste Loesung nie getestet:** `selectedTasks = [newTask.uuid]` mit async Delay wurde nie isoliert ausprobiert.
5. **Filter-Edge-Cases:** `.overdue` und `.recurring` Filter wuerden neuen Task IMMER verstecken — kein Ansatz adressiert das.
6. **QuickCapturePanel als Referenz:** Hat `isNextUp = true` als Workaround — beweist dass Scroll-Problem bekannt war.

### Aktualisierte Fix-Strategie nach Challenge

**Neuer Ansatz D (EMPFOHLEN): Minimaler Fix — selectedTasks + async Delay + ScrollViewReader**

1. `selectedTasks = [newTask.uuid]` WIEDER setzen (war faelschlich entfernt)
2. In `DispatchQueue.main.async {}` wrappen fuer 1 Render-Cycle Verzoegerung
3. `ScrollViewReader` um die List wrappen (wie MacAssignView) + `proxy.scrollTo(newTask.uuid)`
4. `inspectorOverrideTaskID` als Fallback BEHALTEN fuer den Fall dass NSTableView resettet
5. Bei Overdue/Recurring Filter: nach Erstellung AUTOMATISCH auf `.recent` wechseln

**Warum besser als Ansatz A-C:**
- Einfachster Ansatz der nie isoliert getestet wurde
- Kein Semantik-Problem mit "Next Up"
- Kein grosser Umbau (kein ScrollView+LazyVStack noetig)
- Adressiert alle 3 Hauptursachen: Selection (H2), Scroll (H3), Filter-Position (H1)
