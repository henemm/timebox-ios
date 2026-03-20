# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!
> **Archiv:** Erledigte Items → `docs/ARCHIVE-todos.md`
> **IDs:** `BUG_XXX` = Bugs, `FEATURE_XXX` = Features, `TD_XXX` = Tech Debt

---

## Offene Items

| ID | Titel | Prio | Aufwand | Plattform | Beschreibung |
|----|-------|------|---------|-----------|-------------|
| FEATURE_010 | macOS Backlog: Keyboard Shortcuts | Low | S | macOS | Cmd+N (neuer Task), Cmd+Delete (loeschen), etc. |
| FEATURE_011 | macOS Backlog: Undo (Cmd+Z) | Low | S | macOS | iOS hat Shake-to-Undo. macOS Backlog hat kein Cmd+Z-Undo. |
| FEATURE_018 | macOS Enhanced Quick Capture | Low | L | macOS | macOS Produktivitaet. Kein Blocker. |
| FEATURE_019 | macOS Shortcuts.app Integration | Low | L | macOS | macOS Automatisierung. P3. |
| FEATURE_020 | macOS Focus Mode Integration | Low | M | macOS | macOS System-Integration. P3. |
| FEATURE_021 | OrganizeMyDay Intent | Low | XL | iOS | Komplexer Intent. Kann warten. |
| FEATURE_022 | CaptureContextIntent | Low | M | iOS | WARTEND auf Apple APIs (iOS 26.5/27). |
| TD_001 | God-Views aufbrechen | Low | L | Beide | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| TD_002 | View-Duplikation iOS/macOS | Low | L | Beide | Verbleibende Duplikation zwischen Sources/Views und FocusBloxMac. Langfristig wichtig, kurzfristig kein Blocker. |
| TD_003 | Dead Code nach Monster-Entfernung | Low | S | Beide | Nach Commit 5f6ae47 haben folgende Dateien KEINE Aufrufer mehr in Views: `DisciplineTrendChart.swift` (kein Aufrufer), `ReviewComponents.swift` (DisciplineBar-Structs ohne Aufrufer), `DisciplineStatsService.swift` (nur noch in Unit Tests referenziert). Compilieren fehlerfrei, werden aber nie gerendert. |
| TD_004 | ~~Monster-Removal: Dead Code Cleanup~~ | ~~High~~ | ~~S~~ | ~~Beide~~ | **ERLEDIGT.** 4 tote Dateien geloescht (DailyIntention.swift, 3 Coach-UI-Tests), 3 Dateien bereinigt (DebugHierarchy, MacToolbar, AI-Prompt), PBX-Refs entfernt. -426 LoC. 6 Validierungstests GRUEN. |
| TD_005 | Monster-Removal: Validierungstests | High | S | Beide | **Ticket B.** Regressionstests nach Monster-Entfernung: Negative Tests (kein Coach-Tab, keine Coach-Settings, keine Monster-Images), Scoring ohne Coach-Boost, Discipline ohne Coach-Override. ~+80 LoC. Abhaengig von TD_004. Analyse: `docs/context/monster-removal-validation.md` |
| BUG_115 | Unit Test: BadgeOverdueNotificationTests erwartet 3 Actions, bekommt 4 | Medium | S | iOS | `test_dueDateCategory_isRegistered` erwartet 3 Notification-Aktionen, findet aber 4. Vermutlich wurde eine Aktion hinzugefuegt ohne den Test anzupassen. |
| BUG_116 | Unit Test: LocalTaskSourceTests + SyncEngineTests Sortierung falsch | Medium | S | iOS | `test_fetchIncompleteTasks_sortsBySortOrder` und `test_sync_sortsByRank`: Tasks sind in falscher Reihenfolge. Sort-Logik in LocalTaskSource/SyncEngine stimmt nicht mit Test-Erwartungen ueberein. |
| BUG_117 | Unit Test: LocalTaskTests Default-Werte phase/category fehlen | Medium | S | iOS | `test_localTask_defaultValues_phase1`: Erwartet `phase="not_urgent"` und `category="maintenance"`, bekommt `nil`/`""`. Defaultwerte fehlen oder wurden geaendert. |
| BUG_118 | Unit Test: NotificationSnoozeTests Postpone Next Week kaputt | Medium | S | iOS | `test_postponeNextWeek_advancesDueDateBySevenDays`: Datum wird nicht korrekt um 7 Tage vorgerueckt. Differenz zwischen erwartet/erhalten ist viel zu gross. |
| BUG_119 | Unit Test: ReviewEventIntegrationTests Calendar-Events nicht kategorisiert | Medium | S | iOS | `testCategoryStatsIncludesCalendarEvents`: Erwartet 60/30 Min, erhaelt nil. Calendar-Events werden nicht in Category-Statistiken eingerechnet. |
| BUG_120 | Unit Test: SmartTaskEnrichmentServiceTests CloudKit Error 134407 | Low | S | iOS | `test_createTask_enrichesAttributes_whenAvailable` schlaegt mit CloudKit/Store-Removal-Fehler (Error 134407) fehl. Vermutlich Test-Setup-Problem. |
| BUG_111 | macOS UI Tests: "Enable UI Automation"-Dialog erscheint bei jedem Testlauf | High | S | macOS | **Problem:** Beim Ausfuehren von macOS UI Tests erscheint ein modaler Dialog "XCTest moechte Enable UI Automation. Verwende Touch ID..." auf dem iMac-Screen. Dialog blockiert Test-Ausfuehrung via SSH. **Root Cause:** Der Test-Runner `henemm.FocusBloxMacUITests.xctrunner` hat KEINEN Eintrag in der macOS TCC-Datenbank (`/Library/Application Support/com.apple.TCC/TCC.db`). Ohne TCC-Eintrag zeigt macOS bei jedem Lauf den Genehmigungsdialog. `sudo DevToolsSecurity -enable` loest dies NICHT — es behandelt `task_for_pid`-Debugger-Rechte, aber NICHT `kTCCServiceAccessibility`. **Fix-Ansatz:** Privacy Preferences Policy Control (PPPC) Konfigurationsprofil erstellen das `henemm.FocusBloxMacUITests.xctrunner` fuer `kTCCServiceAccessibility` vorausgewaehrt, installiert via `sudo profiles -I -F`. Analyse: `docs/artifacts/bug-111-macos-ui-test-dialog/analysis.md` |
| BUG_113 | FocusBloxMac: Start-Crash in DEBUG — CloudKit Signing-Assertion | Critical | S | macOS | **Problem:** macOS App crasht beim Start in DEBUG-Builds mit EXC_BREAKPOINT auf `com.apple.coredata.cloudkit.queue`. **Root Cause:** `MacModelContainer.create()` in `FocusBloxMacApp.swift` aktiviert CloudKit (`.private("iCloud.com.henning.focusblox")`) auch in DEBUG-Builds. Leere `codeSigningTeamID` in DEBUG → `PFCloudKitSetupAssistant` internal assertion. **Fix:** `#if DEBUG` Guard: `cloudKitDatabase: .none` in DEBUG, `.private(...)` in RELEASE. **Status:** Crash nicht reproduzierbar (Signing aktuell gueltig), Fix als praventive Massnahme geplant. |
| BUG_114 | ~~FocusBloxMac: App blockiert — SwiftData Cast-Fehler in LocalTask.tags~~ | ~~Critical~~ | ~~S~~ | ~~macOS~~ | **ERLEDIGT.** Root Cause: `LocalTask.tags` war `[String]` (non-optional). Bei NULL in SQLite (CloudKit sync) → `swift_dynamicCastFailure`. Fix: `tags` auf `[String]?` (optional) + `?? []` an allen ~20 Zugriffspunkten. Auch WatchLocalTask + TaskSourceData-Protokoll angepasst. |

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
