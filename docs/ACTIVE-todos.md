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

| ID | Epic | Titel | Prio | Aufwand | Spec |
|----|------|-------|------|---------|------|
| RW_0.1 | 0 Infrastruktur | Smart Notification Engine | High | M | [Spec](specs/rework/0.1-smart-notification-engine.md) |
| RW_0.2 | 0 Infrastruktur | BehavioralProfileService | High | M | [Spec](specs/rework/0.2-behavioral-profile-service.md) |
| ~~RW_1.1~~ | ~~1 Erfassung~~ | ~~Quick Dump~~ | ~~High~~ | ~~M~~ | ~~[Spec](specs/rework/1.1-quick-dump.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_1.2~~ | ~~1 Erfassung~~ | ~~AI Context Extraction (Schema)~~ | ~~High~~ | ~~L~~ | ~~[Spec](specs/rework/1.2-1.3-refiner-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| ~~RW_1.3~~ | ~~1 Erfassung~~ | ~~The Refiner (UI)~~ | ~~High~~ | ~~L~~ | ~~[Spec](specs/rework/1.2-1.3-refiner-impl.md)~~ ERLEDIGT → [Archiv](ARCHIVE-todos.md) |
| RW_3.1 | 3 Ausfuehrung | Task direkt auf Kalender droppen | Medium | L | [Spec](specs/rework/3.1-calendar-task-drop.md) |
| ~~RW_3.2~~ | ~~3 Ausfuehrung~~ | ~~Focus Sprint ("Los"-Button)~~ | ~~Medium~~ | ~~M~~ | ~~[Spec](specs/rework/3.2-focus-sprint-impl.md)~~ ERLEDIGT |
| RW_3.3 | 3 Ausfuehrung | Follow-up Logic | Medium | S | [Spec](specs/rework/3.3-follow-up-logic.md) |
| RW_3.4 | 3 Ausfuehrung | Emotional Nudge (Micro-Tasks) | Medium | M | [Spec](specs/rework/3.4-emotional-nudge.md) |
| RW_2.1 | 2 Tagesplanung | Tagesansicht ("Dein Tag") | Medium | XL | [Spec](specs/rework/2.1-day-view.md) |
| RW_2.2 | 2 Tagesplanung | KI-gestuetzte Tagesvorschlaege | Medium | L | [Spec](specs/rework/2.2-next-up-suggestions.md) |
| RW_2.3 | 2 Tagesplanung | Limitation Guard | Medium | S | [Spec](specs/rework/2.3-limitation-guard.md) |
| RW_2.4 | 2 Tagesplanung | Backlog UX Rework | Medium | L | [Spec](specs/rework/2.4-backlog-ux-rework.md) |
| RW_4.1 | 4 Reflexion | Soft Evening Reset | Low | M | [Spec](specs/rework/4.1-soft-evening-reset.md) |
| RW_4.2 | 4 Reflexion | Success Story Generator | Low | L | [Spec](specs/rework/4.2-success-story-generator.md) |
| RW_4.3 | 4 Reflexion | Failure Protocol | Low | M | [Spec](specs/rework/4.3-failure-protocol.md) |
| RW_4.4 | 4 Reflexion | Morning Widget | Low | M | [Spec](specs/rework/4.4-morning-widget.md) |

---

## Offene Items (Legacy)

| ID | Titel | Prio | Aufwand | Plattform | Beschreibung |
|----|-------|------|---------|-----------|-------------|
| FEATURE_010 | macOS Backlog: Keyboard Shortcuts | Low | S | macOS | Cmd+N (neuer Task), Cmd+Delete (loeschen), etc. |
| FEATURE_011 | macOS Backlog: Undo (Cmd+Z) | Low | S | macOS | iOS hat Shake-to-Undo. macOS Backlog hat kein Cmd+Z-Undo. |
| FEATURE_018 | macOS Enhanced Quick Capture | Low | L | macOS | macOS Produktivitaet. Kein Blocker. |
| FEATURE_019 | macOS Shortcuts.app Integration | Low | L | macOS | macOS Automatisierung. P3. |
| FEATURE_020 | macOS Focus Mode Integration | Low | M | macOS | macOS System-Integration. P3. |
| FEATURE_021 | OrganizeMyDay Intent | Low | XL | iOS | Komplexer Intent. Kann warten. |
| FEATURE_022 | CaptureContextIntent | Low | M | iOS | WARTEND auf Apple APIs (iOS 26.5/27). |
| FEATURE_023 | Focus Sprint: Inline-Duration-Picker | Low | S | iOS | Vor Sprint-Start Dauer anpassen (Inline-Picker, kein Sheet). Follow-up aus RW_3.2 — bewusst ausgescoped um LoC-Limit einzuhalten. Default-Dauer (estimatedDuration oder 60 Min) reicht vorerst. |
| TD_001 | God-Views aufbrechen | Low | L | Beide | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| TD_002 | View-Duplikation iOS/macOS | Low | L | Beide | Verbleibende Duplikation zwischen Sources/Views und FocusBloxMac. Langfristig wichtig, kurzfristig kein Blocker. |
| TD_003 | Dead Code nach Monster-Entfernung | Low | S | Beide | Nach Commit 5f6ae47 haben folgende Dateien KEINE Aufrufer mehr in Views: `DisciplineTrendChart.swift` (kein Aufrufer), `ReviewComponents.swift` (DisciplineBar-Structs ohne Aufrufer), `DisciplineStatsService.swift` (nur noch in Unit Tests referenziert). Compilieren fehlerfrei, werden aber nie gerendert. |
| TD_005 | Monster-Removal: Validierungstests | High | S | Beide | **Ticket B.** Regressionstests nach Monster-Entfernung: Negative Tests (kein Coach-Tab, keine Coach-Settings, keine Monster-Images), Scoring ohne Coach-Boost, Discipline ohne Coach-Override. ~+80 LoC. Abhaengig von TD_004. Analyse: `docs/context/monster-removal-validation.md` |
| BUG_115 | Unit Test: BadgeOverdueNotificationTests erwartet 3 Actions, bekommt 4 | Medium | S | iOS | `test_dueDateCategory_isRegistered` erwartet 3 Notification-Aktionen, findet aber 4. Vermutlich wurde eine Aktion hinzugefuegt ohne den Test anzupassen. |
| BUG_116 | Unit Test: LocalTaskSourceTests + SyncEngineTests Sortierung falsch | Medium | S | iOS | `test_fetchIncompleteTasks_sortsBySortOrder` und `test_sync_sortsByRank`: Tasks sind in falscher Reihenfolge. Sort-Logik in LocalTaskSource/SyncEngine stimmt nicht mit Test-Erwartungen ueberein. |
| BUG_117 | Unit Test: LocalTaskTests Default-Werte phase/category fehlen | Medium | S | iOS | `test_localTask_defaultValues_phase1`: Erwartet `phase="not_urgent"` und `category="maintenance"`, bekommt `nil`/`""`. Defaultwerte fehlen oder wurden geaendert. |
| BUG_118 | Unit Test: NotificationSnoozeTests Postpone Next Week kaputt | Medium | S | iOS | `test_postponeNextWeek_advancesDueDateBySevenDays`: Datum wird nicht korrekt um 7 Tage vorgerueckt. Differenz zwischen erwartet/erhalten ist viel zu gross. |
| BUG_119 | Unit Test: ReviewEventIntegrationTests Calendar-Events nicht kategorisiert | Medium | S | iOS | `testCategoryStatsIncludesCalendarEvents`: Erwartet 60/30 Min, erhaelt nil. Calendar-Events werden nicht in Category-Statistiken eingerechnet. |
| BUG_120 | Unit Test: SmartTaskEnrichmentServiceTests CloudKit Error 134407 | Low | S | iOS | `test_createTask_enrichesAttributes_whenAvailable` schlaegt mit CloudKit/Store-Removal-Fehler (Error 134407) fehl. Vermutlich Test-Setup-Problem. |
| BUG_111 | macOS UI Tests: "Enable UI Automation"-Dialog erscheint bei jedem Testlauf | High | S | macOS | **Problem:** Beim Ausfuehren von macOS UI Tests erscheint ein modaler Dialog "XCTest moechte Enable UI Automation. Verwende Touch ID..." auf dem iMac-Screen. Dialog blockiert Test-Ausfuehrung via SSH. **Root Cause:** Der Test-Runner `henemm.FocusBloxMacUITests.xctrunner` hat KEINEN Eintrag in der macOS TCC-Datenbank (`/Library/Application Support/com.apple.TCC/TCC.db`). Ohne TCC-Eintrag zeigt macOS bei jedem Lauf den Genehmigungsdialog. `sudo DevToolsSecurity -enable` loest dies NICHT — es behandelt `task_for_pid`-Debugger-Rechte, aber NICHT `kTCCServiceAccessibility`. **Fix-Ansatz:** Privacy Preferences Policy Control (PPPC) Konfigurationsprofil erstellen das `henemm.FocusBloxMacUITests.xctrunner` fuer `kTCCServiceAccessibility` vorausgewaehrt, installiert via `sudo profiles -I -F`. Analyse: `docs/artifacts/bug-111-macos-ui-test-dialog/analysis.md` |

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
