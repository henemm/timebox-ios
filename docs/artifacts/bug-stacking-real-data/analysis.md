# Bug-Analyse: Stacking-Bar erscheint nicht bei echten Daten

**Issue:** #279 (5. Anlauf), Vorgänger-Commits: 2767a92, d17c4bf, 62e4dd0, 5604f09, 56dc58c, 2db62b7
**Datum:** 2026-05-02

## User-Erwartung (User Advocate)

> "Ich habe Aufgaben die sich wiederholen — 'jeden Montag Sport', 'täglich Journal'. Wenn ich die vergesse, stapeln sie sich. Ich wollte sehen: 'Hey, das hier hast du schon 3 Mal verpasst' — als deutlichen roten Hinweis direkt an der Aufgabe."
>
> "Der Fix muss mit meinen Bestandsdaten funktionieren — automatisch, ohne dass ich irgendetwas manuell nachpflegen muss."

**Vertrauenslage:** 5. Anlauf. Henning fragt sich: "Testet Claude eigentlich mit echten Daten? Oder nur mit selbst gebauten Beispielen?"

---

## Root Cause (Konsens aller 5 Investigatoren)

Das Stacking-Feature beruht auf EINEM Gruppierungs-Schlüssel: `recurrenceGroupID` (`Sources/Models/LocalTask.swift:69`, optional `String?`, kein Default).

`RecurringStackingHelper.apply()` (`Sources/Services/RecurringStackingHelper.swift:25-28`):
```swift
guard let groupID = item.recurrenceGroupID,
      !item.isTemplate,
      !item.isCompleted,
      !item.isNextUp else { continue }
```

→ Wenn `recurrenceGroupID == nil`, wird die Task **stillschweigend übersprungen**. Kein Stacking, keine rote Bar.

### Warum Mocks funktionieren, echte Daten aber nicht

| Quelle | recurrenceGroupID? | Beleg |
|--------|---------------------|-------|
| Mock-Seed iOS | **JA, hardcodiert** | `Sources/FocusBloxApp.swift:957, 970, 983, 997` |
| Mock-Seed macOS | **JA, hardcodiert** | `FocusBloxMac/FocusBloxMacApp.swift:766-784` |
| Manuelles Anlegen via Form | **NEIN** | `Sources/Services/TaskSources/LocalTaskSource.swift:116-135` — `createTask()` akzeptiert `recurrencePattern` aber kein groupID-Parameter; `LocalTask.init()` (Z.269) lässt es `nil` |
| Reminders-Import | **NEIN** | `Sources/Services/RemindersImportService.swift:83-92` — kopiert `recurrencePattern`, NIE `recurrenceGroupID`. `PlanItem.init(reminder:)` (Z.195-200) setzt explizit nil |
| CreateTaskIntent / QuickCapture | **NEIN** | `Sources/Intents/CreateTaskIntent.swift:21`, `QuickCaptureSubIntents.swift:116` |
| FocusBlockActionService (copy/followUp) | **NEIN** | `Sources/Services/FocusBlockActionService.swift:225, 274` |
| TaskSplitService | **NEIN** | `Sources/Services/TaskSplitService.swift:130` |
| Bestandsdaten vor Feb 2026 | **NEIN** | Feld erst seit Commit 2c4f92b vorhanden, **keine SwiftData-Migration** existiert |
| RecurrenceService.createNextInstance | JA (lazy) | `Sources/Services/RecurrenceService.swift:94-100` — aber NUR auf der gerade abgeschlossenen + neuen Instanz, nicht rückwirkend auf bestehende Geschwister |
| RecurrenceService.migrateToTemplateModel | JA (App-Start) | `Sources/Services/RecurrenceService.swift:200-207` — läuft nur einmal beim Start, weist GroupID nur 1 Repräsentant zu, nicht allen offenen Geschwistern mit gleichem Titel/Pattern |

**Kurz:** Echte Daten haben `recurrenceGroupID == nil` aus mindestens 7 verschiedenen Pfaden. Mocks haben es immer.

---

## Zweites, separates Problem (Investigator 4)

Selbst wenn `recurrenceGroupID` korrekt gesetzt wäre, gibt es bei realen User-Daten oft gar keine ≥2 offenen Instanzen — denn:

- `RecurrenceService` erzeugt eine neue Instanz **nur bei Completion** (`createNextInstance` läuft beim Abschließen)
- `repairOrphanedRecurringSeries` (`Sources/Services/RecurrenceService.swift:426-493`) prüft nur Tasks mit `isCompleted == true`
- → Eine täglich-wiederkehrende Aufgabe, die der User 5 Tage **ignoriert** (nicht abschließt), bleibt **eine einzige Task** mit altem `dueDate`. Keine Geschwister entstehen.

**Konsequenz:** Hennings User-Erwartung "wenn ich vergesse, stapelt sich" matcht nicht das Engine-Verhalten "stacking erst nach mehreren Completions". Das ist eine UX-Entscheidung, die Henning treffen muss.

---

## Spannung zwischen Investigatoren

| Position | Vertreter | Aussage |
|----------|-----------|---------|
| A | Inv. 1, 2, 3 | "groupID ist das Problem — Backfill setzen, dann läuft Stacking" |
| B | Inv. 4 | "Auch mit groupID gibt es bei ignorierten Tasks gar keine ≥2 Instanzen" |

**Auflösung:** Beide Diagnosen sind wahr. Es sind zwei sich überlagernde Probleme:
1. **Datenqualitäts-Problem** (groupID nil) — verhindert Stacking selbst wenn Geschwister da wären
2. **Engine-Verhaltens-Problem** — Geschwister entstehen nur durch Completion, nicht durch Ignorieren

---

## Blast Radius (Investigator 5)

Andere Features die ebenfalls "nur mit Mocks" funktionieren oder fehlerhaft sind:

- **Tab-Badge-Counter** (`Sources/Services/BacklogBadgeService.swift:29`) zählt JEDE Instanz einzeln statt gestapelt → potentiell falsche Tab-Zahl
- **macOS** hat separaten `MacBacklogStackingHelper` (`FocusBloxMac/MacBacklogHelpers.swift:41-75`) mit identischer kaputter Logik → Code-Duplikation
- **SmartNotificationEngine** (`Sources/Services/SmartNotificationEngine.swift:161,261,400,513`) feuert für jede Einzel-Instanz → potentieller Notification-Spam bei aufgelaufenen Serien
- **Stille Fehlerpfade** in `RecurrenceService.swift` (Z.111, 151, 169, 249, 298, 330, 345, 412, 431, 440, 491) — `try?` verschluckt DB-Fehler

---

## Test-Lücke (Warum sind alle Tests grün, aber das Feature kaputt?)

Alle existierenden Tests sind **Silent-Pass für reale Daten**:

- `BacklogStackingUITests.swift` (6/6 GREEN) — verwendet `-UITesting`-Flag, der Mock-Seed mit hardcoded groupIDs lädt
- `RecurringStackingTests.swift` (13/13 GREEN) — `makePlanItem(id:groupID:)` setzt groupID immer explizit
- **Kein Test** verifiziert, dass eine via `LocalTaskSource.createTask` erzeugte Task tatsächlich eine groupID bekommt
- **Kein Test** mit echten Datenpfaden (Reminders-Import, Bestandsdaten ohne groupID)

Das ist genau das, was Henning meint: "Testet Claude mit echten Daten? Oder nur mit Mocks?"

---

## Empfohlener Fix (Vorschlag — Henning entscheidet)

### Stufe 1 (Datenqualität, PFLICHT)

1. **Backfill-Migration beim App-Start**: In `RecurrenceService` eine Funktion, die für JEDE offene Task mit `recurrencePattern != "none"` aber `recurrenceGroupID == nil` eine groupID zuweist — Heuristik: gruppiere alle solchen Tasks mit gleichem `(title, recurrencePattern)` zur selben groupID. Läuft 1× pro App-Start, idempotent.

2. **`LocalTaskSource.createTask` setzt groupID sofort**: Wenn `recurrencePattern != nil`, wird sofort eine UUID als `recurrenceGroupID` generiert.

3. **`RemindersImportService` setzt groupID**: Beim Import einer Recurring-Task analog zu (2).

4. **macOS analog**: `MacBacklogStackingHelper` per Möglichkeit gegen `RecurringStackingHelper` ersetzen (Code-Sharing) — sofern Cross-Platform-Code es erlaubt.

### Stufe 2 (UX-Verhalten — Hennings Wahl)

Was passiert mit einer ignorierten täglichen Aufgabe nach 5 Tagen?

- **Variante A: Auflauf-Erzeugung** — Engine erzeugt rückwirkend Instanzen für alle verpassten Tage, sodass es 5 offene Tasks gibt → Stacking greift normal
- **Variante B: Single-Task mit Counter-Bar** — Statt mehrere DB-Einträge zeigt die EINE überfällige Task die rote Bar mit "5 Tage überfällig" basierend auf `recurrencePattern + dueDate`

→ Diese Entscheidung kommt in den Checkpoint mit Henning.

---

## Affected Files (vorläufig — finalisiert nach UX-Entscheidung)

**Stufe 1 sicher:**
- `Sources/Services/RecurrenceService.swift` (Backfill-Migration erweitern)
- `Sources/Services/TaskSources/LocalTaskSource.swift` (createTask)
- `Sources/Services/RemindersImportService.swift` (Import)
- `Sources/Services/RecurringStackingHelper.swift` (ggf. unverändert)
- Tests: `FocusBloxTests/RecurringStackingTests.swift` + neue Tests die `LocalTaskSource.createTask`-Pfad prüfen

**Stufe 2 abhängig:** ggf. `Sources/Services/RecurrenceService.swift` (repairOrphaned erweitern) ODER `Sources/Views/BacklogRow.swift` + `TaskBadges.swift` (Single-Task-Counter-Bar)
