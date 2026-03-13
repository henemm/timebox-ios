# Bug-Analyse: Recurring Tasks noch sichtbar nach Enrichment

## Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check)
- `isVisibleInBacklog` implementiert in Commit 880fc03
- Enrichment-Logik (recurrencePattern + dueDate) ist in Working Changes (uncommitted)
- Vorheriger Fix: macOS ContentView.swift `visibleTasks` Filter hinzugefuegt

### Agent 2 (Datenfluss-Trace)
- iOS: `LocalTaskSource.fetchIncompleteTasks()` → `.filter { $0.isVisibleInBacklog }` → `SyncEngine` → `BacklogView`
- macOS: `@Query` → `visibleTasks` computed property mit `.filter { $0.isVisibleInBacklog }`
- Beide Plattformen nutzen denselben Filter

### Agent 3 (Alle Schreiber)
- `recurrencePattern` wird geschrieben in: LocalTask.init, RemindersImportService (Enrichment + New Import), RecurrenceService
- `dueDate` wird geschrieben in: LocalTask.init, RemindersImportService (Enrichment + New Import), RecurrenceService, BacklogView (date picker)

### Agent 4 (Alle Szenarien)
- 6 Szenarien wo isVisibleInBacklog `true` zurueckgibt fuer recurring Tasks:
  1. recurrencePattern == "none" → sofort true
  2. dueDate == nil → sofort true
  3. dueDate ist heute → true (korrekt)
  4. dueDate ist in der Vergangenheit → true (korrekt: ueberfaellig)
  5. @Query refresh verzoegert nach ModelContext-Aenderung
  6. Verschiedene ModelContexts (Import vs. View)

### Agent 5 (Blast Radius)
- Beide Plattformen (iOS + macOS) nutzen `isVisibleInBacklog`
- watchOS hat KEINEN Filter → dort alle recurring Tasks sichtbar
- RecurrenceService erstellt neue Instanzen nur nach Completion

---

## Konsolen-Beweis (User-Output vom 2026-02-19)

```
Import: 4 reminders to process
  Reminder 'Fahrradkette reinigen' recurrencePattern='weekly'
    State: existing pattern='weekly' dueDate=2026-03-14 isVisible=false    ← KORREKT VERSTECKT
  Reminder 'Zehnagel' recurrencePattern='weekly'
    State: existing pattern='weekly' dueDate=2026-03-01 isVisible=false    ← KORREKT VERSTECKT
  Reminder 'Klavier spielen' recurrencePattern='daily'
    State: existing pattern='daily' dueDate=2026-02-10 isVisible=true      ← UEBERFAELLIG (9 Tage)
  Reminder '1 Blink lesen' recurrencePattern='daily'
    State: existing pattern='daily' dueDate=2026-02-10 isVisible=true      ← UEBERFAELLIG (9 Tage)
Import done: 0 imported, 4 skipped, 0 enriched
```

---

## Hypothesen

### Hypothese A: Filter FUNKTIONIERT — User sieht ueberfaellige Tasks (HOCH)

**Beschreibung:** Die 2 weekly Tasks (Fahrradkette, Zehnagel) sind BEREITS versteckt (`isVisible=false`). Die 2 daily Tasks (Klavier spielen, 1 Blink lesen) bleiben sichtbar weil sie ueberfaellig sind (dueDate=10.Feb, heute=19.Feb). User sieht noch 2 recurring Tasks und nimmt "keine Verbesserung" wahr.

**Beweis DAFUER:**
- Logging beweist: `isVisible=false` fuer Fahrradkette + Zehnagel
- `isVisibleInBacklog` Logik ist korrekt: dueDate < startOfTomorrow → true fuer ueberfaellige
- macOS `visibleTasks` Filter bei ContentView:77 nutzt `isVisibleInBacklog`

**Beweis DAGEGEN:**
- User sagt explizit "keine Veraenderung" — moeglicherweise sind ALLE 4 noch sichtbar

**Wahrscheinlichkeit: HOCH**

### Hypothese B: @Query refresht nicht nach Enrichment-Aenderungen (MITTEL)

**Beschreibung:** SwiftData `@Query` hat die Aenderungen an `recurrencePattern` und `dueDate` nicht aufgenommen. Die View zeigt veraltete Daten — alle 4 Tasks bleiben sichtbar obwohl 2 jetzt `isVisible=false` haben.

**Beweis DAFUER:**
- Enrichment passierte in einer vorherigen Session (0 enriched diesmal)
- `@Query` koennte gecachte Ergebnisse liefern
- Computed properties (`isVisibleInBacklog`) werden nicht von SwiftData getrackt

**Beweis DAGEGEN:**
- `@Query` trackt STORED property Aenderungen (recurrencePattern, dueDate)
- Nach `modelContext.save()` sollte @Query refreshen
- Die Enrichment-Aenderungen wurden in einer frueheren Session GESPEICHERT

**Wahrscheinlichkeit: MITTEL**

### Hypothese C: Verschiedene ModelContexts zeigen verschiedene Daten (NIEDRIG)

**Beschreibung:** Der Import-Service arbeitet mit einem anderen ModelContext als die View. Die Logging-Daten stammen aus dem Import-Context, aber die View sieht andere Werte.

**Beweis DAFUER:**
- Theoretisch moeglich bei SwiftData mit mehreren Contexts

**Beweis DAGEGEN:**
- macOS nutzt typischerweise einen einzigen ModelContext
- Die Daten sind PERSISTENT gespeichert — beide Contexts lesen dieselbe Datenbank
- Enrichment passierte in einer frueheren Session, also ist die Datenbank laengst aktualisiert

**Wahrscheinlichkeit: NIEDRIG**

---

## Wahrscheinlichste Ursache

**Hypothese A** ist am wahrscheinlichsten. Der Filter FUNKTIONIERT korrekt:
- Fahrradkette (weekly, dueDate=14.Maerz) → VERSTECKT ✓
- Zehnagel (weekly, dueDate=1.Maerz) → VERSTECKT ✓
- Klavier spielen (daily, dueDate=10.Feb) → SICHTBAR (ueberfaellig seit 9 Tagen) ← Das ist korrekt per Logik
- 1 Blink lesen (daily, dueDate=10.Feb) → SICHTBAR (ueberfaellig seit 9 Tagen) ← Das ist korrekt per Logik

**Das Problem:** Daily Tasks mit altem dueDate (10.Feb) bleiben als "ueberfaellig" sichtbar. Das dueDate kam aus der Apple Reminder, die am 10. Feb faellig war. Fuer daily recurring Tasks sollte das dueDate auf HEUTE vorgerueckt werden, nicht auf dem alten Wert bleiben.

## Vorgeschlagener Fix (wenn Hypothese A bestaetigt)

Bei Import/Enrichment: Wenn eine recurring Task ein dueDate hat das IN DER VERGANGENHEIT liegt, das dueDate auf HEUTE vorruecken. Dann:
- Klavier spielen (daily, dueDate=HEUTE) → sichtbar (korrekt, faellig heute)
- ODER: Klavier spielen (daily, dueDate=MORGEN) → versteckt (naechste Instanz)

**ABER:** Der User muss entscheiden was das gewuenschte Verhalten ist:
1. Ueberfaellige recurring Tasks sichtbar lassen (aktuelle Logik — korrekt per Design)
2. DueDate auf heute vorruecken (Task erscheint als "faellig heute")
3. DueDate auf naechste Instanz vorruecken (Task verschwindet bis naechster Faelligkeit)

## Debugging-Plan

**Um Hypothese A zu BESTAETIGEN:**
- User fragen: "Siehst du noch ALLE 4 Tasks (Fahrradkette, Zehnagel, Klavier spielen, 1 Blink lesen)? Oder nur noch 2 (Klavier spielen, 1 Blink lesen)?"
- Wenn nur noch 2: Hypothese A bestaetigt → Filter funktioniert, Problem sind ueberfaellige daily Tasks
- Wenn noch 4: Hypothese B bestaetigt → @Query refresh Problem

**Um Hypothese B zu WIDERLEGEN:**
- App beenden + neu starten → @Query liest frisch aus der DB
- Wenn dann 2 Tasks verschwinden: Es war ein Refresh-Problem

## Blast Radius

- watchOS: Kein `isVisibleInBacklog` Filter — dort alle recurring Tasks sichtbar (bekannt)
- RecurrenceService: Erstellt neue Instanzen nur nach Completion — ueberfaellige Tasks bleiben stecken
- Wenn Fix "dueDate vorruecken": Muss in RemindersImportService UND ggf. RecurrenceService angepasst werden
