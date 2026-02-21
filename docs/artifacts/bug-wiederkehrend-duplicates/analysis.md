# Bug-Analyse: Wiederkehrend-View zeigt 18 Duplikate statt ~5-6 Serien

**Plattform:** iOS + macOS (BEIDE betroffen)
**Screen:** Wiederkehrend-View
**Symptome:**
1. 18 Template-Eintraege statt ~5-6 einzigartige Serien
2. Next-Up-Sektion sichtbar in Wiederkehrend (gehoert da nicht hin)

---

## Agenten-Ergebnisse

### Agent 1 (History): 6 Commits zu Recurring, GroupID-Generierung an 3 Stellen
### Agent 2 (Datenfluss): Beide Plattformen filtern `isTemplate && !isCompleted` — korrekt, aber zeigt ALLE Templates
### Agent 3 (Schreiber): 3 Orte wo NEUE GroupIDs generiert werden + Import setzt keine GroupID
### Agent 4 (Szenarien): 5 Szenarien fuer Duplikat-GroupIDs identifiziert
### Agent 5 (Blast Radius): Fix 1 (Next-Up) = sicher. Fix 2 (Dedup) = 6 kritische Flows betroffen

---

## Problem 1: Next-Up in Wiederkehrend

### Ursache (SICHER — Code-Beweis)
`nextUpTasks` filtert nicht nach `!isTemplate`:
- **macOS** ContentView.swift:243-245: `tasks.filter { $0.isNextUp && !$0.isCompleted && matchesSearch($0) }`
- **iOS** BacklogView.swift:82-84: `planItems.filter { $0.isNextUp && !$0.isCompleted && matchesSearch($0) }`

Ausserdem: `showNextUpSection` (macOS:289) schliesst `.recurring` nicht aus.

### Fix
1 Zeile pro Plattform: `&& !$0.isTemplate` in nextUpTasks hinzufuegen
Plus: `showNextUpSection` um `selectedFilter != .recurring` erweitern (macOS)

### Blast Radius: KEINER — sicherer Fix

---

## Problem 2: 18 Templates statt ~5-6

### Ursache (SICHER — 3 Quellen bestaetigen)

Die gleiche logische Serie (z.B. "Zehnagel") hat MEHRERE verschiedene `recurrenceGroupID` Werte:

**Wie das passiert ist (chronologisch):**
1. Tasks wurden VOR Phase 1B erstellt (recurrenceGroupID = nil)
2. Lazy Migration bei Completion (RecurrenceService:98) → NEUE UUID pro Completion
3. Repair (RecurrenceService:297) → nutzt `task.id` als Fallback (ANDERE ID!)
4. Template-Migration (RecurrenceService:201) → NOCHMAL neue UUID fuer Tasks ohne GroupID
5. Ergebnis: "Zehnagel" hat 3 GroupIDs, je mit eigenem Template → 3 Eintraege

**Stellen die neue GroupIDs generieren:**

| Stelle | Datei:Zeile | Trigger |
|--------|-------------|---------|
| Lazy Migration | RecurrenceService:98 | Completion mit GroupID=nil |
| Repair Fallback | RecurrenceService:297 | `task.recurrenceGroupID ?? task.id` |
| Template Migration | RecurrenceService:201 | App-Start fuer Tasks ohne GroupID |

### Hypothesen

**H1: Mehrfache GroupID-Generierung (HOCH)**
- Beweis DAFUER: 3 unabhaengige Stellen generieren UUIDs, Hennings Log zeigt 18 GroupIDs
- Beweis DAGEGEN: Keiner

**H2: Import erzeugt Duplikate (MITTEL)**
- Beweis DAFUER: RemindersImportService setzt recurrenceGroupID NICHT
- Beweis DAGEGEN: Henning importiert nicht regelmaessig

**H3: CloudKit Sync-Konflikt (NIEDRIG)**
- Beweis DAFUER: Keine Konflikterkennung fuer GroupID
- Beweis DAGEGEN: Henning nutzt primaer ein Device

### Fix-Ansatz: Template-Deduplikation beim App-Start

Neue Funktion `deduplicateTemplates()` in RecurrenceService:
1. Alle Templates gruppieren nach `title + recurrencePattern`
2. Pro Gruppe: Aeltestes Template behalten (survivor)
3. Alle Children der Duplikat-Templates auf survivor.recurrenceGroupID umschreiben
4. Duplikat-Templates loeschen

### Blast Radius bei Dedup
6 Flows nutzen recurrenceGroupID:
1. `findTemplate()` — OK wenn Children migriert
2. `createNextInstance()` — OK mit neuem groupID
3. `deleteRecurringTemplate()` — OK wenn Children migriert
4. `updateRecurringSeries()` — OK wenn Children migriert
5. `deleteRecurringSeries()` (macOS) — OK wenn Children migriert
6. `repairOrphanedRecurringSeries()` — OK wenn open groupIDs korrekt

**KRITISCH:** Children MUESSEN auf neue GroupID migriert werden, sonst brechen 5 von 6 Flows!

---

## Debugging-Plan (falls gewuenscht)

Logging in `deduplicateTemplates()`:
- Vor Dedup: Anzahl Templates pro title+pattern
- Nach Dedup: Welche Templates geloescht, welche Children migriert
- Bestaetigung: `[Dedup] Zehnagel: 3 Templates → 1 survivor, 5 children reassigned`
- Widerlegung: Wenn nach Dedup immer noch >1 Template pro Serie → Gruppierung ist falsch

---

## Zusammenfassung

| Problem | Ursache | Fix-Komplexitaet | Dateien |
|---------|---------|-------------------|---------|
| Next-Up in Wiederkehrend | Filter fehlt | 1 Zeile pro Plattform | 2 |
| 18 Duplikate | Historische GroupID-Divergenz | Dedup-Migration beim App-Start | 1-2 |

**Gesamtscope:** ~3 Dateien, ~80-100 LoC (inkl. Tests)
