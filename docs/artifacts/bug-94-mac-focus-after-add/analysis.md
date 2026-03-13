# Bug 94: macOS — Neuer Task bekommt keinen Fokus nach Erstellen

## Bug-Beschreibung
**Plattform:** macOS
**Symptom:** Nach Task-Erstellung ueber Eingabeschlitz + "+" muss der User den neuen Task in der Liste suchen.
**Hinweis von Henning:** War bereits einmal "gefixt" — Fix war wirkungslos, Tests haben das nicht aufgedeckt.

---

## 5a. Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check):
- **Bug 76 Fix (Commit `92100f6`, 2026-03-09):** Fuegt `selectedTasks = [newTask.uuid]` hinzu. War korrekte Idee.
- **Bug 90 Fix (Commit `c5a66f4`, 2026-03-11):** Fuegt `refreshTasks()` VOR `selectedTasks` ein (fuer CloudKit-Sync). Koennte Timing verschlechtert haben.
- **Tests waren tautologisch:** Prueften nur "Task existiert in Liste", nicht "Task ist selektiert/sichtbar".
- Bug 76 wurde als ERLEDIGT archiviert obwohl der Fix nicht verifiziert war.

### Agent 2 (Datenfluss-Trace):
- `addTask()` in ContentView.swift:798-810 erstellt Task, ruft `refreshTasks()`, setzt `selectedTasks`
- Die `List(selection: $selectedTasks)` hat keinen Scroll-Mechanismus
- `selectedTasks` wird gesetzt, aber unklar ob die List den Task visuell hervorhebt UND dorthin scrollt
- `focusNewTaskField()` (Zeile 727-729) ist eine **leere No-Op Funktion** — Dead Code

### Agent 3 (Alle Schreiber):
- Nur 1 Stelle setzt `selectedTasks` nach Add: ContentView.swift:807
- MacAssignView hat ScrollViewReader + onChange + scrollTo — ABER nutzt ScrollView+LazyVStack, NICHT List
- QuickCapturePanel schliesst Panel sofort — separates Problem
- BacklogRow hat @FocusState nur fuer Inline-Edit, nicht fuer neue Tasks

### Agent 4 (Alle Szenarien):
- Race Condition zwischen refreshTasks() und Selection (SEHR HOCH)
- Filter koennte neuen Task in "Someday"-Tier verstecken (HOCH)
- NSTableView-Rendering auf macOS unterscheidet sich von iOS UITableView (MITTEL)

### Agent 5 (Blast Radius):
- iOS nutzt Modal Sheet fuer Task-Erstellung — komplett anderes Pattern
- macOS Inline-TextField ist einzigartig fuer ContentView
- **Blast Radius ist MINIMAL** — Fix betrifft nur ContentView

---

## 5b. Hypothesen

### Hypothese 1: Default-Filter "Priority" sortiert neuen Task nach ganz unten (HOCH)

**Beschreibung:** Default-Filter ist `.priority` (ContentView.swift:52). Neuer Task hat `importance=nil`, `urgency=nil` → Score ~0 → landet im Tier "Someday" am Ende der Liste. User muss bis ganz nach unten scrollen.

**Beweis DAFUER:**
- ContentView.swift:52 — `@State private var selectedFilter: SidebarFilter = .priority`
- ContentView.swift:260-262 — `regularFilteredTasks` sortiert bei `.priority` nach `scoreFor()` absteigend
- ContentView.swift:430-458 — Priority-Tiers: doNow, planSoon, eventually, someday
- Neuer Task ohne Enrichment hat Score ~0 → Tier "someday" ganz unten
- AI-Enrichment (`SmartTaskEnrichmentService`) laeuft NACH createTask() async — Score aendert sich erst spaeter

**Beweis DAGEGEN:**
- Wenn User Filter auf `.recent` gestellt hat, ist neuer Task an Position 0 (neuestes createdAt)
- Wenn Liste kurz ist, ist "Someday" trotzdem sichtbar

**Wahrscheinlichkeit:** HOCH — erklaert warum "suchen" noetig ist selbst wenn Selection funktioniert

### Hypothese 2: .tag() auf @ViewBuilder-Fragment wird von List(selection:) nicht erkannt (HOCH)

**Beschreibung:** `taskRowWithSwipe()` (Zeile 977-1016) ist ein `@ViewBuilder` der MEHRERE Top-Level-Views zurueckgibt: (1) den Haupt-Row mit `.tag(task.uuid)` und (2) einen `ForEach` der blocked dependents. Wenn `ForEach(tierTasks) { task in taskRowWithSwipe(task:) }` aufgerufen wird, produziert jede Iteration N+1 Views. SwiftUI `List(selection:)` erwartet `.tag()` auf dem DIREKTEN Kind des aeusseren ForEach — ob das bei einem @ViewBuilder-Fragment korrekt funktioniert, ist fraglich.

**Beweis DAFUER:**
- ContentView.swift:977-1016 — `taskRowWithSwipe()` gibt makeBacklogRow(task:).tag(task.uuid) + ForEach(blockedDependents) zurueck
- ContentView.swift:440-441 — `ForEach(tierTasks, id: \.uuid) { task in taskRowWithSwipe(task: task) }` → N Views pro Iteration
- SwiftUI List(selection:) basiert auf NSTableView auf macOS — Tag-Zuordnung bei Multi-View-@ViewBuilder ist undokumentiert

**Beweis DAGEGEN:**
- Das identische Pattern wird auch in der NextUp-Section (Zeile 361-386) verwendet und Selection funktioniert dort (per Swipe-Action Zeile 380)
- SwiftUI koennte @ViewBuilder-Fragmente flachen und .tag() korrekt propagieren

**Wahrscheinlichkeit:** HOCH — aber schwer zu beweisen ohne Laufzeit-Test

### Hypothese 3: List scrollt nicht zum selektierten Item (MITTEL-HOCH)

**Beschreibung:** macOS `List(selection:)` scrollt NICHT automatisch zum selektierten Item. Wenn der Task off-screen ist (z.B. in "Someday"-Tier), sieht der User keine Hervorhebung.

**WICHTIG: MacAssignView ist KEIN valider Beweis!** MacAssignView nutzt `ScrollView + LazyVStack`, NICHT `List`. SwiftUI `List` auf macOS ist NSTableView-backed — NSTableView hat eigene Scroll-Logik die ScrollViewReader ignorieren koennte.

**Beweis DAFUER:**
- Kein `ScrollViewReader` in ContentView
- macOS NSTableView scrollt nicht automatisch bei programmatischer Selection-Aenderung
- Apple-Doku: `List(selection:)` garantiert kein Auto-Scroll

**Beweis DAGEGEN:**
- Manche macOS-Versionen (14+) scrollen bei Selection-Aenderung
- Wenn Task im sichtbaren Bereich ist, braucht man keinen Scroll

**Wahrscheinlichkeit:** MITTEL-HOCH

### Hypothese 4: Timing — refreshTasks() und selectedTasks in falscher Reihenfolge (MITTEL)

**Beschreibung:** `refreshTasks()` (Zeile 806) ersetzt das gesamte `tasks` Array. SwiftUI re-rendert die List. Wenn `selectedTasks` (Zeile 807) gesetzt wird WAEHREND die List re-rendert, koennte die Selection verloren gehen.

**Beweis DAFUER:**
- Bug 90 hat `refreshTasks()` eingefuegt — vorher war nur `selectedTasks` (Bug 76 Fix)
- `refreshTasks()` macht `modelContext.save()` + fetch → ersetzt `tasks` komplett

**Beweis DAGEGEN:**
- `refreshTasks()` ist synchron (kein await) — Zeile 87-98
- Beides passiert im selben `Task {}` Block, sollte sequentiell sein

**Wahrscheinlichkeit:** MITTEL

---

## 5c. Wahrscheinlichste Ursachen

**Kombination von Hypothese 1 + 3 (Primaer) + moeglicherweise Hypothese 2:**

1. Default-Filter ist `.priority` → neuer Task landet in "Someday" ganz unten
2. macOS List scrollt NICHT automatisch dorthin
3. Resultat: Task ist selektiert aber unsichtbar → User muss suchen

**Warum die anderen weniger wahrscheinlich:**
- Hypothese 2 (tag-Problem) — wenn tags komplett nicht funktionieren wuerden, wuerde Selection generell nie funktionieren. Aber Selection per Klick funktioniert ja.
- Hypothese 4 (Timing) — beide Operationen sind synchron im selben Block, Timing-Problem ist unwahrscheinlich.

---

## 5d. Debugging-Plan

### Hypothese 1+3 bestaetigen (Priority-Filter + kein Scroll):
- **Test 1:** macOS App oeffnen mit .priority Filter, 20+ Tasks. Neuen Task ueber "+" anlegen.
  - BEOBACHTEN: In welchem Tier landet der Task? (Erwartung: "Someday" ganz unten)
  - BEOBACHTEN: Ist der Task blau hervorgehoben? (Selection vorhanden?)
  - BEOBACHTEN: Scrollt die Liste automatisch? (Erwartung: NEIN)
- **Test 2:** Filter auf `.recent` wechseln, dann neuen Task anlegen.
  - BEOBACHTEN: Task sollte an Position 0 sein (neuestes createdAt) → sofort sichtbar
- **Logging:** `print("[addTask] selectedTasks set to \(newTask.uuid)")` an Zeile 807

### Hypothese 1+3 widerlegen:
- Wenn der Task AUCH bei `.recent` Filter unsichtbar ist → Problem liegt nicht am Filter
- Wenn der Task in "Someday" ist aber BLAU hervorgehoben → Selection funktioniert, nur Scroll fehlt
- Wenn der Task in "Someday" ist und NICHT hervorgehoben → Hypothese 2 (tag-Problem) oder Hypothese 4 (Timing)

### Plattform: macOS

---

## 5e. Blast Radius

**Minimal:**
- Nur `FocusBloxMac/ContentView.swift` betroffen
- iOS hat komplett anderes Pattern (Modal Sheet)
- QuickCapturePanel hat aehnliches Symptom aber andere Ursache (setzt nie selectedTasks)
- **Achtung:** ScrollViewReader um eine macOS List wrappen koennte nicht funktionieren (NSTableView-Backend) — Alternative: `.scrollPosition(id:)` API (macOS 14+) oder `revealSelection()` verwenden

---

## 5f. Challenge-Ergebnisse (Devil's Advocate)

### Runde 1 — Verdict: LUECKEN

Gefundene Luecken (eingearbeitet):
1. **MacAssignView ist KEIN valider Beweis** — nutzt ScrollView+LazyVStack, nicht List
2. **taskRowWithSwipe() @ViewBuilder-Fragment** — .tag() auf Multi-View @ViewBuilder koennte nicht funktionieren
3. **Default-Filter .priority** — neuer Task ohne Score landet in "Someday" ganz unten (war vorher als "MITTEL" unterschaetzt)
4. **Inspector-Check fehlt** — unklar ob Inspector (rechte Spalte) den neuen Task zeigt → wuerde Selection beweisen

### Offene Fragen:
- Funktioniert `scrollTo()` oder `.scrollPosition(id:)` mit macOS SwiftUI `List`?
- Zeigt der Inspector den neuen Task nach Erstellung? (Wuerde beweisen dass Selection funktioniert)
