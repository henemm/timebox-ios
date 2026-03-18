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
| FEATURE_015 | UX: Tag-Auswahl redesignen | Medium | S | iOS | Tag-Sektion in TaskFormSheet unuebersichtlich: "Neuer Tag" dominiert, bestehende Tags kommen danach. Redesign: Tags als antippbare Chips, "Neuer Tag" darunter. Vorbild: Apple Erinnerungen. |
| FEATURE_017 | Stille-Regel: Nudges dynamisch canceln | Low | S | iOS | Geplante Nudges stoppen wenn Intention tagsueber erfuellt wird. |
| FEATURE_018 | macOS Enhanced Quick Capture | Low | L | macOS | macOS Produktivitaet. Kein Blocker. |
| FEATURE_019 | macOS Shortcuts.app Integration | Low | L | macOS | macOS Automatisierung. P3. |
| FEATURE_020 | macOS Focus Mode Integration | Low | M | macOS | macOS System-Integration. P3. |
| FEATURE_021 | OrganizeMyDay Intent | Low | XL | iOS | Komplexer Intent. Kann warten. |
| FEATURE_022 | CaptureContextIntent | Low | M | iOS | WARTEND auf Apple APIs (iOS 26.5/27). |
| TD_001 | God-Views aufbrechen | Low | L | Beide | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| TD_002 | View-Duplikation iOS/macOS | Low | L | Beide | ~5900 LoC verbleibend (von ~7300). BUG_109 View-Merge hat ~1400 LoC Duplikation eliminiert (CoachBacklogView.swift + MacCoachBacklogView.swift geloescht, in BacklogView/ContentView gemergt). Langfristig wichtig, kurzfristig kein Blocker. |

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
