# Bug 60: Vollstaendige Analyse — Erweiterte Attribute verschwinden (7. Wiederholung)

## Agenten-Ergebnisse Zusammenfassung

5 parallele Explore-Agenten haben unabhaengig voneinander folgendes gefunden:

| Agent | Kern-Ergebnis |
|-------|---------------|
| **Wiederholungs-Check** | 7. Wiederholung (Bug 18, 32, 34, 48, 57, 59, 60). Jeder Fix hat EIN Symptom behandelt. Safe-Setter aus Bug 57 sind DEAD CODE — nie aufgerufen. |
| **Datenfluss-Trace** | createTask() erstellt Tasks mit NUR title/importance/dueDate/notes. urgency, estimatedDuration, taskType, tags fehlen IMMER bei Neuanlage. |
| **Alle Schreiber** | 40+ Schreibstellen fuer erweiterte Attribute. RemindersSyncService:200-201 loescht externalID+sourceSystem PERMANENT. Kein anderer Code tut das. |
| **Alle Szenarien** | 9 Szenarien analysiert. HIGH-Risk: ID-Instabilitaet (Szenario 3+4). Gefilterte IDs in handleDeletedReminders (Szenario 8) ist KORREKT laut Agent 4 — aber FALSCH laut Agent 1+5. |
| **Blast Radius** | SEHR WEIT: 7+ Views betroffen (Eisenhower, Duration, Category, AI, TBD, Backlog, Next Up). Beide Plattformen. CloudKit verstaerkt das Problem. |

### Wo ueberlappen sich die Ergebnisse?

ALLE 5 Agenten identifizieren unabhaengig dieselben 3 Kernprobleme:
1. **externalID wird auf nil gesetzt** (RemindersSyncService.swift:201) — macht Recovery unmoeglich
2. **isCompleted=true blockiert Orphan-Recovery** (Zeile 203 + Predicate Zeile 169)
3. **ID-Instabilitaet** (ReminderData.swift:17-21) — calendarItemExternalIdentifier aendert sich

Agent 4 sieht handleDeletedReminders mit gefilterten IDs als "korrekt" (weil Hidden-List-Tasks aus Backlog verschwinden sollen). Agenten 1 und 5 sehen es als Problem. **Beide haben teilweise recht** — das Design ist korrekt in der ABSICHT, aber falsch in der AUSFUEHRUNG (weil externalID geloescht wird).

---

## Alle moeglichen Ursachen (Hypothesen)

### Hypothese A: handleDeletedReminders mit gefilterten IDs (HOCH)

**Beschreibung:** handleDeletedReminders bekommt nur IDs sichtbarer Listen. Tasks aus versteckten Listen werden faelschlicherweise als "geloescht" behandelt.

**Beweis DAFUER:**
- `RemindersSyncService.swift:65`: `Set(reminders.map(\.id))` — `reminders` ist gefiltert (Zeile 34-37)
- `fetchReminderSourcedTasks()` (Zeile 192) liefert ALLE reminders-Tasks, auch aus versteckten Listen
- Soft-Delete setzt externalID=nil (Zeile 201) — permanenter Verlust der Verbindung

**Beweis DAGEGEN:**
- Henning sagt Tasks waren "die ganze Zeit aktiv/unerledigt" — kein Hinweis auf Listen-Wechsel
- Agent 4 argumentiert: dieses Verhalten ist BEABSICHTIGT (Tasks aus versteckten Listen sollen ausgeblendet werden)

**Wahrscheinlichkeit:** HOCH — aber moeglicherweise nicht der PRIMAERE Trigger fuer Hennings Fall

### Hypothese B: calendarItemExternalIdentifier aendert sich (HOCH)

**Beschreibung:** Die Reminder-ID wechselt zwischen calendarItemIdentifier und calendarItemExternalIdentifier (nach Geraete-Neustart, iCloud-Resync, Account-Aenderung). Der alte Task wird nicht mehr gefunden, ein neuer ohne Attribute erstellt.

**Beweis DAFUER:**
- `ReminderData.swift:17-21`: Fallback-Logik bevorzugt calendarItemExternalIdentifier
- Apple-Dokumentation: calendarItemExternalIdentifier kann sich aendern
- Bug 57 hat das ID-Format GEWECHSELT (calendarItemIdentifier → calendarItemExternalIdentifier)
- Alle Agenten identifizieren dies unabhaengig als HIGH-Risk
- Passt zu Hennings Beschreibung: Tasks waren aktiv, Attribute ploetzlich weg

**Beweis DAGEGEN:**
- Sollte nach Bug 57 Fix B stabiler sein (calendarItemExternalIdentifier IST stabiler)
- Wenn ID sich aendert, muesste man Duplikate im Backlog sehen (Henning hat das nicht erwaehnt)

**Wahrscheinlichkeit:** HOCH — wahrscheinlichster Trigger fuer Hennings Fall

### Hypothese C: isCompleted=true aus Bug 59 blockiert Recovery permanent (HOCH)

**Beschreibung:** Bug 59 Fix fuegt `isCompleted = true` in handleDeletedReminders hinzu (Zeile 203). findOrphanedTask sucht nur `isCompleted == false` (Zeile 169). Sobald ein Task EINMAL durch handleDeletedReminders laeuft, ist Recovery PERMANENT blockiert.

**Beweis DAFUER:**
- Zeile 203: `task.isCompleted = true`
- Zeile 169: Predicate `$0.isCompleted == false`
- Bug 60 trat DIREKT NACH Bug 59 Fix auf
- Henning: "Problem trat nach Bug 59 Fix auf"

**Beweis DAGEGEN:**
- isCompleted=true ist semantisch korrekt fuer erledigte Reminders
- Aber NICHT korrekt fuer ID-Aenderungen oder versteckte Listen

**Wahrscheinlichkeit:** HOCH — verstaerkt Hypothesen A und B fatal

### Hypothese D: CloudKit-Merge ueberschreibt Attribute mit nil (MITTEL)

**Beschreibung:** macOS importiert Reminder (erstellt "duennen" Task ohne Attribute), synct via CloudKit. iOS empfaengt den duennen Task, lokale Attribute werden ueberschrieben.

**Beweis DAFUER:**
- macOS importiert IMMER (kein CloudKit-Check, ContentView.swift:572)
- iOS importiert nur wenn CloudKit NICHT aktiv (BacklogView.swift:402)
- Asymmetrie: macOS schreibt duenne Tasks, CloudKit synct sie
- Bug 57 Fix A (bedingte Writes) schuetzt NUR innerhalb RemindersSyncService, NICHT bei CloudKit-Merge
- Agent 5 bestaetigt: "No merge policy protects extended attributes when they become nil"

**Beweis DAGEGEN:**
- Bedingte Writes (Fix A) verhindern, dass RemindersSyncService Felder als "dirty" markiert
- CloudKit synct nur dirty-Felder, also sollten nil-Attribute nicht gesynct werden
- ABER: createTask() erstellt ein KOMPLETT neues Objekt — ALLE Felder sind "dirty"

**Wahrscheinlichkeit:** MITTEL — moeglich bei Dual-Device-Nutzung

### Hypothese E: Safe-Setter sind Dead Code (NIEDRIG als Ursache, HOCH als Verstaerker)

**Beschreibung:** Bug 57 Fix D erstellte safeSetImportance/safeSetUrgency/safeSetDuration/safeSetTaskType. Diese werden NIRGENDS aufgerufen — weder in RemindersSyncService noch in SyncEngine noch in Views.

**Beweis DAFUER:**
- Agent 1 bestaetigt: "safeSet* appears only in LocalTask.swift definition, zero call sites"
- Agent 3 bestaetigt: alle Schreibzugriffe nutzen direkte Zuweisung, nie Safe-Setter
- 10 Tests fuer Safe-Setter existieren und sind GRUEN — aber Code wird nie aufgerufen

**Beweis DAGEGEN:**
- Nicht die URSACHE des Attributverlusts — eher eine fehlende Schutzschicht
- Bedingte Writes in updateTask() bieten aehnlichen Schutz

**Wahrscheinlichkeit als Ursache:** NIEDRIG — aber als Verstaerker HOCH

---

## Wahrscheinlichste Ursache(n)

### Primaer: Hypothese B + C (ID-Instabilitaet + isCompleted blockiert Recovery)

**Die toedliche Kette:**
1. calendarItemExternalIdentifier aendert sich (Geraete-Neustart, iCloud-Resync)
2. findTask(byExternalID: neueID) → nil (alte ID im Task)
3. findOrphanedTask → nil (Task hat sourceSystem="reminders", Predicate sucht "local")
4. createTask() → NEUER Task ohne Attribute
5. handleDeletedReminders: alte ID nicht in aktuellen IDs → Soft-Delete:
   - sourceSystem = "local", externalID = nil, isCompleted = true
6. Naechster Sync: findOrphanedTask sucht isCompleted=false → nil (wegen isCompleted=true)
7. **PERMANENT: Recovery unmoeglich, Attribute verloren**

### Sekundaer: Hypothese A (gefilterte IDs)

Verstaerkt das Problem bei Listen-Aenderungen, aber moeglicherweise nicht Hennings konkreter Fall.

### Verstaerker: Hypothese D + E (CloudKit-Merge + Dead-Code Safe-Setter)

Tragen zur Fragilität bei, sind aber nicht der primaere Trigger.

---

## Blast Radius

### Betroffene Views/Features
- **Eisenhower Matrix** (4 Quadranten) — importance+urgency nil → TBD-Bereich
- **Duration-Gruppierung** — estimatedDuration nil → keine Dauer angezeigt
- **Kategorie-View** — taskType leer → keine Kategorie
- **AI-Empfehlungen** — aiScore/aiEnergyLevel nil → nicht gerankt
- **TBD-View** — Tasks tauchen hier auf statt im richtigen Bereich
- **Next Up** — fehlende Metadaten bei Planung
- **Backlog-Liste** — keine Importance/Urgency-Indikatoren

### Betroffene Plattformen
- **iOS + macOS** — beide nutzen denselben RemindersSyncService
- **CloudKit verstaerkt** — Attributverlust wird zwischen Geraeten gesynct

### Aehnliche Patterns im Code
- **Keine anderen Sync-Services** haben das gleiche Problem (RemindersSyncService ist der einzige der externalID=nil setzt)
- **Dedup-Logik** in FocusBloxApp.swift (Zeilen 313-363) bricht wenn externalID nil ist
- **calendarItemIdentifier** wird auch fuer Kalender-Events genutzt — gleiche Instabilitaet moeglich (aber dort keine erweiterten Attribute)

---

## Strukturelle Root Causes (NICHT einzelne Bugs)

| # | Strukturelles Problem | Betroffene Bugs |
|---|----------------------|-----------------|
| 1 | **externalID wird auf nil gesetzt** — macht Recovery permanent unmoeglich | 57, 59, 60 |
| 2 | **isCompleted=true blockiert Orphan-Recovery** — Predicate schliesst sie aus | 59, 60 |
| 3 | **Kein Title-Match fuer sourceSystem="reminders"** — nur Orphans (sourceSystem="local") werden per Titel gesucht | 59, 60 |
| 4 | **calendarItemExternalIdentifier ist nicht stabil** — aendert sich bei Restart/Resync | 57, 59, 60 |
| 5 | **createTask() hat keine Attribute** — bei Neuanlage gehen ALLE erweiterten Attribute verloren | 18, 32, 34, 48, 57, 59, 60 |
| 6 | **Safe-Setter sind Dead Code** — 10 Tests gruen, 0 Aufrufe in Produktion | 57, 60 |
| 7 | **Keine Unterscheidung** zwischen "erledigt", "versteckt" und "ID geaendert" in handleDeletedReminders | 59, 60 |
