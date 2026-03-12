# Tests: Monster Coach Phase 3a — Intention-basierter Backlog-Filter

> Erstellt: 2026-03-12
> TDD-Pflicht: Tests ZUERST schreiben (RED), dann implementieren (GREEN)

---

## Unit Tests — `FocusBloxTests/IntentionFilterTests.swift`

### UT-01: Survival ueberstimmt alles

```
func test_survival_overridesAllOtherFilters()
// Gegeben: activeOptions = [.survival, .fokus, .bhag]
// Erwartung: matchesIntentionFilter(task) == true fuer JEDEN Task
// (kein Filter aktiv)
```

### UT-02: Fokus zeigt nur NextUp-Tasks

```
func test_fokus_onlyShowsNextUpTasks()
// Gegeben: activeOptions = [.fokus]
// Task mit isNextUp = true → sichtbar
// Task mit isNextUp = false → unsichtbar
```

### UT-03: BHAG zeigt Tasks mit importance 3

```
func test_bhag_showsHighImportanceTasks()
// Gegeben: activeOptions = [.bhag]
// Task mit importance = 3 → sichtbar
// Task mit importance = 2 → unsichtbar
```

### UT-04: BHAG zeigt oft verschobene Tasks

```
func test_bhag_showsHighlyRescheduledTasks()
// Gegeben: activeOptions = [.bhag]
// Task mit rescheduleCount = 2 → sichtbar
// Task mit rescheduleCount = 0 → unsichtbar
// Task mit rescheduleCount = 5 → sichtbar
```

### UT-05: Growth filtert auf Kategorie Lernen

```
func test_growth_filtersOnLearningCategory()
// Gegeben: activeOptions = [.growth]
// Task mit taskType = "learning" → sichtbar
// Task mit taskType = "income" → unsichtbar
// Task mit taskType = "" → unsichtbar
```

### UT-06: Connection filtert auf Kategorie Geben

```
func test_connection_filtersOnGivingBackCategory()
// Gegeben: activeOptions = [.connection]
// Task mit taskType = "giving_back" → sichtbar
// Task mit taskType = "maintenance" → unsichtbar
```

### UT-07: Multi-Select — ODER-Logik

```
func test_multiSelect_usesUnionLogic()
// Gegeben: activeOptions = [.fokus, .growth]
// Task mit isNextUp = true, taskType = "income" → sichtbar (fokus)
// Task mit isNextUp = false, taskType = "learning" → sichtbar (growth)
// Task mit isNextUp = false, taskType = "income" → unsichtbar
```

### UT-08: Balance hat keinen Task-Filter

```
func test_balance_showsAllTasks()
// Gegeben: activeOptions = [.balance]
// Task egal welcher Art → sichtbar (balance filtert nicht)
```

### UT-09: Leere Filter-Liste bedeutet kein Filter

```
func test_emptyFilters_showsAllTasks()
// Gegeben: activeOptions = []
// Erwartung: intentionFilterActive == false
```

### UT-10: BHAG-Schwellwert ist genau 2

```
func test_bhag_rescheduleThresholdIsTwo()
// rescheduleCount = 1 → NICHT sichtbar durch bhag
// rescheduleCount = 2 → sichtbar durch bhag
```

---

## UI Tests — `FocusBloxUITests/IntentionFilterUITests.swift`

**Voraussetzung:** Launch-Argument `-UITesting -CoachModeEnabled`
**Seed-Daten:** Mock-Tasks muessen folgende Varianten enthalten (in seedUITestData oder als neuer Test-Seed-Zweig):
- Task mit isNextUp = true (fuer Fokus-Filter-Test)
- Task mit importance = 3 (fuer BHAG-Filter-Test)
- Task mit taskType = "learning" (fuer Growth-Filter-Test)
- Task mit taskType = "giving_back" (fuer Connection-Filter-Test)

### UI-01: Intention setzen wechselt zum Backlog-Tab

```
func test_settingIntention_switchesToBacklogTab()
// 1. App starten mit -UITesting -CoachModeEnabled
// 2. Review-Tab antippen
// 3. MorningIntentionCard ist sichtbar (accessibilityIdentifier: "morningIntentionCard")
// 4. Intention auswaehlen: intentionChip_fokus antippen
// 5. "Intention setzen" Button antippen (setIntentionButton)
// 6. ERWARTUNG: Backlog-Tab ist aktiv (mainTabView zeigt BacklogView)
//    Pruefung: Element mit ID "addTaskButton" ist sichtbar (nur in BacklogView)
```

### UI-02: Filter-Chip erscheint im Backlog nach Fokus-Intention

```
func test_fokusIntention_showsFilterChipInBacklog()
// 1. Fokus-Intention setzen (wie UI-01)
// 2. Im Backlog-Tab: intentionFilterChip_fokus ist sichtbar
```

### UI-03: Filter-Chip kann abgeschaltet werden

```
func test_filterChip_canBeDismissed()
// 1. Fokus-Intention setzen
// 2. Im Backlog: removeIntentionFilter_fokus Button antippen
// 3. ERWARTUNG: intentionFilterChip_fokus ist nicht mehr sichtbar
```

### UI-04: Survival zeigt keine Filter-Chips

```
func test_survivalIntention_showsNoFilterChips()
// 1. Survival-Intention setzen (intentionChip_survival)
// 2. "Intention setzen" antippen
// 3. Im Backlog: kein intentionFilterChip_* Element sichtbar
```

### UI-05: Fokus-Filter zeigt nur NextUp-Tasks in der Backlog-Liste

```
func test_fokusFilter_onlyShowsNextUpTasksInList()
// Voraussetzung: Seed-Daten enthalten mindestens einen NextUp-Task
//               und mindestens einen Nicht-NextUp-Task
// 1. Fokus-Intention setzen
// 2. Im Backlog: nur Tasks aus Next-Up-Section sichtbar
//    (Tasks in "Backlog"-Sections sind nicht sichtbar)
// Pruefung: kein Element mit Backlog-Section-Header sichtbar
//           ODER alle Tasks die kein isNextUp haben, sind nicht gelistet
```

### UI-06: Alle Filter-Chips abschalten entfernt die Chip-Leiste

```
func test_removingAllChips_hidesChipBar()
// 1. Growth-Intention setzen
// 2. removeIntentionFilter_growth antippen
// 3. ERWARTUNG: keine intentionFilterChip_* Elemente sichtbar
// 4. Normaler Backlog (ungefiltert) ist wieder sichtbar
```

---

## AppStorage-Keys (Referenz fuer Tests)

| Key | Typ | Zweck |
|-----|-----|-------|
| `intentionJustSet` | Bool | Signal: Tab-Wechsel ausfuehren |
| `intentionFilterOptions` | String | Kommagetrennte rawValues aktiver Filter |

**Reset in UI-Tests:**
Beide Keys muessen in `FocusBloxApp.resetUserDefaultsIfNeeded()` unter `-UITesting` geloescht werden.

---

## Test-Datenpraeparation fuer UI-Tests

Folgende Mock-Tasks muessen in `seedUITestData` ergaenzt werden (oder in einem separaten Intention-Filter-Seed):

```swift
// Fokus-Filter-Test: NextUp-Task bereits vorhanden ([MOCK] Task 1 #30min)

// BHAG-Filter-Test: High-importance Task bereits vorhanden ([MOCK] Task 1 mit importance=3)

// Growth-Filter-Test
let growthTask = LocalTask(title: "[MOCK] Lernen Task", importance: 2, estimatedDuration: 30, urgency: "not_urgent")
growthTask.taskType = "learning"
growthTask.isNextUp = false

// Connection-Filter-Test
let connectionTask = LocalTask(title: "[MOCK] Geben Task", importance: 2, estimatedDuration: 20, urgency: "not_urgent")
connectionTask.taskType = "giving_back"
connectionTask.isNextUp = false
```
