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
| BUG_111 | macOS UI Tests: "Enable UI Automation"-Dialog erscheint bei jedem Testlauf | High | S | macOS | **Problem:** Beim Ausfuehren von macOS UI Tests erscheint ein modaler Dialog "XCTest moechte Enable UI Automation. Verwende Touch ID..." auf dem iMac-Screen. Dialog blockiert Test-Ausfuehrung via SSH. **Root Cause:** Der Test-Runner `henemm.FocusBloxMacUITests.xctrunner` hat KEINEN Eintrag in der macOS TCC-Datenbank (`/Library/Application Support/com.apple.TCC/TCC.db`). Ohne TCC-Eintrag zeigt macOS bei jedem Lauf den Genehmigungsdialog. `sudo DevToolsSecurity -enable` loest dies NICHT — es behandelt `task_for_pid`-Debugger-Rechte, aber NICHT `kTCCServiceAccessibility`. **Fix-Ansatz:** Privacy Preferences Policy Control (PPPC) Konfigurationsprofil erstellen das `henemm.FocusBloxMacUITests.xctrunner` fuer `kTCCServiceAccessibility` vorausgewaehrt, installiert via `sudo profiles -I -F`. Analyse: `docs/artifacts/bug-111-macos-ui-test-dialog/analysis.md` |
| BUG_113 | FocusBloxMac: Start-Crash in DEBUG — CloudKit Signing-Assertion | Critical | S | macOS | **Problem:** macOS App crasht beim Start in DEBUG-Builds mit EXC_BREAKPOINT auf `com.apple.coredata.cloudkit.queue`. **Root Cause:** `MacModelContainer.create()` in `FocusBloxMacApp.swift` aktiviert CloudKit (`.private("iCloud.com.henning.focusblox")`) auch in DEBUG-Builds. Leere `codeSigningTeamID` in DEBUG → `PFCloudKitSetupAssistant` internal assertion. **Fix:** `#if DEBUG` Guard: `cloudKitDatabase: .none` in DEBUG, `.private(...)` in RELEASE. **Status:** Crash nicht reproduzierbar (Signing aktuell gueltig), Fix als praventive Massnahme geplant. |
| BUG_114 | FocusBloxMac: App blockiert — SwiftData Cast-Fehler in LocalTask.tags | Critical | S | macOS | **Problem:** macOS App startet, aber Tasks werden nicht geladen. App haengt in Endlosschleife. **Stack Trace:** `ContentView.overdueTasks.getter` → `scoreFor(_:)` (Zeile 340) → `coachBoostedIDs.getter` (Zeile 372) → `planItems.getter` (Zeile 366) → `PlanItem.init(localTask:)` (Zeile 178) → `LocalTask.tags.getter` → SwiftData `swift_dynamicCastFailure` → `fatalError`. **Vermutung:** Schema-Mismatch nach Clean Build oder inkompatible persistierte Tags-Daten. Tritt nach Clean Build Folder + Build + Run auf. |

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
