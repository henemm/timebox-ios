# Bug-Analyse: Wiederkehrender Task "Klavier spielen" startet nicht mehr

**Datum:** 2026-05-17  
**Betroffene Plattformen:** iOS + macOS

---

## User-Erwartung (User Advocate)

Der User hat "Klavier spielen" einmalig eingerichtet, damit es automatisch startet — täglich, wöchentlich oder nach Muster. Die App hat das früher zuverlässig getan. Jetzt passiert nichts — kein Timer, keine Benachrichtigung, kein Hinweis.

Kern der Frustration: "Es hat früher funktioniert" — d.h. der User hat nichts falsch gemacht. Irgendetwas hat sich verändert, ohne sein Zutun. Das bricht das Vertrauen in die App.

Der User kann nicht unterscheiden ob der Task verschwunden, nur verschoben oder still blockiert ist. Er möchte mindestens einen Hinweis wenn ein Termin nicht gestartet wurde.

---

## Hypothesen (alle Investigatoren)

### Hypothese 1 — `lastSkippedDate` blockiert Reparatur permanent (WAHRSCHEINLICHSTE)

**Mechanismus:**
1. User hat irgendwann eine einzelne Instanz von "Klavier spielen" manuell gelöscht ("nur diesen Eintrag")
2. Dabei wird `template.lastSkippedDate = Date()` gesetzt (`BacklogView.swift:756` / `ContentView.swift:1186`)
3. `lastSkippedDate` wird NUR zurückgesetzt wenn `completeTask()` aufgerufen wird (`SyncEngine.swift:190`)
4. Wenn "Klavier spielen" seitdem nicht mehr abgeschlossen wurde (oder `completedAt == nil`), bleibt `lastSkippedDate` dauerhaft gesetzt
5. `repairOrphanedRecurringSeries()` beim App-Start prüft: `if skippedDate > completedAt { continue }` → Serie wird nie repariert

**Betroffene Datei:** `Sources/Services/RecurrenceService.swift:466-472`  
**Eingeführt durch:** Commit `2fa08923` (Issue #209, April 2026)

### Hypothese 2 — Neue Instanz hat `dueDate` in der Zukunft → unsichtbar

**Mechanismus:** Nach Abschluss wird eine neue Instanz mit `dueDate = nächste Woche` erstellt. `isVisibleInBacklog` gibt `false` zurück wenn `dueDate >= morgen`. Task existiert in der DB, ist aber nicht im Backlog sichtbar.

**Betroffene Datei:** `Sources/Models/LocalTask.swift:86-93`  
**Wahrscheinlichkeit:** Hoch — könnte parallel zu Hypothese 1 zutreffen

### Hypothese 3 — `dueDate` fehlt auf letzter Completion → keine neue Instanz

**Mechanismus:** `createNextInstance()` prüft `guard let baseDate = completedTask.dueDate else { return nil }`. Wenn die letzte Completion kein `dueDate` hatte, wird nie ein Nachfolger erstellt.

**Betroffene Datei:** `Sources/Services/RecurrenceService.swift:84`

### Hypothese 4 — `deduplicateTemplates()` hat falsches Template gespeichert

**Mechanismus:** Die Dedup-Logik wählt das neueste Template als "Survivor". Wenn das ältere Template die korrekten Wochentage hatte und das neuere `weekdays = nil`, liefert `nextWeekdayDate()` nil → keine gültige Instanz.

**Betroffene Datei:** `Sources/Services/RecurrenceService.swift:294`

---

## Wahrscheinlichste Ursache

**Hypothese 1** (`lastSkippedDate`-Falle) ist der primäre Root Cause — sie erklärt als einzige vollständig warum es früher funktioniert hat und jetzt nicht mehr. Der Fix ist eng begrenzt.

Zusätzlich kann **Hypothese 2** (zukünftiges `dueDate`) parallel zutreffen und muss mitbehoben werden.

---

## Blast Radius

- Betrifft **alle** wiederkehrenden Tasks mit demselben `lastSkippedDate`-Zustand — nicht nur "Klavier spielen"
- Plattform: **Beide** (iOS + macOS, da shared Code in `Sources/`)
- Risiko: Kein Datenverlust, kein Datenschaden — aber Serie dauerhaft "eingefroren"
- Weitere betroffene Features: Backlog-Badge, SmartNotifications (stille Ausfälle möglich)

---

## Betroffene Dateien (Schätzung)

- `Sources/Services/RecurrenceService.swift` (Kernfix)
- Möglicherweise `Sources/Services/SyncEngine.swift` (lastSkippedDate-Reset-Logik)
- `Tests/` — neue Unit Tests für `repairOrphanedRecurringSeries()`
