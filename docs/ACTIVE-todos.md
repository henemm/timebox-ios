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
| FEATURE_001 | Coach-Backlog iOS: Recurring-Serie-Dialoge | High | S | iOS | "Nur diese Aufgabe"/"Alle dieser Serie"-Dialoge fehlen beim Loeschen/Bearbeiten wiederkehrender Tasks. BacklogView hat taskToDeleteRecurring + editSeriesMode — Coach-Backlog nicht. Datenverlust-Risiko. |
| FEATURE_002 | Coach-Backlog iOS: Blocked-Row Editing | Medium | S | iOS | Blocked Rows im Coach-Backlog sind read-only. In BacklogView erlauben sie Duration/Importance/Category-Aenderungen. |
| FEATURE_003 | Coach-Backlog macOS: Quick-Add TextField | Medium | S | macOS | Normaler macOS-Backlog hat Quick-Add-TextField oben — Coach-Backlog nicht. |
| FEATURE_004 | Coach-Backlog macOS: Suchfunktion | Medium | S | macOS | Normaler macOS-Backlog hat .searchable — Coach-Backlog nicht. |
| FEATURE_005 | Coach-Backlog macOS: Toolbar (Sync + Import) | High | S-M | macOS | Normaler macOS-Backlog zeigt Sync-Status-Indicator + Apple-Reminders-Import-Button in Toolbar. Coach-Backlog hat nur ViewMode-Switcher. Fehlende Sync-Sichtbarkeit. |
| FEATURE_006 | Coach-Backlog macOS: Inspector Panel | Medium | M | macOS | Normaler macOS-Backlog hat Detail-Inspector rechts (3-Spalten-Layout). Coach-Backlog zeigt nur Liste. |
| FEATURE_007 | Coach-Backlog macOS: Multi-Selection + Bulk Actions | Medium | M | macOS | Normaler macOS-Backlog unterstuetzt Mehrfachauswahl + Bulk-Loeschen/Verschieben. Coach-Backlog nur Einzelaktionen. |
| FEATURE_008 | Coach-Backlog macOS: Drag-to-Reorder NextUp | Low | S | macOS | Normaler macOS-Backlog erlaubt NextUp-Reihenfolge per Drag&Drop. Coach-Backlog nicht. |
| FEATURE_009 | Coach-Backlog macOS: Deferred Sort/Completion Feedback | Medium | S | macOS | Normaler macOS-Backlog zeigt visuelles Feedback bei Sort-Aenderungen (isPendingResort, isCompletionPending). Coach-Backlog gibt diese Parameter nicht an MacBacklogRow weiter. |
| FEATURE_010 | Coach-Backlog macOS: Keyboard Shortcuts | Low | S | macOS | Normaler macOS-Backlog hat Cmd+N (neuer Task), Cmd+Delete (loeschen), etc. Coach-Backlog keine. |
| FEATURE_011 | Coach-Backlog macOS: Undo (Cmd+Z) | Low | S | macOS | iOS Coach-Backlog hat Shake-to-Undo. macOS Coach-Backlog hat kein Cmd+Z-Undo. |
| FEATURE_012 | Coach-Backlog macOS: effectiveScore/Tier/dependentCount | High | S | macOS | MacBacklogRow bekommt diese Parameter nicht von Coach-Backlog. Normaler Backlog schon. Betrifft Badge-Anzeige und visuelle Priorisierung — falsche Darstellung. |
| FEATURE_013 | Coach-Backlog macOS: Serien-Bearbeitung | Low | S | macOS | Recurring-Task-Dialoge (Serie vs. Einzelaufgabe) fehlen auf macOS — sowohl in Coach- als auch normalem Backlog. |
| FEATURE_014 | Coach-Backlog: Apple Reminders Import | Medium | M | Beide | Beide Plattformen: Normaler Backlog hat Reminders-Import-Funktion. Coach-Backlog nicht. |
| FEATURE_015 | UX: Tag-Auswahl redesignen | Medium | S | iOS | Tag-Sektion in TaskFormSheet unuebersichtlich: "Neuer Tag" dominiert, bestehende Tags kommen danach. Redesign: Tags als antippbare Chips, "Neuer Tag" darunter. Vorbild: Apple Erinnerungen. |
| FEATURE_016 | ~~Disziplin-Entwicklung sichtbar machen~~ | ~~Low~~ | ~~M~~ | ~~Beide~~ | **ERLEDIGT** — Phase 1: Disziplin-Profil (Heute + Woche) in CoachMeinTagView. Phase 2 (Multi-Wochen-Trend mit Charts) als separates Ticket. |
| FEATURE_017 | Stille-Regel: Nudges dynamisch canceln | Low | S | iOS | Geplante Nudges stoppen wenn Intention tagsueber erfuellt wird. |
| FEATURE_018 | macOS Enhanced Quick Capture | Low | L | macOS | macOS Produktivitaet. Kein Blocker. |
| FEATURE_019 | macOS Shortcuts.app Integration | Low | L | macOS | macOS Automatisierung. P3. |
| FEATURE_020 | macOS Focus Mode Integration | Low | M | macOS | macOS System-Integration. P3. |
| FEATURE_021 | OrganizeMyDay Intent | Low | XL | iOS | Komplexer Intent. Kann warten. |
| FEATURE_022 | CaptureContextIntent | Low | M | iOS | WARTEND auf Apple APIs (iOS 26.5/27). |
| TD_001 | God-Views aufbrechen | Low | L | Beide | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| TD_002 | View-Duplikation iOS/macOS | Low | XL | Beide | ~7300 LoC verbleibend. Langfristig wichtig, kurzfristig kein Blocker. |

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
