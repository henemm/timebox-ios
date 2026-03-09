# Bug 85: Erinnerung mit Uhrzeit + Notification Snooze + Kontextmenü Verschieben

## Scope: 3 Tickets (vom User gewünscht)

- **85-A**: Uhrzeit bei Fälligkeitsdatum überall anzeigen
- **85-B**: Notification Snooze-Optionen (wie Apple Reminders)
- **85-C**: Kontextmenü "Verschieben"-Optionen auf iOS + macOS

**Challenge-Verdict:** LÜCKEN → eingearbeitet (siehe unten)

---

## Ticket 85-A: Uhrzeit bei Fälligkeitsdatum anzeigen

### IST-Zustand

Die Uhrzeit wird in 2 von 3 DatePickern gespeichert (`[.date, .hourAndMinute]` in CreateTaskView + TaskFormSheet), aber **nirgendwo angezeigt**.

### Zwei Probleme (nicht eins!)

**Problem 1 — Ausgabe:** Der Shared Formatter `Date+DueDate.swift:31` setzt `timeStyle = .none`. Zusätzlich umgehen die Early-Returns für "Heute" (Zeile 19-20) und "Morgen" (Zeile 21-22) den Formatter komplett — dort wird ein reiner String zurückgegeben, niemals mit Uhrzeit. D.h. selbst nach `timeStyle`-Fix würde "Heute" weiterhin ohne Uhrzeit angezeigt.

**Problem 2 — Eingabe (macOS):** `TaskInspector.swift:105` nutzt `displayedComponents: .date` (OHNE Uhrzeit). macOS-User können über den Inspector keine Uhrzeit setzen.

### Betroffene Anzeige-Stellen (alle 4)

| View | Datei | Zeile | Style | Plattform |
|------|-------|-------|-------|-----------|
| BacklogRow | Sources/Views/BacklogRow.swift | 187 | `.compact` | iOS |
| TaskPreviewView | Sources/Views/TaskPreviewView.swift | 83 | `.compact` | iOS |
| TaskDetailSheet | Sources/Views/TaskDetailSheet.swift | 185 | `.full` | iOS+macOS |
| MacBacklogRow | FocusBloxMac/MacBacklogRow.swift | 241 | `.compact` | macOS |

### DatePicker-Eingabe (Uhrzeit setzen)

| View | Datei | Zeile | Hat Uhrzeit? |
|------|-------|-------|--------------|
| CreateTaskView | Sources/Views/TaskCreation/CreateTaskView.swift | 135 | `[.date, .hourAndMinute]` |
| TaskFormSheet | Sources/Views/TaskFormSheet.swift | 217 | `[.date, .hourAndMinute]` |
| TaskInspector | FocusBloxMac/TaskInspector.swift | 105 | `.date` ONLY — **LÜCKE** |

### Fix-Ansatz

1. `Date+DueDate.swift`: ALLE Code-Pfade ändern (nicht nur Zeile 31):
   - "Heute" → "Heute, 14:30" (wenn Uhrzeit ≠ 00:00)
   - "Morgen" → "Morgen, 14:30" (wenn Uhrzeit ≠ 00:00)
   - Wochentag → "Mo, 14:30" (wenn Uhrzeit ≠ 00:00)
   - Datum → "12.03.26, 14:30" (wenn Uhrzeit ≠ 00:00)
2. `TaskInspector.swift:105`: `.date` → `[.date, .hourAndMinute]`

**Dateien:** 2 Dateien (`Date+DueDate.swift`, `TaskInspector.swift`)

**Blast Radius:** Minimal — Shared Formatter + 1 macOS DatePicker.

### Offene PO-Frage

Wenn Uhrzeit = 00:00: Ist das "nicht gesetzt" oder "bewusst Mitternacht"? Empfehlung: 00:00 = nicht gesetzt (keine Uhrzeitanzeige). User die um Mitternacht eine Deadline brauchen, sind ein extremer Edge Case.

---

## Ticket 85-B: Notification Snooze-Optionen

### IST-Zustand

Due-Date Notifications haben 3 Aktionen:
- "Next Up" — Task auf Next Up setzen
- "Morgen" — Frist +1 Tag verschieben
- "Erledigt" — Task als erledigt markieren

**Problem:** Nur "Morgen" (+1 Tag) als Verschiebe-Option. Apple Reminders bietet: 1 Stunde, Morgen, Nächste Woche.

### Betroffene Dateien

| Datei | Was ändern |
|-------|-----------|
| NotificationService.swift:20-39 | Aktion-Registrierung (neue Actions) |
| NotificationActionDelegate.swift:60-68 | ACTION_POSTPONE Handler ersetzen |
| WatchNotificationDelegate.swift:68-104 | watchOS Handler erweitern |
| WatchNotificationDelegate.swift:25-36 | **watchOS Registrierung** (eigene Kopie, nicht Shared!) |

### iOS Action-Limit: Max 4 pro Category

Aktuell 3, gewünscht wären 5 (Next Up + 3 Snooze + Erledigt). **Max 4 möglich.**

**Optionen (PO-Entscheidung):**
- **Option A:** Next Up, Morgen, Nächste Woche, Erledigt (4 Aktionen — "In 1 Stunde" weglassen)
- **Option B:** In 1 Stunde, Morgen, Nächste Woche, Erledigt (4 Aktionen — "Next Up" weglassen)
- **Option C:** Morgen, Nächste Woche, Erledigt (3 Aktionen + Next Up als Tipp im Body)

**Empfehlung: Option A** — "Morgen" und "Nächste Woche" sind die häufigsten Snooze-Aktionen, "Next Up" ist ein wichtiger Workflow-Bestandteil, "In 1 Stunde" ist seltener nützlich.

### Fix-Ansatz

1. `ACTION_POSTPONE` ersetzen durch `ACTION_POSTPONE_TOMORROW` (+1 Tag) + `ACTION_POSTPONE_NEXT_WEEK` (+7 Tage)
2. Registrierung in BEIDEN Stellen: `NotificationService.registerDueDateActions()` UND `WatchNotificationDelegate.registerActions()`
3. Handler in BEIDEN Delegates erweitern

**Dateien:** 3 Dateien (NotificationService, NotificationActionDelegate, WatchNotificationDelegate)

**Blast Radius:** Notification-System isoliert. Regression-Risiko: `ACTION_POSTPONE` wird gelöscht — alte Handler müssen entfernt, neue hinzugefügt werden.

---

## Ticket 85-C: Kontextmenü "Verschieben"-Optionen

### IST-Zustand

**Kein "Verschieben" / "Frist ändern" in irgendeinem Kontextmenü.** Weder iOS noch macOS.

#### iOS (3 Stellen mit Kontextmenü/Swipe):
| View | Typ | Aktionen |
|------|-----|----------|
| NextUpSection | `.contextMenu` | Bearbeiten, Aus Next Up entfernen, Löschen |
| TaskAssignmentView | `.contextMenu` | In Block verschieben |
| BacklogView | `.swipeActions` | Next Up, Löschen, Bearbeiten |

#### macOS (1 Stelle):
| View | Typ | Aktionen |
|------|-----|----------|
| ContentView | `.contextMenu(forSelectionType:)` | Erledigt, Kategorie, Next Up +/-, Serie bearbeiten, Löschen |

### Fix-Ansatz

Allen Kontextmenüs ein "Verschieben"-Untermenü hinzufügen:
- "Morgen" (+1 Tag)
- "Nächste Woche" (+7 Tage)
- Nur bei Tasks MIT dueDate sichtbar

Shared Postpone-Helper als Extension auf `LocalTask` oder Funktion in `SyncEngine` — wird von Notifications (85-B) UND Kontextmenüs (85-C) wiederverwendet.

**iOS:** 2-3 Views anpassen (NextUpSection, BacklogView; TaskAssignmentView optional)
**macOS:** 1 View anpassen (ContentView)

**Dateien:** 4-5 Dateien + 1 Shared Helper

### Offene PO-Frage

Soll "Verschieben" auch für Tasks OHNE dueDate verfügbar sein (= neues dueDate anlegen)? Empfehlung: Nur für Tasks mit bestehendem dueDate.

---

## Priorisierung (Empfehlung)

| Ticket | Aufwand | Impact | Empfehlung |
|--------|---------|--------|------------|
| **85-A** | Klein (2 Dateien) | Hoch | **Zuerst** — einfachster Fix, sofortiger Mehrwert |
| **85-B** | Mittel (3 Dateien) | Mittel | **Zweites** — Notification UX, Shared Postpone-Helper anlegen |
| **85-C** | Größer (4-5 Dateien) | Mittel | **Drittes** — nutzt Shared Helper aus 85-B |
