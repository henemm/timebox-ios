# Bug-Analyse: Recurring Tasks erscheinen 3x statt gestapelt

## Symptom

3 identische "Fahrradkette reinigen" Instanzen im Backlog, alle mit Datum 22.03.26.
Zwei haben Priority 60, eine Priority 51.
Sind kuerzlich und gleichzeitig erschienen — waren vorher nicht da.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- Lange History von Recurring-Bugs: Zombie-Tasks, Template-Duplikate, Orphaned Series
- BUG_108 (Zehnagel-Zombie) war der letzte grosse Fix (Commit `0738f35`, 17.03.2026)
- 2 Massnahmen: (1) completed Tasks neutralisieren bei Serie-Ende, (2) Startup-Reihenfolge korrigiert
- `deduplicateTemplates()` existiert seit Feb 2026 — Bug trat DANACH auf

### Agent 2: Datenfluss-Trace
- 3 Pfade erzeugen neue Instanzen:
  - `createNextInstance()` bei Completion (FocusBlockActionService:77, SyncEngine:184, TaskInspector:224)
  - `repairOrphanedRecurringSeries()` beim App-Start (FocusBloxApp:307)
  - `migrateToTemplateModel()` erzeugt Templates (FocusBloxApp:305)
- Startup-Reihenfolge: migrate -> dedup -> repair (korrekt seit BUG_108)

### Agent 3: Alle Schreiber
- `recurrenceGroupID` wird an 2 Stellen NEU generiert (UUID):
  - RecurrenceService.swift:98 (Lazy Migration bei Completion)
  - RecurrenceService.swift:201 (Template Migration bei App-Start)
- Dedup reassigned Kinder, aber NUR fuer bekannte Template-GroupIDs

### Agent 4: Szenarien
- Hauptverdacht: Repair erzeugt Instanzen fuer completed Tasks mit VERSCHIEDENEN GroupIDs
- Fallback `task.recurrenceGroupID ?? task.id` (Zeile 410) erzeugt einzigartige IDs
- ABER: Guard auf Zeile 418 (`findTemplate(groupID:)`) sollte das verhindern

### Agent 5: Blast Radius
- `deduplicateTemplates()` konsolidiert Templates nach Titel und reassigned Kinder
- LUECKE: Kinder-Dedup nach Datum fehlt — reassigned Kinder mit gleichem Datum bleiben als separate Instanzen
- Alle recurring Serien potenziell betroffen

---

## Hypothesen

### H1: deduplicateTemplates() reassigned Kinder ohne Datum-Dedup (HOCH)

**Beschreibung:** Historisch hatten "Fahrradkette reinigen" Tasks VERSCHIEDENE GroupIDs (aus Lazy Migration oder Template Migration). Jede GroupID-Linie erzeugte eigene Instanzen fuer denselben Zeitraum. `deduplicateTemplates()` konsolidierte die Templates und reassigned ALLE Kinder zur Survivor-GroupID — aber loeschte die Datum-Duplikate nicht.

**Beweis DAFUER:**
- `deduplicateTemplates()` Zeile 321-336: Reassigned Kinder, keine Datum-Pruefung
- Code-Kommentar Zeile 289: "Historical bug: 3 independent code paths generated different GroupIDs"
- 3 Instanzen mit gleichem Datum = klassisches Symptom von GroupID-Fragmentierung + Reassignment ohne Dedup

**Beweis DAGEGEN:**
- User sagt: "waren noch nicht vorhanden als deduplicateTemplates() implementiert wurde"
- Wenn die Kinder erst NACH dem Dedup-Code entstanden, kann Dedup nicht die Ursache sein

**Wahrscheinlichkeit:** MITTEL-HOCH (trotz Timing-Einwand — Dedup laeuft bei JEDEM App-Start, nicht nur einmal)

### H2: repairOrphanedRecurringSeries() erzeugt Duplikate bei Multi-Device Sync (HOCH)

**Beschreibung:** CloudKit synced completed Tasks von einem anderen Geraet. Diese haben entweder keine GroupID oder eine andere als auf dem Hauptgeraet. Repair sieht "keine offene Instanz fuer diese GroupID" und erzeugt neue.

**Beweis DAFUER:**
- Repair prueft `openGroupIDs` nur fuer EXAKTE GroupID-Matches (Zeile 414)
- CloudKit-Sync kann completed Tasks mit abweichender GroupID einbringen
- "Gleichzeitig erschienen" passt zu: Sync-Event bringt Daten, naechster App-Start repariert

**Beweis DAGEGEN:**
- Repair Guard: `findTemplate(groupID:)` muss Template mit dieser GroupID finden (Zeile 418)
- Wenn CloudKit eine fremde GroupID bringt, gibt es kein Template dafuer → Repair STOPPT
- Es sei denn, `migrateToTemplateModel()` erstellt vorher ein Template dafuer

**Wahrscheinlichkeit:** MITTEL

### H3: migrateToTemplateModel() + Repair Zusammenspiel erzeugt Duplikate (HOCH)

**Beschreibung:** Folgendes Szenario beim App-Start:
1. `migrateToTemplateModel()` findet completed recurring Tasks OHNE GroupID
2. Weist ihnen NEUE GroupIDs zu und erstellt Templates
3. `deduplicateTemplates()` konsolidiert Templates nach Titel → 1 Survivor
4. Reassigned Kinder — aber die completed Tasks haben jetzt die Survivor-GroupID
5. `repairOrphanedRecurringSeries()` findet diese completed Tasks
6. Fuer JEDE davon: GroupID = Survivor → Template existiert → ABER `openGroupIDs` enthaelt Survivor (weil offene Instanz existiert) → SKIP

WARTE — das wuerde eigentlich KORREKT funktionieren. Repair wuerde KEINE Duplikate erzeugen, weil `openGroupIDs` den Survivor enthaelt.

AUSSER: die offene Instanz hat KEINE GroupID (nil) → `openGroupIDs` enthaelt den Survivor NICHT → Repair erzeugt neue Instanz.

**Beweis DAFUER:**
- Zeile 396-399: `openGroupIDs` sammelt nur Tasks mit `.recurrenceGroupID != nil`
- Wenn die offene "Fahrradkette"-Instanz KEINE GroupID hat → invisible fuer Repair
- Template Migration (Zeile 200-206) weist GroupIDs nur fuer Tasks `tasksWithoutGroupID` zu — aber diese sind in einer separaten Schleife von `groupedByID`
- RACE: Migration koennte die offene Instanz in `tasksWithoutGroupID` packen UND ihr GroupID zuweisen, aber Repair hat `openGroupIDs` VORHER gecached

**Beweis DAGEGEN:**
- Migration laeuft VOR Repair (Zeile 305 vor 307)
- Migration weist der offenen Instanz eine GroupID zu → diese sollte in Repair sichtbar sein
- ABER: Migration assigned GroupID "X", Dedup aendert zu GroupID "Y" (Survivor) → Repair sucht nach "Y" in openGroupIDs

**Wahrscheinlichkeit:** HOCH — das ist der wahrscheinlichste Pfad

### H4: Doppelte Completion (FocusBlock + SyncEngine gleichzeitig) (NIEDRIG)

**Beschreibung:** Task wird sowohl ueber FocusBlockActionService ALS AUCH SyncEngine erledigt. Beide rufen `createNextInstance()` auf.

**Beweis DAGEGEN:**
- Dedup in `createNextInstance()` (Zeile 103-117) prueft per Datum — sollte zweiten Call blocken
- Sehr unwahrscheinlich dass beide Code-Pfade fuer denselben Task feuern

**Wahrscheinlichkeit:** NIEDRIG

---

## Wahrscheinlichste Ursache: H1 + H3 Kombination

**Das Timing-Puzzle:** User sagt "erst kuerzlich erschienen, waren vorher nicht da."

Erklaerung: Die 3 Instanzen existierten moeglicherweise IMMER in der Datenbank (erzeugt durch historische GroupID-Fragmentierung), waren aber durch den `isVisibleInBacklog` Filter NICHT SICHTBAR (zukuenftige Instanzen werden ausgeblendet). Als ihr dueDate (22.03.26) erreicht wurde, wurden sie ploetzlich sichtbar.

ALTERNATIVE: Ein kuerzlicher App-Start triggerte `deduplicateTemplates()`, das die Kinder reassigned hat. Durch das Reassignment aenderte sich der Sichtbarkeits-Status — vorher hatten sie eine GroupID ohne Template (unsichtbar?), jetzt haben sie die Survivor-GroupID mit Template (sichtbar).

---

## Wie beweise ich die Hypothese?

### Logging-Plan:
1. In `deduplicateTemplates()` nach dem Reassignment: Log ALLE offenen Kinder mit gleichem Datum pro GroupID
   - **Bestaetigung:** "3 offene Kinder mit dueDate=22.03.26 nach Reassignment" → H1 bestaetigt
   - **Widerlegung:** "Nur 1 Kind pro Datum" → H1 widerlegt, H2/H3 pruefen

2. In `repairOrphanedRecurringSeries()`: Log JEDE Instanz-Erzeugung mit groupID + dueDate
   - **Bestaetigung:** "Erzeuge Instanz fuer groupID=X, dueDate=22.03.26 — bereits 2 offene" → H3 bestaetigt
   - **Widerlegung:** "Repair erzeugt 0 Instanzen" → Repair ist nicht die Ursache

3. Direkte Datenbankabfrage: Wie viele offene Instanzen von "Fahrradkette reinigen" existieren?
   - Haben sie GLEICHE oder VERSCHIEDENE recurrenceGroupIDs?

---

## Blast Radius

- **Alle recurring Serien** mit historischen GroupID-Fragmenten potenziell betroffen
- Besonders Serien die VOR dem Template-Modell existierten
- CloudKit-Sync zwischen Geraeten kann das Problem verstaerken
- RW_3.5 (Recurring Stacking) wuerde das Problem visuell kaschieren, aber nicht die Daten-Duplikate loesen

## Fehlende Schutzschicht

Es gibt KEINE Dedup fuer KINDER-Instanzen mit gleichem Datum nach GroupID-Konsolidierung.
`deduplicateTemplates()` reassigned Kinder, aber loescht Datum-Duplikate nicht.
Dies ist die strukturelle Luecke.
