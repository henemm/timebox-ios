# Bug: Recurring Task "Zehnagel" erscheint nach Loeschen immer wieder

## Symptom
User loescht "Zehnagel" wiederholt, Task taucht bei naechstem App-Start wieder auf.

## Agenten-Ergebnisse (5 parallele Investigationen)

### 1. Wiederholungs-Check
- Commit 0fd420d hat Mock-Daten-Leak gefixt (UI Test Tasks ohne `-UITesting` Flag)
- "Zehnagel" war NICHT Teil dieses Leaks — ist ein echter User-Task
- TemplateDedupTests dokumentiert: "Zehnagel hatte 4 Templates mit verschiedenen GroupIDs"

### 2. Datenfluss-Trace
- Alle Unit Tests nutzen `isStoredInMemoryOnly: true` — kein Leak moeglich
- "Zehnagel" in Tests ist nur Test-Fixture, nicht Leak-Quelle

### 3. Alle Schreiber (Resurrections-Pfade)
- **Pfad A:** `repairOrphanedRecurringSeries()` (RecurrenceService.swift:380-423)
- **Pfad B:** Apple Reminders Re-Import (RemindersImportService.swift:30-81)
- **Pfad C:** `migrateToTemplateModel()` (RecurrenceService.swift:160-240)

### 4. Szenarien
- Hauptszenario: User loescht → App-Neustart → Repair erstellt neu → Endlosschleife

### 5. Blast Radius
- Betrifft ALLE wiederkehrenden Tasks, nicht nur "Zehnagel"
- Jeder recurring Task der geloescht wird, kann durch Repair wiederkommen

---

## Hypothesen

### Hypothese 1: `repairOrphanedRecurringSeries()` (HOCH)

**Mechanismus:**
1. User hat completed "Zehnagel" Tasks in der DB (von frueheren Erledigungen)
2. User loescht die offene Instanz
3. App-Neustart → `repairOrphanedRecurringSeries()` laeuft (FocusBloxApp.swift:272)
4. Findet completed "Zehnagel" OHNE offenen Nachfolger
5. Erstellt automatisch neue Instanz via `createNextInstance()`
6. "Zehnagel" ist zurueck

**Beweis DAFUER:**
- Code in RecurrenceService.swift:380-423 macht genau das
- Laeuft bei JEDEM App-Start
- Prueft nur ob offene Instanz existiert, nicht ob User bewusst geloescht hat

**Beweis DAGEGEN:**
- Dedup laeuft danach und koennte Duplikate bereinigen (aber erstellt keine neuen)

**Wahrscheinlichkeit: HOCH**

### Hypothese 2: Apple Reminders Re-Import (MITTEL)

**Mechanismus:**
1. "Zehnagel" existiert als recurring Reminder in Apple Reminders
2. Import markiert Reminder als complete → Apple erstellt naechste Instanz
3. User loescht in FocusBlox
4. Naechster Import: Findet keinen "Zehnagel" mehr (geloescht) → importiert neu

**Beweis DAFUER:**
- Import prueft nur Titel-Match gegen incomplete Tasks (Zeile 52-66)
- Kein `externalID` Tracking — geloeschte Tasks werden nicht gemerkt
- Kein Blacklist-Mechanismus

**Beweis DAGEGEN:**
- Nur relevant wenn User aktiv importiert (nicht automatisch)
- Nur wenn "Zehnagel" noch in Apple Reminders existiert

**Wahrscheinlichkeit: MITTEL** (abhaengig ob Henning noch importiert)

### Hypothese 3: CloudKit Sync bringt Template zurueck (NIEDRIG)

**Mechanismus:**
- Geloeschtes Template wird von anderem Device zurueck-gesynct
- Migration erstellt neues Template

**Wahrscheinlichkeit: NIEDRIG** (nur bei Multi-Device mit Sync-Lag)

---

## Wahrscheinlichste Ursache

**Hypothese 1: `repairOrphanedRecurringSeries()`**

Das fundamentale Problem: Es gibt keinen Weg eine recurring Serie PERMANENT zu stoppen.
- "Alle offenen loeschen" → loescht Template + offene Instanzen
- Completed Tasks bleiben ERHALTEN
- `repairOrphanedRecurringSeries()` nutzt completed Tasks als Quelle
- Erstellt neue Instanz → Zombie-Schleife

**Fehlende Funktionalitaet:** Ein `seriesCancelled` Flag das verhindert, dass Repair neue Instanzen erstellt.

---

## Debugging-Plan

Um Hypothese 1 zu bestaetigen:
- Logging in `repairOrphanedRecurringSeries()`: "Repairing series [groupID] from completed task [title]"
- App starten nach Loeschen von "Zehnagel"
- Wenn Log "Repairing series... Zehnagel" zeigt → Hypothese bestaetigt

Um Hypothese 1 zu widerlegen:
- Wenn kein Repair-Log fuer Zehnagel → andere Ursache (Import oder CloudKit)

---

## Blast Radius
- ALLE recurring Tasks betroffen (nicht nur Zehnagel)
- Jeder User der eine recurring Serie beenden will, hat das gleiche Problem
- Betrifft iOS UND macOS (beide rufen `repairOrphanedRecurringSeries()` auf)

## Fix-Ansatz (Vorschlag)

`repairOrphanedRecurringSeries()` muss pruefen ob die Serie **bewusst beendet** wurde:
- Option A: `seriesCancelled: Bool` Flag auf completed Tasks setzen wenn User Serie loescht
- Option B: Repair nur fuer Serien die ein Template haben (kein Template = Serie beendet)
- Option B ist einfacher und erfordert kein neues Feld

Repair-Logik aendern: "Wenn kein Template fuer diese GroupID existiert → Serie wurde beendet → NICHT reparieren"
