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
| ~~FEATURE_003~~ | ~~Coach-Backlog macOS: Quick-Add TextField~~ | ~~Medium~~ | ~~S~~ | ~~macOS~~ | **DONE** — Quick-Add TextField + Button + onAddTask callback. Tests: 2 UI tests gruen. |
| FEATURE_004 | Coach-Backlog macOS: Suchfunktion | Medium | S | macOS | Normaler macOS-Backlog hat .searchable — Coach-Backlog nicht. |
| FEATURE_006 | Coach-Backlog macOS: Inspector Panel | Medium | M | macOS | Normaler macOS-Backlog hat Detail-Inspector rechts (3-Spalten-Layout). Coach-Backlog zeigt nur Liste. |
| FEATURE_007 | Coach-Backlog macOS: Multi-Selection + Bulk Actions | Medium | M | macOS | Normaler macOS-Backlog unterstuetzt Mehrfachauswahl + Bulk-Loeschen/Verschieben. Coach-Backlog nur Einzelaktionen. |
| FEATURE_008 | Coach-Backlog macOS: Drag-to-Reorder NextUp | Low | S | macOS | Normaler macOS-Backlog erlaubt NextUp-Reihenfolge per Drag&Drop. Coach-Backlog nicht. |
| FEATURE_009 | Coach-Backlog macOS: Deferred Sort/Completion Feedback | Medium | S | macOS | Normaler macOS-Backlog zeigt visuelles Feedback bei Sort-Aenderungen (isPendingResort, isCompletionPending). Coach-Backlog gibt diese Parameter nicht an MacBacklogRow weiter. |
| FEATURE_010 | Coach-Backlog macOS: Keyboard Shortcuts | Low | S | macOS | Normaler macOS-Backlog hat Cmd+N (neuer Task), Cmd+Delete (loeschen), etc. Coach-Backlog keine. |
| FEATURE_011 | Coach-Backlog macOS: Undo (Cmd+Z) | Low | S | macOS | iOS Coach-Backlog hat Shake-to-Undo. macOS Coach-Backlog hat kein Cmd+Z-Undo. |
| FEATURE_013 | Coach-Backlog macOS: Serien-Bearbeitung | Low | S | macOS | Recurring-Task-Dialoge (Serie vs. Einzelaufgabe) fehlen auf macOS (MacCoachBacklogView + MacBacklogRow). iOS BacklogView + CoachBacklogView haben sie bereits. |
| FEATURE_014 | Coach-Backlog: Apple Reminders Import | Medium | M | Beide | Beide Plattformen: Normaler Backlog hat Reminders-Import-Funktion. Coach-Backlog nicht. |
| FEATURE_015 | UX: Tag-Auswahl redesignen | Medium | S | iOS | Tag-Sektion in TaskFormSheet unuebersichtlich: "Neuer Tag" dominiert, bestehende Tags kommen danach. Redesign: Tags als antippbare Chips, "Neuer Tag" darunter. Vorbild: Apple Erinnerungen. |
| FEATURE_017 | Stille-Regel: Nudges dynamisch canceln | Low | S | iOS | Geplante Nudges stoppen wenn Intention tagsueber erfuellt wird. |
| FEATURE_018 | macOS Enhanced Quick Capture | Low | L | macOS | macOS Produktivitaet. Kein Blocker. |
| FEATURE_019 | macOS Shortcuts.app Integration | Low | L | macOS | macOS Automatisierung. P3. |
| FEATURE_020 | macOS Focus Mode Integration | Low | M | macOS | macOS System-Integration. P3. |
| FEATURE_021 | OrganizeMyDay Intent | Low | XL | iOS | Komplexer Intent. Kann warten. |
| FEATURE_022 | CaptureContextIntent | Low | M | iOS | WARTEND auf Apple APIs (iOS 26.5/27). |
| TD_001 | God-Views aufbrechen | Low | L | Beide | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| TD_002 | View-Duplikation iOS/macOS | Low | XL | Beide | ~7300 LoC verbleibend. Langfristig wichtig, kurzfristig kein Blocker. |
| ~~BUG_107~~ | ~~Coach-Backlog: Blocked Tasks erscheinen doppelt~~ | ~~High~~ | ~~S~~ | ~~Beide~~ | **ERLEDIGT** — 4 Filter in CoachBacklogViewModel ergaenzt (`blockerTaskID == nil` / `!isBlocked`): nextUpTasks, remainingTasks, overdueTasks, recentTasks. 30/30 Unit Tests gruen. 3 pre-existing Eule-Test-Failures korrigiert (Design-Limitierung: Eule-Coach-Boost immer leer weil NextUp eigene Section hat). |
| ~~BUG_108~~ | ~~Zehnagel-Zombie: Recurring Task ueberlebt Serien-Ende~~ | ~~High~~ | ~~S-M~~ | ~~Beide~~ | **DONE.** Fix: (1) deleteRecurringTemplate neutralisiert completed Tasks (recurrencePattern=none), (2) Startup-Reihenfolge migration→dedup→repair. Analyse: `docs/artifacts/bug-108-zehnagel-zombie/analysis.md` |

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
