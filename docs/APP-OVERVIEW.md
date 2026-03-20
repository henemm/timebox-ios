# FocusBlox — App-Bestandsaufnahme

> Stand: 2026-03-20 | Zweck: Referenz-Dokument fuer geplantes Rework

---

## Sektion 1: Architektur

### Pattern & Prinzipien

- **Service-Oriented Architecture** — keine ViewModels, Services sind First-Class-Citizens
- **Cross-Platform Code-Sharing** — maximales Sharing via `Sources/`, nur Layout-Unterschiede in `FocusBloxMac/`
- **Keine externen Dependencies** — 100% Apple Frameworks
- **Daten:** SwiftData + CloudKit Sync (Private DB: `iCloud.com.henning.focusblox`)
- **Settings:** `AppSettings` (UserDefaults-Singleton) + `SyncedSettings` (iCloud KV Store)
- **Navigation:** iOS = TabView (4 Tabs: Backlog, Blox, Focus, Review) | macOS = Sidebar + Content
- **Deployment Target:** iOS 26.2 / macOS 26.2 / watchOS 26.2

### Projekt-Struktur

```
FocusBlox/
├── Sources/                          # Shared Code (111 Swift-Dateien)
│   ├── Models/         (19)          #   Datenstrukturen
│   ├── Services/       (24)          #   Business-Logik
│   ├── Views/          (45)          #   Plattformuebergreifende UI
│   ├── Intents/        (13)          #   App Intents / Siri Shortcuts
│   ├── Helpers/        (4)           #   Utilities
│   ├── Extensions/     (2)           #   Swift Extensions
│   ├── Protocols/      (2)           #   Protokoll-Definitionen
│   ├── Layouts/        (1)           #   Layout-Komponenten
│   └── Testing/        (1)           #   Test-Utilities
├── FocusBloxMac/                     # macOS-spezifische Views (18 Dateien)
├── FocusBloxWatch Watch App/         # watchOS App (6 Dateien)
├── FocusBloxWidgets/                 # iOS Widgets (4 Dateien)
├── FocusBloxWatchWidgets/            # watchOS Widgets (2 Dateien)
├── FocusBloxShareExtension/          # iOS Share Extension (1 Datei)
├── FocusBloxMacShareExtension/       # macOS Share Extension (1 Datei)
├── FocusBloxTests/                   # iOS Unit Tests (105 Dateien)
├── FocusBloxUITests/                 # iOS UI Tests (108 Dateien)
├── FocusBloxMacTests/                # macOS Unit Tests (6 Dateien)
├── FocusBloxMacUITests/              # macOS UI Tests (20 Dateien)
├── FocusBloxWatch Watch AppTests/    # Watch Unit Tests (2 Dateien)
├── FocusBloxWatch Watch AppUITests/  # Watch UI Tests (2 Dateien)
├── FocusBloxCoreTests/               # Core Framework Tests (1 Datei)
└── docs/                             # Dokumentation, Specs, Artifacts
```

### Metriken

| Kategorie | Anzahl |
|-----------|--------|
| Services | 24 |
| Models | 19 |
| Shared Views | 45 |
| macOS Views | 18 |
| App Intents | 13 |
| Test-Dateien gesamt | 244 |
| — iOS Unit Tests | 105 |
| — iOS UI Tests | 108 |
| — macOS Unit Tests | 6 |
| — macOS UI Tests | 20 |
| — Watch Tests | 4 |
| — Core Tests | 1 |

---

### Services (24)

| Service | Pfad | Beschreibung |
|---------|------|-------------|
| AITaskScoringService | `Sources/Services/AITaskScoringService.swift` | AI-Task-Scoring via Foundation Models; unsichtbar ohne Apple Intelligence |
| CategoryStatsService | `Sources/Services/CategoryStatsService.swift` | Aggregiert Kategorie-Statistiken aus erledigten Tasks fuer Trend-Analyse |
| CloudKitSyncMonitor | `Sources/Services/CloudKitSyncMonitor.swift` | Ueberwacht CloudKit-Sync-Events mit State-Tracking |
| DeferredCompletionController | `Sources/Services/DeferredCompletionController.swift` | Verzoegerte Task-Completion mit 3s visueller Pause vor Daten-Commit |
| DeferredSortController | `Sources/Services/DeferredSortController.swift` | Friert Priority-Scores waehrend Badge-Updates fuer fluessige Animation ein |
| DisciplineStatsService | `Sources/Services/DisciplineStatsService.swift` | Aggregiert Disziplin-Statistiken fuer Review-Views; Multi-Wochen-Historie |
| EventKitRepository | `Sources/Services/EventKitRepository.swift` | EventKit-Wrapper fuer Kalender/Erinnerungen mit Change-Notifications |
| FocusBlockActionService | `Sources/Services/FocusBlockActionService.swift` | Task-Aktionen (Complete, Skip, Follow-up) waehrend FocusBlock; iOS + macOS |
| LiveActivityManager | `Sources/Services/LiveActivityManager.swift` | Live Activity Lifecycle fuer Lock Screen und Dynamic Island |
| LocalTaskSource | `Sources/Services/TaskSources/LocalTaskSource.swift` | TaskSource-Implementierung fuer lokale Tasks via SwiftData + CloudKit |
| MenuBarIconState | `Sources/Services/MenuBarIconState.swift` | State-Logik fuer macOS Menu Bar Icon (idle/active/done) |
| NotificationActionDelegate | `Sources/Services/NotificationActionDelegate.swift` | Interaktive Notification-Actions (NextUp, Postpone, Complete) |
| NotificationService | `Sources/Services/NotificationService.swift` | Plant lokale Push-Notifications mit interaktiven Actions fuer Due Dates |
| RecurrenceService | `Sources/Services/RecurrenceService.swift` | Berechnet naechstes Due Date fuer wiederkehrende Tasks |
| RemindersImportService | `Sources/Services/RemindersImportService.swift` | Einweg-Import aus Apple Reminders; optional als erledigt markieren |
| SmartTaskEnrichmentService | `Sources/Services/SmartTaskEnrichmentService.swift` | AI-Anreicherung via Foundation Models (Importance, Urgency, Category, Energy) |
| SoundService | `Sources/Services/SoundService.swift` | Audio-Feedback (Block-End-Gong, Warnings); respektiert App-Settings |
| SpotlightIndexingService | `Sources/Services/SpotlightIndexingService.swift` | Indexiert aktive Tasks in Spotlight; exkludiert erledigte und Templates |
| SyncEngine | `Sources/Services/SyncEngine.swift` | Core Sync — holt incomplete, recurring und completed Tasks |
| TaskCompletionUndoService | `Sources/Services/TaskCompletionUndoService.swift` | Undo letzte Completion via Shake (iOS) oder Cmd+Z (macOS) |
| TaskPriorityScoringService | `Sources/Services/TaskPriorityScoringService.swift` | Deterministisches Priority-Scoring: doNow/planSoon/eventually/someday |
| TaskTitleEngine | `Sources/Services/TaskTitleEngine.swift` | AI-Verbesserung von Task-Titeln via Apple Intelligence |
| TimerCalculator | `Sources/Services/TimerCalculator.swift` | Shared Timer-Berechnungen fuer Task-Fortschritt (iOS + macOS) |
| WidgetRelevanceCalculator | `Sources/Services/WidgetRelevanceCalculator.swift` | Widget-Relevanz fuer Smart Stack (10.0 idle bis 100.0 aktiver Block) |

### Models (19)

| Model | Pfad | Beschreibung |
|-------|------|-------------|
| AppSettings | `Sources/Models/AppSettings.swift` | App-Settings in UserDefaults als @MainActor Singleton |
| CalendarEvent | `Sources/Models/CalendarEvent.swift` | Kalender-Event aus EventKit (Titel, Zeiten, Teilnehmer) |
| CalendarEventTransfer | `Sources/Models/CalendarEventTransfer.swift` | Transferable fuer Drag&Drop von Kalender-Events |
| Discipline | `Sources/Models/Discipline.swift` | Enum: konsequenz, ausdauer, mut, fokus mit Farben und Icons |
| FocusBlock | `Sources/Models/FocusBlock.swift` | Zeitslot fuer fokussierte Arbeit mit Task-Zuweisung und Tracking |
| FocusBlockActivityAttributes | `Sources/Models/FocusBlockActivityAttributes.swift` | ActivityKit-Attributes fuer Live Activities |
| GapFinder | `Sources/Models/GapFinder.swift` | Findet freie Zeitslots zwischen Kalender-Events und Focus Blocks |
| LocalTask | `Sources/Models/LocalTask.swift` | SwiftData @Model fuer lokale Tasks mit CloudKit-Sync |
| PlanItem | `Sources/Models/PlanItem.swift` | Unified Plan-Item (Task + Event kombiniert) mit Ranking |
| PlanItemTransfer | `Sources/Models/PlanItemTransfer.swift` | Transferable fuer Drag&Drop von Plan-Items |
| RecurrencePattern | `Sources/Models/RecurrencePattern.swift` | Enum: none, daily, weekly, monthly, quarterly, yearly, custom |
| ReminderData | `Sources/Models/ReminderData.swift` | DTO fuer Apple Reminders aus EventKit |
| ReminderListInfo | `Sources/Models/ReminderListInfo.swift` | Display-Info fuer Reminder-Listen (id, title, colorHex) |
| ReviewStatsCalculator | `Sources/Models/ReviewStatsCalculator.swift` | Berechnet Kategorie-Statistiken fuer Review-Views |
| SyncedSettings | `Sources/Models/SyncedSettings.swift` | Synchronisiert Settings via iCloud KV Store zwischen Geraeten |
| TaskCategory | `Sources/Models/TaskCategory.swift` | Enum: income, essentials, selfCare, learn, social |
| TaskMetadata | `Sources/Models/TaskMetadata.swift` | SwiftData @Model fuer Task-Metadaten (sortOrder, manualDuration) |
| TimelineItem | `Sources/Models/TimelineItem.swift` | Unified Timeline-Item fuer Kollisionserkennung |
| WarningTiming | `Sources/Models/WarningTiming.swift` | Enum: short (90%), standard (80%), early (70%) |

### Shared Views (45)

**Hauptscreens:**

| View | Pfad | Beschreibung |
|------|------|-------------|
| MainTabView | `Sources/Views/MainTabView.swift` | Root-Navigation: 4 Tabs (Backlog, Blox, Focus, Review) |
| ContentView | `Sources/Views/ContentView.swift` | iOS App Root View |
| BacklogView | `Sources/Views/BacklogView.swift` | Task-Liste mit 5 View-Modi (Priority, Recent, Overdue, Recurring, Completed) |
| BlockPlanningView | `Sources/Views/BlockPlanningView.swift` | Block-Planung und Task-Zuweisung |
| PlanningView | `Sources/Views/PlanningView.swift` | Timeline mit Kalender-Events, Luecken und unzugeordneten Tasks |
| FocusLiveView | `Sources/Views/FocusLiveView.swift` | Aktiver Focus-Block Timer mit Task-Progression |
| DailyReviewView | `Sources/Views/DailyReviewView.swift` | Sprint-Review: erledigte Tasks nach Focus Blocks; Today/Week |
| SettingsView | `Sources/Views/SettingsView.swift` | App-Settings (Sound, Warnings, Kalender, AI, Notifications) |
| TimelineView | `Sources/Views/TimelineView.swift` | Kalender-Timeline (shared iOS/macOS) |

**Sheets & Detail-Views:**

| View | Pfad | Beschreibung |
|------|------|-------------|
| TaskDetailSheet | `Sources/Views/TaskDetailSheet.swift` | Modal fuer Task-Details |
| TaskFormSheet | `Sources/Views/TaskFormSheet.swift` | Formular-Sheet fuer Task-Bearbeitung |
| CreateTaskView | `Sources/Views/TaskCreation/CreateTaskView.swift` | Vollstaendiges Task-Erstellungsformular |
| TaskAssignmentView | `Sources/Views/TaskAssignmentView.swift` | Task-Zuweisung zu Focus Blocks |
| FocusBlockTasksSheet | `Sources/Views/FocusBlockTasksSheet.swift` | Tasks eines Focus Blocks anzeigen |
| EditFocusBlockSheet | `Sources/Views/EditFocusBlockSheet.swift` | Focus Block bearbeiten (Zeit, Titel) |
| SprintReviewSheet | `Sources/Views/SprintReviewSheet.swift` | Sprint-Review nach Block-Ende |
| BlockerPickerSheet | `Sources/Views/BlockerPickerSheet.swift` | Blocker-Task auswaehlen |
| QuickCaptureView | `Sources/Views/QuickCaptureView.swift` | Schnelle Task-Eingabe |

**Rows & Cards:**

| View | Pfad | Beschreibung |
|------|------|-------------|
| BacklogRow | `Sources/Views/BacklogRow.swift` | Task-Zeile in Backlog-Liste |
| MiniTaskCard | `Sources/Views/MiniTaskCard.swift` | Kompakte Task-Karte |
| MiniBacklogView | `Sources/Views/MiniBacklogView.swift` | Kompakte Backlog-Ansicht fuer eingebettete Kontexte |
| TaskPreviewView | `Sources/Views/TaskPreviewView.swift` | Task-Vorschau Kompakt-Ansicht |
| EventBlock | `Sources/Views/EventBlock.swift` | Kalender-Event in Timeline |
| HourRow | `Sources/Views/HourRow.swift` | Stundenzeile in Timeline |
| NextUpSection | `Sources/Views/NextUpSection.swift` | Next-Up Tasks Sektion |

**Picker & Badges:**

| View | Pfad | Beschreibung |
|------|------|-------------|
| CategoryPicker | `Sources/Views/CategoryPicker.swift` | Kategorie-Auswahl |
| ImportancePicker | `Sources/Views/ImportancePicker.swift` | Eisenhower-Importance (1-3) |
| DurationPicker | `Sources/Views/DurationPicker.swift` | Dauer in Minuten |
| DurationBadge | `Sources/Views/DurationBadge.swift` | Dauer-Badge |
| CategoryIconBadge | `Sources/Views/CategoryIconBadge.swift` | Kategorie-Icon-Badge |
| TagInputView | `Sources/Views/TagInputView.swift` | Multi-Tag Eingabe |

**Charts & Review:**

| View | Pfad | Beschreibung |
|------|------|-------------|
| CategoryTrendChart | `Sources/Views/CategoryTrendChart.swift` | Kategorie-Verteilung/Trends |
| DisciplineTrendChart | `Sources/Views/DisciplineTrendChart.swift` | Disziplin-Verteilung/Trends |
| ReviewComponents | `Sources/Views/ReviewComponents.swift` | Wiederverwendbare Review-Komponenten |

**Components (`Sources/Views/Components/`):**

| View | Pfad | Beschreibung |
|------|------|-------------|
| SettingsComponents | `Sources/Views/Components/SettingsComponents.swift` | CalendarRow, ReminderListRow |
| SharedSheets | `Sources/Views/Components/SharedSheets.swift` | Wiederverwendbare Sheet-Definitionen |
| TaskBadges | `Sources/Views/Components/TaskBadges.swift` | Badges fuer Importance, Urgency, Duration, Category |
| DayProgressSection | `Sources/Views/Components/DayProgressSection.swift` | Tagesfortschritt-Sektion |
| QuickDurationButton | `Sources/Views/Components/QuickDurationButton.swift` | Schnellwahl fuer Dauer (5, 15, 30 min) |
| WeekdayButton | `Sources/Views/Components/WeekdayButton.swift` | Wochentag-Button fuer Recurrence |

**System & Design:**

| View | Pfad | Beschreibung |
|------|------|-------------|
| DesignSystem | `Sources/Views/DesignSystem.swift` | Zentrales Design-System (Farben, Materialien) |
| FocusBloxIconLayers | `Sources/Views/FocusBloxIconLayers.swift` | App-Icon Layer-Generator (Liquid Glass) |
| SettingsToolbarModifier | `Sources/Views/SettingsToolbarModifier.swift` | Toolbar-Modifier fuer Settings-Button |
| ShakeGestureModifier | `Sources/Views/ShakeGestureModifier.swift` | Shake-Gesture Handler (iOS Undo) |

### macOS Views (18)

| View | Pfad | Beschreibung |
|------|------|-------------|
| FocusBloxMacApp | `FocusBloxMac/FocusBloxMacApp.swift` | macOS App Entry Point mit MenuBarController |
| ContentView | `FocusBloxMac/ContentView.swift` | Root View mit Sidebar + Main Content |
| SidebarView | `FocusBloxMac/SidebarView.swift` | Navigation-Sidebar (4 Sektionen) |
| MacFocusView | `FocusBloxMac/MacFocusView.swift` | Focus-Tab mit Timer und Task-Management |
| MacPlanningView | `FocusBloxMac/MacPlanningView.swift` | Planning mit Timeline + Next-Up nebeneinander |
| MacReviewView | `FocusBloxMac/MacReviewView.swift` | Review-Dashboard (Daily + Weekly) |
| MacTimelineView | `FocusBloxMac/MacTimelineView.swift` | Horizontale Timeline (macOS-Layout) |
| MacSettingsView | `FocusBloxMac/MacSettingsView.swift` | Settings fuer macOS |
| MacBacklogRow | `FocusBloxMac/MacBacklogRow.swift` | Task-Zeile mit macOS Context Menu |
| MenuBarView | `FocusBloxMac/MenuBarView.swift` | Menu Bar Popover (Focus-State + Quick Actions) |
| MacTaskCreateSheet | `FocusBloxMac/MacTaskCreateSheet.swift` | Task-Erstellung (macOS-Praesentation) |
| QuickCapturePanel | `FocusBloxMac/QuickCapturePanel.swift` | Floating Quick Capture (Spotlight-Style) |
| TaskInspector | `FocusBloxMac/TaskInspector.swift` | Inspector-Panel rechte Sidebar |
| KeyboardShortcutsView | `FocusBloxMac/KeyboardShortcutsView.swift` | Keyboard-Shortcuts Uebersicht |
| MacTaskTransfer | `FocusBloxMac/MacTaskTransfer.swift` | Drag&Drop Utilities |
| WindowAccessor | `FocusBloxMac/WindowAccessor.swift` | NSWindow-Zugriff aus SwiftUI |
| ClickThroughView | `FocusBloxMac/ClickThroughView.swift` | Transparentes Overlay (Click-Through) |
| MinimalTestApp | `FocusBloxMac/MinimalTestApp.swift` | Test-Helper fuer CI |

### Extensions & Widgets

**iOS Widgets (4 Dateien):**
- `FocusBloxWidgets/FocusBloxWidgetsBundle.swift` — Widget Bundle
- `FocusBloxWidgets/FocusBlockLiveActivity.swift` — Live Activity (Lock Screen + Dynamic Island)
- `FocusBloxWidgets/QuickAddTaskControl.swift` — Quick Add Control
- `FocusBloxWidgets/QuickCaptureWidget.swift` — Quick Capture Widget

**watchOS (6+2 Dateien):**
- `FocusBloxWatch Watch App/FocusBloxWatchApp.swift` — App Entry Point
- `FocusBloxWatch Watch App/ContentView.swift` — Main UI
- `FocusBloxWatch Watch App/VoiceInputSheet.swift` — Spracheingabe
- `FocusBloxWatch Watch App/WatchLocalTask.swift` — Lokales Task-Modell
- `FocusBloxWatch Watch App/WatchNotificationDelegate.swift` — Notification Handling
- `FocusBloxWatch Watch App/WatchTaskMetadata.swift` — Task-Metadaten
- `FocusBloxWatchWidgets/FocusBloxWatchWidgetsBundle.swift` — Widget Bundle
- `FocusBloxWatchWidgets/QuickCaptureComplication.swift` — Watch Complication

**Share Extensions:**
- `FocusBloxShareExtension/ShareViewController.swift` — iOS Share Extension
- `FocusBloxMacShareExtension/ShareViewController.swift` — macOS Share Extension

**App Intents (13 Dateien in `Sources/Intents/`):**
- `FocusBloxShortcuts.swift` — Shortcuts-Integration
- `CreateTaskIntent.swift` — Task erstellen
- `CompleteTaskIntent.swift` — Task erledigen
- `CountOpenTasksIntent.swift` — Offene Tasks zaehlen
- `GetNextUpIntent.swift` — Next Up abrufen
- `CreateTaskSnippetIntent.swift` — Snippet erstellen
- `CCQuickAddIntents.swift` — Control Center Quick Add
- `QuickCaptureSnippetView.swift` — UI-Snippet
- `QuickCaptureState.swift` — State Management
- `QuickCaptureSubIntents.swift` — Sub-Intents
- `FocusBlockEntity.swift` — Focus Block Entity
- `TaskEntity.swift` — Task Entity
- `TaskEnums.swift` — Task Enums

---

## Sektion 2: Features

### Kern-Features

| Feature | Beschreibung | Schluessel-Dateien |
|---------|-------------|-------------------|
| **Backlog** | Task-Liste mit 5 View-Modi (Priority, Recent, Overdue, Recurring, Completed), Search, Tags, Kategorien | `BacklogView`, `BacklogRow`, `TaskPriorityScoringService` |
| **Block Planning** | Kalender-Timeline, freie Slots erkennen, Tasks per Drag&Drop in Zeitbloecke zuweisen | `BlockPlanningView`, `PlanningView`, `TimelineView`, `GapFinder` |
| **Focus Live** | Aktiver Timer mit Task-Tracking, Gong am Ende, Warning vor Ende, Sprint Review | `FocusLiveView`, `FocusBlockActionService`, `SoundService`, `TimerCalculator` |
| **Daily Review** | Erledigte Tasks nach Focus Blocks gruppiert, Today/Week Ansicht | `DailyReviewView`, `SprintReviewSheet`, `ReviewComponents` |
| **Quick Capture** | Schnelle Task-Eingabe auf iOS, Watch-Diktat, Mac-Hotkey | `QuickCaptureView`, `QuickCapturePanel`, `VoiceInputSheet` |

### Task-Management

| Feature | Beschreibung | Schluessel-Dateien |
|---------|-------------|-------------------|
| **Recurring Tasks** | Template-System mit automatischen Instanzen (daily, weekly, monthly, etc.) | `RecurrenceService`, `RecurrencePattern`, `LocalTask` |
| **Task Dependencies** | Blocker-System mit Zyklus-Erkennung | `BlockerPickerSheet`, `LocalTask.blockerIDs` |
| **Priority Scoring** | Deterministisches Scoring: doNow (60-100), planSoon (35-59), eventually (10-34), someday (0-9) | `TaskPriorityScoringService` |
| **Task Undo** | Letzte Completion rueckgaengig via Shake (iOS) oder Cmd+Z (macOS) | `TaskCompletionUndoService`, `ShakeGestureModifier` |
| **Deferred Completion** | 3-Sekunden visuelle Verzoegerung vor Daten-Commit | `DeferredCompletionController` |

### AI & Intelligence

| Feature | Beschreibung | Schluessel-Dateien |
|---------|-------------|-------------------|
| **AI Enrichment** | Apple Intelligence fuer auto Importance/Urgency/Category/Energy | `SmartTaskEnrichmentService` |
| **AI Scoring** | Foundation Models fuer Task-Bewertung (nur mit Apple Intelligence) | `AITaskScoringService` |
| **AI Title Improvement** | Automatische Verbesserung von Task-Titeln im Hintergrund | `TaskTitleEngine` |

### System-Integration

| Feature | Beschreibung | Schluessel-Dateien |
|---------|-------------|-------------------|
| **Reminders Import** | Einweg-Import aus Apple Reminders | `RemindersImportService`, `EventKitRepository` |
| **Kalender-Integration** | Focus Blocks als Kalender-Events, Kollisionserkennung | `EventKitRepository`, `TimelineItem` |
| **CloudKit Sync** | Multi-Device Sync (iPhone, Mac, Watch) via Private DB | `CloudKitSyncMonitor`, `LocalTaskSource`, `SyncedSettings` |
| **Live Activities** | Dynamic Island + Lock Screen waehrend Focus Block | `LiveActivityManager`, `FocusBlockActivityAttributes`, `FocusBlockLiveActivity` |
| **Notifications** | Due-Date Reminders mit interaktiven Actions (NextUp, Postpone, Complete) | `NotificationService`, `NotificationActionDelegate` |
| **Siri Shortcuts** | 5+ App Intents fuer Automatisierung (Create, Complete, Count, GetNextUp) | `Sources/Intents/` (13 Dateien) |
| **Spotlight** | Tasks durchsuchbar via Spotlight | `SpotlightIndexingService` |
| **Widgets** | Quick Capture Widget, Live Activity, Watch Complication | `FocusBloxWidgets/`, `FocusBloxWatchWidgets/` |
| **Share Extension** | Tasks aus anderen Apps erstellen (iOS + macOS) | `FocusBloxShareExtension/`, `FocusBloxMacShareExtension/` |
| **Menu Bar (macOS)** | Status-Item mit Focus-State und Quick Actions | `MenuBarView`, `MenuBarIconState` |

### Analytics & Tracking

| Feature | Beschreibung | Schluessel-Dateien |
|---------|-------------|-------------------|
| **Kategorie-Tracking** | Zeitverteilung nach 5 Kategorien (Earn, Essentials, Self Care, Learn, Social) | `CategoryStatsService`, `CategoryTrendChart`, `TaskCategory` |
| **Disziplin-Tracking** | 4 Trainings-Dimensionen (Konsequenz, Ausdauer, Mut, Fokus) | `DisciplineStatsService`, `DisciplineTrendChart`, `Discipline` |
| **Widget Relevance** | Smart Stack Relevanz basierend auf aktuellem Block-Status | `WidgetRelevanceCalculator` |

---

## Sektion 3: User-Perspektive

### Kernproblem

User haben Tasks verstreut und keine Sichtbarkeit auf freie Zeit zwischen Meetings. Ohne bewusste Intention und Grenzen werden freie Bloecke von reaktiver Arbeit, niedrigen Prioritaeten oder Ablenkung aufgefressen. Der Tag "passiert einfach" statt bewusst gestaltet zu werden.

### Loesung

FocusBlox fuellt die Luecke zwischen Apple Reminders (Task-Management) und Apple Calendar (Terminplanung):
1. Tasks bewusst priorisieren
2. In freie Kalender-Slots per Drag&Drop zuweisen
3. Harte Timer (Focus Blocks) mit Gong am Ende
4. Review — was geschafft, wohin ging die Zeit?

### User Journey

**Morgens:**
1. Backlog durchgehen, Tasks priorisieren
2. "Next Up" markieren — bewusste Entscheidung was heute zaehlt
3. Kalender anschauen, freie Slots finden
4. Tasks per Drag&Drop in Zeitbloecke zuweisen

> Gefuehl: "Ich waehle bewusst, was heute wichtig ist"

**Waehrend des Tages:**
1. Focus Block starten — Timer laeuft auf Lock Screen und Dynamic Island
2. Aktuelle Task sichtbar, Fokus auf eine Sache
3. Warning-Gong kurz vor Ende, End-Gong wenn Block vorbei
4. Task erledigen oder zurueck in Backlog
5. Naechsten Block starten

> Gefuehl: "Ich bin fokussiert, nicht abgelenkt"

**Abends:**
1. Review-Tab oeffnen — was geschafft?
2. Tasks nach Focus Blocks gruppiert sehen
3. Kategorie-Verteilung anschauen (wohin ging die Zeit?)
4. Disziplin-Trends checken (welche Staerken wachsen?)
5. Wochen-Rueckblick am Freitag/Sonntag

> Gefuehl: "Ich sehe, was ich geschafft habe. Ich gestalte meinen Tag, statt zu reagieren."

### 5 Kategorien (Zeitverteilung)

Jeder Task gehoert zu einer Kategorie — zeigt wohin die Zeit fliesst:

| Kategorie | Code | Icon | Farbe | Bedeutung |
|-----------|------|------|-------|-----------|
| **Earn** (Geld) | `income` | `dollarsign.circle` | Gruen | Wertschoepfende Arbeit, Einkommen |
| **Essentials** (Pflege) | `maintenance` | `wrench.and.screwdriver.fill` | Orange | Notwendige Pflege (Admin, Haushalt, Pflichten) |
| **Self Care** (Energie) | `recharge` | `heart.circle` | Cyan | Selbstfuersorge, Erholung, Aufladen |
| **Learn** (Lernen) | `learning` | `book` | Lila | Weiterentwicklung, Bildung, Wachstum |
| **Social** (Geben) | `giving_back` | `person.2` | Pink | Mentoring, Helfen, Weitergeben |

**Zweck:** Am Tages-/Wochenende sieht der User die Balance: "40% Earn, 25% Essentials, 15% Self Care, 10% Learn, 10% Social" — bewusste Zeitverteilung ueber Lebensbereiche.

### 4 Disziplinen (Persoenliches Wachstum)

Jeder Task trainiert eine Disziplin — zeigt welcher Widerstand ueberwunden wurde:

| Disziplin | Farbe | Icon | Was wird trainiert | Klassifizierung |
|-----------|-------|------|--------------------|-----------------|
| **Konsequenz** | Gruen | `arrow.trianglehead.counterclockwise` | Disziplin & Durchhaltevermoegen | Tasks die ≥2x verschoben wurden |
| **Ausdauer** | Grau | `figure.walk` | Geduld & Bestaendigkeit | Default — langweilige aber notwendige Arbeit |
| **Mut** | Rot | `flame` | Emotionale Staerke | Tasks mit hoher Importance (3) |
| **Fokus** | Blau | `scope` | Zeitmanagement & Klarheit | Erledigte Tasks innerhalb der geschaetzten Dauer |

**Klassifizierungs-Logik (Prioritaet):**
1. `rescheduleCount >= 2` → Konsequenz
2. `importance == 3` → Mut
3. Erledigt innerhalb Schaetzung → Fokus
4. Default → Ausdauer

**Unterschied zu Kategorien:** Kategorien zeigen WO die Zeit hingeht (Lebensbereiche). Disziplinen zeigen WELCHE Staerke aufgebaut wird (persoenliches Wachstum).

### Emotionale Design-Momente

| Moment | Gefuehl | UI-Element |
|--------|---------|-----------|
| Task in Block ziehen | Agency, Kontrolle | Drag&Drop mit haptischem Feedback |
| Timer laeuft | Fokus, Praesenz | Live Activity auf Lock Screen |
| Gong + Done | Erfuellung | Audio-Feedback, sofort naechste Task |
| Review am Abend | Zufriedenheit | Kategorie-/Disziplin-Charts |
| Trend-Wachstum | Stolz | Stacked Bar Charts mit Trend-Pfeilen |
