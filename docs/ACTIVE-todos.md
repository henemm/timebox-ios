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
| FEATURE_010 | macOS Backlog: Keyboard Shortcuts | Low | S | macOS | Cmd+N (neuer Task), Cmd+Delete (loeschen), etc. Betrifft beide Modi (Normal + Monster) gleich. |
| FEATURE_011 | macOS Backlog: Undo (Cmd+Z) | Low | S | macOS | iOS hat Shake-to-Undo. macOS Backlog hat kein Cmd+Z-Undo. Betrifft beide Modi gleich. |
| FEATURE_017 | Stille-Regel: Nudges dynamisch canceln | Low | S | iOS | Geplante Nudges stoppen wenn Intention tagsueber erfuellt wird. |
| FEATURE_018 | macOS Enhanced Quick Capture | Low | L | macOS | macOS Produktivitaet. Kein Blocker. |
| FEATURE_019 | macOS Shortcuts.app Integration | Low | L | macOS | macOS Automatisierung. P3. |
| FEATURE_020 | macOS Focus Mode Integration | Low | M | macOS | macOS System-Integration. P3. |
| FEATURE_021 | OrganizeMyDay Intent | Low | XL | iOS | Komplexer Intent. Kann warten. |
| FEATURE_022 | CaptureContextIntent | Low | M | iOS | WARTEND auf Apple APIs (iOS 26.5/27). |
| FEATURE_026 | Priority View: Einheitliche Score-Sortierung & Coach-Boost | Medium | M | Beide | **ERLEDIGT** — Alle Sections (Ueberfaellig, Coach) nach Priority Score sortieren. Ueberfaellige Daten rot hervorheben. Monster-Modus boostet Score (+15) statt eigener Section. |
| TD_001 | God-Views aufbrechen | Low | L | Beide | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| TD_002 | View-Duplikation iOS/macOS | Low | L | Beide | ~5900 LoC verbleibend (von ~7300). BUG_109 View-Merge hat ~1400 LoC Duplikation eliminiert (CoachBacklogView.swift + MacCoachBacklogView.swift geloescht, in BacklogView/ContentView gemergt). Langfristig wichtig, kurzfristig kein Blocker. |
| BUG_109 | ~~Backlog: Relevanz-Sortierung invertiert~~ | High | S | iOS | **ERLEDIGT** — Next Up Section hatte keine Score-Sortierung (Tasks in DB-Einfuegereihenfolge statt nach priorityScore absteigend). Fix: `.sorted { $0.priorityScore > $1.priorityScore }` in `nextUpTasks`. UI Test: `NextUpSortOrderUITests`. macOS war nicht betroffen (sortiert nach nextUpSortOrder). |
| BUG_110 | ~~macOS Coach-Backlog: Doppelte Controls ueber Task-Liste~~ | High | S | macOS | **ERLEDIGT** — Coach-Toolbar (ViewMode-Switcher + Sync/Import) entfernt; Sidebar und App-Toolbar decken alles ab. |
| BUG_111 | macOS UI Tests: "Enable UI Automation"-Dialog erscheint bei jedem Testlauf | High | S | macOS | **Problem:** Beim Ausfuehren von macOS UI Tests erscheint ein modaler Dialog "XCTest moechte Enable UI Automation. Verwende Touch ID..." auf dem iMac-Screen. Dialog blockiert Test-Ausfuehrung via SSH. **Root Cause:** Der Test-Runner `henemm.FocusBloxMacUITests.xctrunner` hat KEINEN Eintrag in der macOS TCC-Datenbank (`/Library/Application Support/com.apple.TCC/TCC.db`). Ohne TCC-Eintrag zeigt macOS bei jedem Lauf den Genehmigungsdialog. `sudo DevToolsSecurity -enable` loest dies NICHT — es behandelt `task_for_pid`-Debugger-Rechte, aber NICHT `kTCCServiceAccessibility`. **Fix-Ansatz:** Privacy Preferences Policy Control (PPPC) Konfigurationsprofil erstellen das `henemm.FocusBloxMacUITests.xctrunner` fuer `kTCCServiceAccessibility` vorausgewaehrt, installiert via `sudo profiles -I -F`. Analyse: `docs/artifacts/bug-111-macos-ui-test-dialog/analysis.md` |
| FEATURE_023 | ~~macOS Suche vereinheitlichen~~ | High | S | macOS | **ERLEDIGT** — v1.1: Quick-Add Bar entfernt, (+) Button + MacTaskCreateSheet. v2 (2026-03-19): `.searchable()` Toolbar-Suche durch Inline-TextField ersetzt (backlogSearchField). Alle UI Tests gruen. Specs: `docs/specs/macos/feature-023-unified-search.md`, `docs/specs/macos/feature-023-v2-inline-search.md` |
| FEATURE_004 | ~~Coach-Backlog-Suche (macOS)~~ | Medium | S | macOS | **ERLEDIGT** — Implementiert durch FEATURE_023_v2 (Inline-Suchfeld über Task-Liste). Coach-Backlog filtert in Echtzeit. Alle 4 TDD-Tests GREEN. Abgeschlossen 2026-03-19. |
| TD_003 | ~~Workflow-Bypass-Haertung~~ | Critical | M | Tooling | **ERLEDIGT** — 4 Bypass-Vektoren geschlossen: (1) `state_integrity_guard.py` blockiert Bash-Schreibzugriffe auf State/Hooks/Settings, (2) `set-field` Blocklist auf 16 Felder erweitert, (3) `--force` Flag entfernt, (4) `.claude/hooks/` aus Whitelists entfernt. |

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
