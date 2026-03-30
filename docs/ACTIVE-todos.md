# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!
> **Archiv:** Erledigte Items → `docs/ARCHIVE-todos.md`
> **IDs:** `BUG_XXX` = Bugs, `FEATURE_XXX` = Features, `TD_XXX` = Tech Debt

---

## Rework: FocusBlox Neuausrichtung

> 18 Stories in 5 Epics. Reihenfolge: Epic 0 → 1 → 3 → 2 → 4.
> Specs: `docs/specs/rework/` | [Epic Overview](specs/rework/0.0-epic-overview.md)

| ID | Epic | Titel | Prio | Aufwand | macOS | Spec |
|----|------|-------|------|---------|-------|------|
| ~~RW_0.1a~~ | ~~0 Infrastruktur~~ | ~~Smart Notification Engine — Phase A (Foundation)~~ | ~~High~~ | ~~M~~ | ~~Shared~~ | ~~[Spec](specs/rework/0.1-smart-notification-engine-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_0.1b~~ | ~~0 Infrastruktur~~ | ~~Smart Notification Engine — Phase B (FocusBlock Migration)~~ | ~~High~~ | ~~M~~ | ~~Shared~~ | ~~[Spec](specs/rework/0.1b-smart-notification-phase-b-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_0.1c~~ | ~~0 Infrastruktur~~ | ~~Smart Notification Engine — Phase C (DueDate Migration)~~ | ~~High~~ | ~~M~~ | ~~Shared~~ | ~~[Spec](specs/rework/0.1c-smart-notification-phase-c-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_0.1d~~ | ~~0 Infrastruktur~~ | ~~Smart Notification Engine — Phase D (Review/Nudge + Settings UI)~~ | ~~High~~ | ~~M~~ | ~~UI fehlt~~ | ~~[Spec](specs/rework/0.1d-smart-notification-phase-d-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_0.2~~ | ~~0 Infrastruktur~~ | ~~BehavioralProfileService (Affinitaet, Kapazitaet, Schaetzgenauigkeit)~~ | ~~High~~ | ~~M~~ | ~~Shared~~ | ~~[Spec](specs/rework/0.2-behavioral-profile-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_0.2b~~ | ~~0 Infrastruktur~~ | ~~BehavioralProfileService Phase B (Kalender-Korrelation, Verschiebungs-Muster)~~ | ~~High~~ | ~~S~~ | ~~Shared~~ | ~~[Spec](specs/rework/0.2b-behavioral-profile-phase-b-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_1.1~~ | ~~1 Erfassung~~ | ~~Quick Dump~~ | ~~High~~ | ~~M~~ | ~~Shared~~ | ~~[Spec](specs/rework/1.1-quick-dump.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_1.2~~ | ~~1 Erfassung~~ | ~~AI Context Extraction (Schema)~~ | ~~High~~ | ~~L~~ | ~~Shared~~ | ~~[Spec](specs/rework/1.2-1.3-refiner-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_1.3~~ | ~~1 Erfassung~~ | ~~The Refiner (UI)~~ | ~~High~~ | ~~L~~ | ~~UI fehlt~~ | ~~[Spec](specs/rework/1.2-1.3-refiner-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_3.1a~~ | ~~3 Ausfuehrung~~ | ~~Calendar Task Drop — Phase A: Model Layer~~ | ~~Medium~~ | ~~S~~ | ~~Shared~~ | ~~[Spec](specs/rework/3.1a-calendar-task-drop-model-layer.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_3.1b~~ | ~~3 Ausfuehrung~~ | ~~Calendar Task Drop — Phase B: iOS Schedule/Unschedule Logic~~ | ~~Medium~~ | ~~S~~ | ~~Shared~~ | ~~[Spec](specs/rework/3.1b-calendar-task-drop-schedule-logic.md)~~ ERLEDIGT |
| ~~RW_3.1c~~ | ~~3 Ausfuehrung~~ | ~~Calendar Task Drop — Phase C: ScheduledTaskBlock + Context Menu~~ | ~~Medium~~ | ~~S~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/3.1c-scheduled-task-block.md)~~ ERLEDIGT |
| ~~RW_3.1d~~ | ~~3 Ausfuehrung~~ | ~~Calendar Task Drop — Phase D: GapFinder + Notifications + macOS~~ | ~~Medium~~ | ~~S~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/3.1d-gapfinder-notifications-macos.md)~~ ERLEDIGT |
| ~~RW_3.2~~ | ~~3 Ausfuehrung~~ | ~~Focus Sprint ("Los"-Button)~~ | ~~Medium~~ | ~~M~~ | ~~UI fehlt~~ | ~~[Spec](specs/rework/3.2-focus-sprint-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_3.3~~ | ~~3 Ausfuehrung~~ | ~~Follow-up Logic~~ | ~~Medium~~ | ~~S~~ | ~~Shared~~ | ~~[Spec](specs/rework/3.3-follow-up-logic-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_3.4~~ | ~~3 Ausfuehrung~~ | ~~Emotional Nudge (Micro-Tasks)~~ | ~~Medium~~ | ~~M~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/3.4-emotional-nudge-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_2.1a~~ | ~~2 Tagesplanung~~ | ~~DayView — Phase A: Grundstruktur + Modi-Wechsel + Tab/Sidebar + Settings~~ | ~~Medium~~ | ~~M~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/2.1a-day-view-skeleton.md)~~ ERLEDIGT |
| ~~RW_2.1b~~ | ~~2 Tagesplanung~~ | ~~DayView — Phase B: Morgen-Modus (Kalender-Luecken + Task-Liste)~~ | ~~Medium~~ | ~~M~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/2.1b-day-view-morning-mode.md)~~ ERLEDIGT |
| ~~RW_2.1c~~ | ~~2 Tagesplanung~~ | ~~DayView — Phase C: Tages-Timeline (TimelineView Integration)~~ | ~~Medium~~ | ~~M~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/2.1c-day-view-daytime-timeline.md)~~ ERLEDIGT |
| ~~RW_2.1d~~ | ~~2 Tagesplanung~~ | ~~DayView — Phase D: Abend-Modus (Zusammenfassung + Stubs fuer 4.2/4.3)~~ | ~~Medium~~ | ~~M~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/2.1-day-view.md)~~ ERLEDIGT |
| ~~RW_2.2~~ | ~~2 Tagesplanung~~ | ~~KI-gestuetzte Tagesvorschlaege~~ | ~~Medium~~ | ~~L~~ | ~~Shared~~ | ~~[Spec](specs/rework/2.2-next-up-suggestions-impl.md)~~ ERLEDIGT |
| ~~RW_2.3~~ | ~~2 Tagesplanung~~ | ~~Limitation Guard~~ | ~~Medium~~ | ~~S~~ | ~~Shared~~ | ~~[Spec](specs/rework/2.3-limitation-guard-impl.md)~~ ERLEDIGT |
| ~~RW_2.4~~ | ~~2 Tagesplanung~~ | ~~Backlog UX Rework (Parkdeck-Metapher)~~ | ~~Medium~~ | ~~L~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/2.4-backlog-ux-rework-impl.md)~~ ERLEDIGT |
| ~~RW_3.5~~ | ~~3 Ausfuehrung~~ | ~~Recurring Stacking — Visuelle Gruppierung + Priority Boost~~ | ~~Medium~~ | ~~M~~ | ~~Eigene View~~ | ~~[Spec](specs/rework/3.5-recurring-stacking-impl.md)~~ ERLEDIGT |
| ~~RW_4.1~~ | ~~4 Reflexion~~ | ~~Soft Evening Reset~~ | ~~Low~~ | ~~M~~ | ~~Shared~~ | ~~[Spec](specs/rework/4.1-soft-evening-reset.md)~~ ERLEDIGT |
| ~~RW_4.2~~ | ~~4 Reflexion~~ | ~~Success Story Generator~~ | ~~Low~~ | ~~L~~ | ~~Shared~~ | ~~[Spec](specs/rework/4.2-success-story-generator-impl.md)~~ ERLEDIGT |
| ~~RW_4.3~~ | ~~4 Reflexion~~ | ~~Failure Protocol~~ | ~~Low~~ | ~~M~~ | ~~Shared~~ | ~~[Spec](specs/rework/4.3-failure-protocol-impl.md)~~ ERLEDIGT |
| ~~RW_4.4~~ | ~~4 Reflexion~~ | ~~Morning Widget~~ | ~~Low~~ | ~~M~~ | ~~iOS-only~~ | ~~[Spec](specs/rework/4.4-morning-widget-impl.md)~~ ERLEDIGT |
| ~~RW_1.4~~ | ~~1 Erfassung~~ | ~~AI Enrichment Rework (Kategorie + Zeitschaetzung statt Titel-AI)~~ | ~~High~~ | ~~S~~ | ~~Shared~~ | ~~[Spec](specs/rework/1.4-ai-enrichment-rework-impl.md)~~ ERLEDIGT |
| ~~RW_1.5~~ | ~~1 Erfassung~~ | ~~Refiner-Tab entfernt, Auto-Confirm Pipeline~~ | ~~High~~ | ~~S~~ | ~~Shared~~ | ~~[Spec](specs/rework/1.5-remove-refiner-auto-confirm.md)~~ ERLEDIGT |

### macOS-Spalte Legende

| Wert | Bedeutung |
|------|-----------|
| **Shared** | Logik + UI in `Sources/`, funktioniert auf beiden Plattformen ohne Anpassung |
| **Eigene View** | Logik shared in `Sources/`, macOS braucht eigene View in `FocusBloxMac/` |
| **UI fehlt** | iOS fertig, macOS-UI noch nicht implementiert (siehe Paritaets-Todos) |
| **iOS-only** | Feature existiert nur auf iOS (z.B. Lock Screen Widget) |

---

## macOS Paritaet — Offene Items

> Logik ist jeweils shared in `Sources/` — nur macOS-UI fehlt.

| ID | Titel | Prio | Aufwand | Beschreibung |
|----|-------|------|---------|-------------|
| ~~MAC_025b~~ | ~~Reminders Sync auf macOS~~ | ~~High~~ | ~~S~~ | ~~`migrateRemindersToLocal()` Aufruf in `FocusBloxMacApp.swift` fehlt (~3 LoC). [Spec](specs/macos/MAC-025-reminders-sync.md)~~ ERLEDIGT |
| ~~MAC_027~~ | ~~Focus Sprint Workflow Paritaet~~ | ~~Medium~~ | ~~S~~ | ~~Sidebar-Switch + Follow-up + Nudge Dialog~~ ERLEDIGT |
| ~~MAC_028~~ | ~~Backlog Paritaet (Parkdeck + Stacking)~~ | ~~Medium~~ | ~~S~~ | ~~Parkdeck-Metapher + Recurring Stacking. [Spec](specs/macos/MAC_028-backlog-parity.md)~~ ERLEDIGT |
| ~~MAC_026~~ | ~~Enhanced Quick Capture (Metadaten)~~ | ~~Medium~~ | ~~M~~ | ~~macOS Quick Capture hat nur Titel, iOS hat volle Metadaten. Teilbereich A (Metadaten-Buttons) implementiert. [Spec](specs/macos/MAC_026-quick-capture-metadata-impl.md)~~ ERLEDIGT |
| ~~MAC_029~~ | ~~Menüzeilen-Icon optimieren~~ | ~~Low~~ | ~~S~~ | ~~Konzentrische Kreise programmatisch als Template-Image. Rings mit Gaps, Alpha-Gradient, Template-Mode, 5 Unit Tests. [Spec](specs/macos/MAC_029-menubar-icon.md)~~ ERLEDIGT |
| ~~MAC_RW_2.1_TL~~ | ~~DayView Daytime Timeline auf macOS~~ | ~~Medium~~ | ~~M~~ | ~~MacTimelineView read-only im DayView Daytime-Modus integriert. MockEventKitRepository in FocusBloxMacApp fuer UI Tests. 3 UI Tests gruen. [Spec](specs/macos/MAC_RW_2.1_TL-dayview-timeline.md)~~ ERLEDIGT |

### Erledigte macOS-Items

> Bereits implementiert, verifiziert am 2026-03-28.

| ID | Titel |
|----|-------|
| ~~MAC_024~~ | Sync + UI Alignment (Sandbox-Fix) |
| ~~MAC_025a~~ | Next Up Button in MacBacklogRow |
| ~~MAC_MENU~~ | MenuBar FocusBlock Status + Timer |
| ~~MAC_020~~ | Drag & Drop Planung |
| ~~MAC_021~~ | Review Dashboard |
| ~~MAC_RW_0.1d~~ | Notification Profile Picker |
| ~~MAC_RW_1.3~~ | Refiner Navigation |
| ~~MAC_RW_3.2a~~ | Focus Sprint Context Menu |
| ~~MAC_027~~ | Focus Sprint Workflow Paritaet (Sidebar-Switch + Follow-up + Nudge) |

---

## Offene Items (Legacy)

| ID | Titel | Prio | Aufwand | Plattform | Beschreibung |
|----|-------|------|---------|-----------|-------------|
| FEATURE_010 | macOS Backlog: Keyboard Shortcuts | Low | S | macOS | Cmd+N (neuer Task), Cmd+Delete (loeschen), etc. |
| FEATURE_011 | macOS Backlog: Undo (Cmd+Z) | Low | S | macOS | iOS hat Shake-to-Undo. macOS Backlog hat kein Cmd+Z-Undo. |
| ~~FEATURE_018~~ | ~~macOS Enhanced Quick Capture~~ | — | — | ~~macOS~~ | Ersetzt durch MAC_026 (siehe macOS Infrastruktur) |
| FEATURE_019 | macOS Shortcuts.app Integration | Low | L | macOS | macOS Automatisierung. P3. |
| FEATURE_020 | macOS Focus Mode Integration | Low | M | macOS | macOS System-Integration. P3. |
| FEATURE_021 | OrganizeMyDay Intent | Low | XL | iOS | Komplexer Intent. Kann warten. |
| FEATURE_022 | CaptureContextIntent | Low | M | iOS | WARTEND auf Apple APIs (iOS 26.5/27). |
| FEATURE_028 | Focus Sprint: Inline-Duration-Picker | Low | S | iOS | Vor Sprint-Start Dauer anpassen (Inline-Picker, kein Sheet). Follow-up aus RW_3.2 — bewusst ausgescoped um LoC-Limit einzuhalten. Default-Dauer (estimatedDuration oder 60 Min) reicht vorerst. |
| FEATURE_030 | Task Lifecycle Debug Mode | Low | M | Beide | In Settings aktivierbarer Debug-Modus, der sichtbar macht wie ein Task entstanden (manuell, Reminders Import, Recurring Repair, CloudKit Sync), manipuliert (Template-Migration, Dedup-Reassignment, Priority-Recalc) oder geloescht wurde. Ziel: Transparenz bei Daten-Bugs wie Recurring-Duplikaten. Idee aus bug-recurring-stacking Analyse. |
| TD_001 | God-Views aufbrechen | Low | L | Beide | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| TD_002 | View-Duplikation iOS/macOS konsolidieren | Medium | L | Beide | Verbleibende Duplikation zwischen Sources/Views und FocusBloxMac. **Wird mit jedem Rework-Feature teurer.** Perspektivisch konsolidieren. **Teilfix:** MacTaskCreateSheet durch shared TaskFormSheet ersetzt (bug-mac-create-dialog). Verbleibend: Settings, Review, BacklogRow. |
| TD_007 | macOS UI Tests in Workflow integrieren | Medium | M | macOS | sim.sh hat mac-build + mac-unit, aber macOS UI Tests fehlen noch. BUG_111 (TCC-Dialog) blockiert automatisierte Ausfuehrung via SSH. Nach BUG_111-Fix: mac-test Befehl in sim.sh + Adversary-Gate fuer macOS UI Tests erweitern. |
| TD_006 | Dead Code nach Monster-Entfernung | Low | S | Beide | Nach Commit 5f6ae47 haben folgende Dateien KEINE Aufrufer mehr in Views: `DisciplineTrendChart.swift` (kein Aufrufer), `ReviewComponents.swift` (DisciplineBar-Structs ohne Aufrufer), `DisciplineStatsService.swift` (nur noch in Unit Tests referenziert). Compilieren fehlerfrei, werden aber nie gerendert. `.safeAreaInset(edge: .top) { EmptyView() }` in BacklogView.swift — ERLEDIGT (verursachte schwarzen Gap). |
| ~~TD_005~~ | ~~Monster-Removal: Validierungstests~~ | ~~High~~ | ~~S~~ | ~~Beide~~ | ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~BUG_123~~ | ~~Recurring Child-Duplikate: 3x gleicher Task mit gleichem Datum im Backlog~~ | ~~High~~ | ~~S~~ | ~~Beide~~ | ~~Historische GroupID-Fragmentierung fuehrte zu mehreren offenen Instanzen derselben Serie mit identischem Datum. `deduplicateTemplates()` reassigned Kinder, aber deduplizierte nicht nach Datum. Fix: `deduplicateChildInstances()` in Startup-Sequenz nach Template-Dedup. Analyse: `docs/artifacts/bug-recurring-stacking/analysis.md`~~ ERLEDIGT |
| ~~BUG_122~~ | ~~Sort-Lock: Nicht alle Task-Attribute editierbar waehrend Sortier-Sperre~~ | ~~High~~ | ~~S~~ | ~~iOS~~ | ~~`blockedRow()` in BacklogView.swift übergab keine Inline-Badge-Callbacks. Fix: 5 Callbacks (Importance, Urgency, Category, Duration, isPendingResort) ergänzt. macOS war nicht betroffen.~~ ERLEDIGT |
| BUG_115 | Unit Test: BadgeOverdueNotificationTests erwartet 3 Actions, bekommt 4 | Medium | S | iOS | `test_dueDateCategory_isRegistered` erwartet 3 Notification-Aktionen, findet aber 4. Vermutlich wurde eine Aktion hinzugefuegt ohne den Test anzupassen. |
| BUG_116 | Unit Test: LocalTaskSourceTests + SyncEngineTests Sortierung falsch | Medium | S | iOS | `test_fetchIncompleteTasks_sortsBySortOrder` und `test_sync_sortsByRank`: Tasks sind in falscher Reihenfolge. Sort-Logik in LocalTaskSource/SyncEngine stimmt nicht mit Test-Erwartungen ueberein. |
| BUG_117 | Unit Test: LocalTaskTests Default-Werte phase/category fehlen | Medium | S | iOS | `test_localTask_defaultValues_phase1`: Erwartet `phase="not_urgent"` und `category="maintenance"`, bekommt `nil`/`""`. Defaultwerte fehlen oder wurden geaendert. |
| BUG_118 | Unit Test: NotificationSnoozeTests Postpone Next Week kaputt | Medium | S | iOS | `test_postponeNextWeek_advancesDueDateBySevenDays`: Datum wird nicht korrekt um 7 Tage vorgerueckt. Differenz zwischen erwartet/erhalten ist viel zu gross. |
| BUG_119 | Unit Test: ReviewEventIntegrationTests Calendar-Events nicht kategorisiert | Medium | S | iOS | `testCategoryStatsIncludesCalendarEvents`: Erwartet 60/30 Min, erhaelt nil. Calendar-Events werden nicht in Category-Statistiken eingerechnet. |
| BUG_120 | Unit Test: SmartTaskEnrichmentServiceTests CloudKit Error 134407 | Low | S | iOS | `test_createTask_enrichesAttributes_whenAvailable` schlaegt mit CloudKit/Store-Removal-Fehler (Error 134407) fehl. Vermutlich Test-Setup-Problem. |
| ~~BUG_121~~ | ~~App crasht beim Start ohne iCloud-Account (CloudKit SIGTRAP)~~ | ~~Critical~~ | ~~S~~ | ~~Beide~~ | ~~App crashte bei normalem Start auf Geraeten/Simulatoren ohne iCloud-Account. `cloudKitDatabase: .private()` loeste SIGTRAP in `PFCloudKitContainerProvider` aus. Fix: `ubiquityIdentityToken`-Pruefung vor CloudKit-Init, Fallback auf lokalen Speicher. Eingefuehrt in Commit 5946410, gefixt in bug-cloudkit-crash Workflow.~~ ERLEDIGT |
| ~~INFRA_001~~ | ~~TDD GREEN Gate: User muss Test-Ergebnisse freigeben~~ | ~~High~~ | ~~S~~ | ~~Beide~~ | ~~Nach TDD GREEN muss User "go" sagen bevor Validation. Verhindert dass Claude Test-Befunde ignoriert. Hooks: tdd_green_gate.py, tdd_green_listener.py~~ ERLEDIGT |
| ~~BUG_124~~ | ~~Datums-Keywords bleiben im Task-Titel stehen~~ | ~~High~~ | ~~S~~ | ~~Beide~~ | ~~`stripKeywords()` hatte nur Urgency-Regex, keine Datums-Keywords. Fix: Word-Boundary-Regex für heute/morgen/übermorgen/Wochentage/nächste Woche + englische Varianten. Analyse: `docs/artifacts/bug-124-keyword-strip/analysis.md`~~ ERLEDIGT |
| ~~BUG_125~~ | ~~"Bestehende Tasks analysieren" Button wendet neue Regeln nicht an~~ | ~~High~~ | ~~S~~ | ~~Beide~~ | ~~Button rief nur `enrichAllTbdTasks()` auf (KI-Enrichment), nicht `TaskTitleEngine` (Title-Cleanup, Datums-Extraktion, Dauer). Fix: Neue `reanalyzeAllTasks()` Methode mit 4-Step-Pipeline (deterministisch + KI). Section umbenannt zu "Automatische Task-Analyse". 14 Unit Tests. Analyse: `docs/artifacts/bug-reanalyze-tasks/analysis.md`~~ ERLEDIGT |
| BUG_111 | macOS UI Tests: "Enable UI Automation"-Dialog erscheint bei jedem Testlauf | High | S | macOS | **Problem:** Beim Ausfuehren von macOS UI Tests erscheint ein modaler Dialog "XCTest moechte Enable UI Automation. Verwende Touch ID..." auf dem iMac-Screen. Dialog blockiert Test-Ausfuehrung via SSH. **Root Cause:** Der Test-Runner `henemm.FocusBloxMacUITests.xctrunner` hat KEINEN Eintrag in der macOS TCC-Datenbank (`/Library/Application Support/com.apple.TCC/TCC.db`). Ohne TCC-Eintrag zeigt macOS bei jedem Lauf den Genehmigungsdialog. `sudo DevToolsSecurity -enable` loest dies NICHT — es behandelt `task_for_pid`-Debugger-Rechte, aber NICHT `kTCCServiceAccessibility`. **Fix-Ansatz:** Privacy Preferences Policy Control (PPPC) Konfigurationsprofil erstellen das `henemm.FocusBloxMacUITests.xctrunner` fuer `kTCCServiceAccessibility` vorausgewaehrt, installiert via `sudo profiles -I -F`. Analyse: `docs/artifacts/bug-111-macos-ui-test-dialog/analysis.md` |

---

## Workflow-Architektur Rework

| ID | Titel | Prio | Aufwand | Beschreibung |
|----|-------|------|---------|-------------|
| ~~INFRA_002~~ | ~~Workflow v3: Von 51 Hooks auf Phasenwechsel-Architektur~~ | ~~High~~ | ~~XL~~ | ~~P1+P2 erledigt: 6 neue Hooks (1.291 LoC) erstellt. Cutover (settings.json + alte Hooks löschen + State-Migration) als separater Schritt. [Spec](specs/infra/INFRA_002-workflow-v3.md)~~ ERLEDIGT |

### INFRA_002 — Migrationsplan

**Problem:** 51 Python-Hooks, 227KB shared State, instabiles Session-Tracking. Jeder Edit durchlaeuft 17 Hooks (bis 85s Timeout), jeder Bash-Befehl 15 Hooks (bis 365s). Bugs durch Race Conditions, Zombie-Workflows, Phase-Korruption.

**Ziel:** Gleiche Qualitaetssicherung, 90% weniger Komplexitaet.

**Architektur-Prinzipien:**
1. **Phasen bleiben** — der Workflow /01 bis /06 aendert sich nicht
2. **Hooks = Gesetz, CLAUDE.md = Guidance** — aber weniger Gesetze, bessere Gesetze
3. **QA ist unabhaengig** — separater Agent prueft, nicht derselbe Claude der implementiert
4. **Optimistische Validierung** — frei arbeiten innerhalb einer Phase, pruefen beim Phasenwechsel
5. **1 State-File pro Workflow** — kein shared mutable State

**Phase 1: State-Isolation (Eliminiert Session-Tracking-Bugs)**
- `workflow_state.json` → `.claude/workflows/<name>.json` (1 File pro Workflow)
- Jedes File enthaelt nur SEINEN State (Phase, Artifacts, affected_files)
- Aktiver Workflow wird per `.claude/workflows/.active` Symlink bestimmt
- Git Worktrees fuer echte Parallelitaet (statt Session-ID-Hacks)
- **Eliminiert:** session_env.py, TERM_SESSION_ID-Tracking, Race Conditions, Zombie-Workflows

**Phase 2: Hook-Konsolidierung (51 → 5 Hooks)**

| Hook | Event | Aufgabe |
|------|-------|---------|
| `phase_listener.py` | UserPromptSubmit | Approval, Override, Stop-Lock, Phase-Erkennung |
| `edit_gate.py` | PreToolUse (Edit/Write) | 1. Gehoert Datei zum aktiven Workflow? 2. Ist Phase >= phase6_implement? |
| `bash_gate.py` | PreToolUse (Bash) | 1. Build-Lock (parallele Builds). 2. Pre-Commit-Gate (alle Checks). 3. sim.sh Enforcement |
| `post_bash.py` | PostToolUse (Bash) | Build-Lock Release |
| `phase_transition.py` | PreToolUse (Bash) | Beim Phasenwechsel-Befehl: Validiert ALLE Voraussetzungen der naechsten Phase |

**Was `phase_transition.py` beim Phasenwechsel prueft (statt bei jedem Edit):**

| Uebergang | Validierung |
|-----------|-------------|
| → phase3_spec | Context-File existiert, Analyse-Findings vorhanden |
| → phase4_approved | Spec-File existiert, User hat "approved" gesagt |
| → phase5_tdd_red | Spec approved |
| → phase6_implement | RED Test-Artifacts existieren mit FAIL-Ergebnis |
| → phase7_validate | GREEN Test-Artifacts existieren mit PASS-Ergebnis |
| → phase8_complete | QA-Agent Verdict "VERIFIED", Docs aktualisiert |

**Phase 3: QA als separater Agent**
- Nach phase6_implement → QA-Agent wird automatisch gestartet (nicht derselbe Claude)
- QA-Agent hat NUR Lese-Rechte + Test-Ausfuehrung
- QA-Agent gibt Verdict: "VERIFIED" oder "NEEDS WORK: [Liste]"
- Nur bei "VERIFIED" ist Commit moeglich
- Adversary-Agent und Implementation-Validator werden zum Standard-QA-Flow

**Phase 4: Cleanup**
- 46 Hook-Dateien loeschen
- `workflow_state_multi.py` (1700 Zeilen) → `workflow.py` (~300 Zeilen)
- settings.json: 50 Hook-Eintraege → 5
- CLAUDE.md aktualisieren

**Risiken:**
- Waehrend Migration koennten bestehende Workflows inkonsistent werden → Freeze + Clean Cutover
- QA-Agent muss genauso streng sein wie die bisherigen Hooks → gruendlich testen
- Einige Hooks enthalten nuetzliche Logik die nicht verloren gehen darf (z.B. secrets_guard, scope_guard) → in phase_transition.py integrieren

**Reihenfolge:** Phase 1 → 2 → 3 → 4 (jeweils mit eigener Spec + Validation)

---

## Prioritaets-Legende

| Prio | Bedeutung |
|------|-----------|
| **Critical** | Blocker — App unbenutzbar oder Datenverlust |
| **High** | Kaputte/fehlende UX, falsche Anzeige |
| **Medium** | Nuetzliche Features die Produktivitaet verbessern |
| **Low** | Nice-to-have, langfristig |

## Status-Legende

| Status | Bedeutung |
|--------|-----------|
| **OFFEN** | Noch nicht begonnen |
| **SPEC READY** | Spec geschrieben & approved, Implementation ausstehend |
| **IN ARBEIT** | Aktive Bearbeitung |
| **ERLEDIGT** | Fertig → verschoben nach `docs/ARCHIVE-todos.md` |
| **BLOCKIERT** | Kann nicht fortgesetzt werden |

---

> **Dies ist das EINZIGE Backlog.** Kein zweites Backlog.
> **Archiv:** Alle erledigten Items → `docs/ARCHIVE-todos.md`
