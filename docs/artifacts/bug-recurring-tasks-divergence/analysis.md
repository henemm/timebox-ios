# Bug-Analyse: Wiederkehrende Tasks — macOS-Divergenz

## Zusammenfassung der Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- Recurring Tasks wurden in 3 Phasen implementiert (Feb 16-17, 2026)
- Phase 1A: Core Instance Generation + RecurrenceService
- Phase 1B: Series-Konzept (recurrenceGroupID), Delete/Edit Dialoge, Backlog-Filter "Wiederkehrend"
- Dedup-Bug wurde gefunden und gefixt (0e37f2f)
- Kein bekannter Regression — Implementation galt als "production-ready"
- Ein offener Minor: Quick-Edit Recurrence-Params (nicht blockernd)

### Agent 2: Datenfluss-Trace
- iOS nutzt `LocalTaskSource.fetchIncompleteTasks()` (Zeilen 34-53) — filtert zukuenftige recurring Tasks
- macOS ContentView nutzt `@Query` direkt (Zeile 36) — **KEIN Filter**
- Der "Wiederkehrend" ViewMode existiert auf iOS, **FEHLT auf macOS**
- Die Filterung passiert upstream in LocalTaskSource — Views operieren auf bereits gefilterten Daten

### Agent 3: Alle Schreiber
- 3 Completion-Pfade: SyncEngine.completeTask(), FocusBlockActionService.completeTask(), TaskInspector (macOS)
- Alle rufen korrekt RecurrenceService.createNextInstance() auf
- TaskInspector (macOS) ist platform-spezifisch, nutzt aber denselben RecurrenceService

### Agent 4: Alle Szenarien
- **ROOT CAUSE BESTAETIGT:** macOS ContentView nutzt `@Query` statt `LocalTaskSource`
- iOS: View -> SyncEngine -> LocalTaskSource (GEFILTERT) -> Database
- macOS: View -> @Query -> Database (KEIN FILTER)
- Jeder wiederkehrende Task mit dueDate in der Zukunft ist auf macOS sofort sichtbar

### Agent 5: Blast Radius
- macOS ContentView + SidebarView haben keinen "Wiederkehrend"-Filter
- iOS BacklogView hat ViewMode.recurring — macOS SidebarFilter hat das nicht
- Fix ist sicher: Focus Blocks, Notifications, Reminders Sync sind unabhaengig
- Einziger kritischer Punkt: macOS filteredTasks computed property

## Ueberlappungen der Ergebnisse

Alle 5 Agenten bestaetigten unabhaengig voneinander denselben Kern:
- **macOS ContentView.swift:36 nutzt `@Query` direkt** statt durch den shared LocalTaskSource-Filter zu gehen
- **macOS SidebarView hat keinen "Wiederkehrend"-Filter** im Gegensatz zu iOS ViewMode.recurring

---

## ALLE moeglichen Ursachen

### Hypothese 1: macOS umgeht LocalTaskSource-Filter (PRIMAER)
**Beschreibung:** macOS ContentView.swift:36 nutzt `@Query(sort: \LocalTask.createdAt, order: .reverse)` direkt auf der Datenbank. iOS nutzt `LocalTaskSource.fetchIncompleteTasks()` das recurring Tasks mit `dueDate >= startOfTomorrow` herausfiltert.

**Beweis DAFUER:**
- ContentView.swift:36: `@Query(sort: \LocalTask.createdAt, order: .reverse) private var tasks: [LocalTask]`
- ContentView.swift:101-141: `filteredTasks` computed property — filtert nur nach `isCompleted`, Kategorie, etc. — **kein recurring-dueDate-Filter**
- LocalTaskSource.swift:41-52: iOS-Filter existiert und funktioniert korrekt

**Beweis DAGEGEN:** Keiner. Der Code ist eindeutig.

**Wahrscheinlichkeit:** **HOCH (99%)**

### Hypothese 2: Fehlender "Wiederkehrend"-Filter in macOS Sidebar
**Beschreibung:** iOS hat `ViewMode.recurring` in BacklogView (Zeile 14). macOS SidebarFilter hat kein `.recurring` Case.

**Beweis DAFUER:**
- BacklogView.swift:14: `case recurring = "Wiederkehrend"` existiert
- SidebarView.swift:30-38: `enum SidebarFilter` hat .all, .category, .nextUp, .tbd, .overdue, .upcoming, .completed, .smartPriority — **kein .recurring**
- ContentView.swift:101-141: `filteredTasks` hat keinen recurring-Case

**Beweis DAGEGEN:** Keiner.

**Wahrscheinlichkeit:** **HOCH (100%)**

### Hypothese 3: Timing/Race-Condition bei CloudKit-Sync
**Beschreibung:** Zukunfts-Instanzen koennten per CloudKit ankommen und kurzzeitig sichtbar sein, bevor der Filter greift.

**Beweis DAFUER:**
- SwiftData + CloudKit hat bekannte Timing-Probleme (Bug 38)
- `@Query` reagiert sofort auf DB-Aenderungen

**Beweis DAGEGEN:**
- Auf iOS wuerde der Filter greifen, da fetchIncompleteTasks() bei jedem Aufruf filtert
- Das Problem ist persistent, nicht kurzzeitig

**Wahrscheinlichkeit:** **NIEDRIG** — nicht die Hauptursache, koennte aber den Effekt verstaerken

---

## Wahrscheinlichste Ursache(n)

**Primaer: Hypothese 1 + 2 kombiniert**

Das Problem hat ZWEI Facetten:
1. **macOS zeigt zukunftige recurring Tasks** weil `@Query` den shared Filter umgeht
2. **macOS hat keinen "Wiederkehrend"-Filter** in der Sidebar

Hypothese 3 ist irrelevant — das Problem ist strukturell, nicht timing-bedingt.

---

## Blast Radius

### Direkt betroffen:
- macOS ContentView: Alle Filter-Modi (all, category, nextUp, etc.) zeigen zukunftige recurring Tasks
- macOS Sidebar Badges: tbdCount, overdueCount etc. zaehlen zukunftige recurring Tasks mit

### Nicht betroffen:
- iOS BacklogView (funktioniert korrekt via LocalTaskSource)
- Focus Blocks (fetchen per Task-ID)
- Notifications (unabhaengig)
- Reminders Sync (unabhaengig)
- RecurrenceService (korrekt)
- watchOS (eigenes Modell)

### Fix-Risiko:
- **Niedrig** — der Fix betrifft nur macOS ContentView/SidebarView
- Keine Seiteneffekte auf andere Features zu erwarten
