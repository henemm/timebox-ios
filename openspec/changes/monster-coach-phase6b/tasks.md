# Tasks: Monster Coach Phase 6b — MacCoachBacklogView

**Erstellt:** 2026-03-14
**Status:** Geplant

---

## Implementierungs-Checkliste

### Phase A: MacBacklogRow erweitern

- [ ] `FocusBloxMac/MacBacklogRow.swift` — `disciplineColor: Color?` Parameter ergaenzen (analog zu iOS `BacklogRow.disciplineColor`)
- [ ] Checkbox-Icon-Farbe nutzt `disciplineColor` wenn gesetzt (`.foregroundStyle(disciplineColor ?? .secondary)`)
- [ ] Font-Weight bei disciplineColor: `.semibold` (wie iOS)

### Phase B: MacCoachBacklogView erstellen

- [ ] Neue Datei `FocusBloxMac/MacCoachBacklogView.swift` anlegen
- [ ] State: `@State private var tasks: [LocalTask] = []` (wie ContentView.tasks Pattern)
- [ ] `@AppStorage("intentionFilterOptions")` fuer Ranking-Logik
- [ ] `refreshTasks()` — gleiche Fetch-Logik wie ContentView (LocalTask fetch aus modelContext)
- [ ] `intention: DailyIntention` computed property → `DailyIntention.load()`
- [ ] `primaryIntention: IntentionOption?` — erstes Element aus intentionFilterOptions
- [ ] `relevantTasks: [LocalTask]` — Tasks die IntentionOption.matchesFilter() matchen
- [ ] `otherTasks: [LocalTask]` — alle anderen incomplete Tasks
- [ ] `monsterHeader` ViewBuilder — Monster-Bild + Label (analog iOS, gleiche accessibilityIdentifier)
- [ ] `coachTaskList` List mit Sektionen "Dein Schwerpunkt" + "Weitere Tasks"
- [ ] Task-Zeilen: `MacBacklogRow` mit `disciplineColor` aus `Discipline.classifyOpen()`
- [ ] Context-Menu auf Zeilen: Bearbeiten / Als erledigt markieren / Loeschen (kein SwipeActions auf macOS)
- [ ] Quick-Add Bar oben (wie in normalem backlogView)
- [ ] `.task { refreshTasks() }` beim Erscheinen
- [ ] accessibilityIdentifier "coachMonsterHeader", "coachTaskList", "coachRelevantSection", "coachOtherSection"
- [ ] Zu Xcode-Projekt hinzufuegen (FocusBloxMac Target)

### Phase C: ContentView integrieren

- [ ] `@AppStorage("coachModeEnabled")` in ContentView.swift ergaenzen
- [ ] In `mainContentView` Switch bei `case .backlog:`: bedingte Weiche `coachModeEnabled ? MacCoachBacklogView() : backlogView`
- [ ] Sidebar-Verhalten: bei `coachModeEnabled && selectedSection == .backlog` vereinfachte Sidebar anzeigen (Eintrag "Backlog" ohne Filter-Optionen)

### Phase D: SidebarView anpassen

- [ ] Optionalen `isCoachMode: Bool` Parameter in SidebarView ergaenzen
- [ ] Bei `isCoachMode == true`: nur einen "Backlog" Label-Eintrag anzeigen statt der 5 Filter-Optionen
- [ ] ContentView uebergibt `isCoachMode: coachModeEnabled`

### Phase E: Tests schreiben (TDD RED zuerst)

- [ ] Neue Testdatei `FocusBloxUITests/MacCoachBacklogUITests.swift` anlegen
- [ ] Test 1: Coach-Modus AN → Monster-Header (`coachMonsterHeader`) sichtbar im Backlog
- [ ] Test 2: Coach-Modus AUS → Monster-Header NICHT sichtbar
- [ ] Test 3: Keine Intention → Hinweis-Text "Starte deinen Tag" sichtbar in Monster-Header
- [ ] Test 4: Intention gesetzt → `coachRelevantSection` vorhanden

### Phase F: Validierung

- [ ] Build erfolgreich (beide Targets: iOS + macOS)
- [ ] Alle 4 UI Tests gruen
- [ ] Bestehende macOS UI Tests unveraendert gruen
- [ ] docs/ACTIVE-todos.md aktualisieren: Phase 6b auf ERLEDIGT setzen
- [ ] Commit: `feat: Monster Coach Phase 6b — MacCoachBacklogView`

---

## Reihenfolge

A → B → E (TDD RED) → C → D → E (gruen machen) → F

Schritte A+B+E koennen gleichzeitig vorbereitet werden, bevor C+D die Integration herstellen.
