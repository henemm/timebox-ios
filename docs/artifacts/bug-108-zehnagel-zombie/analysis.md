# BUG_108: Zehnagel-Zombie — Recurring Task ueberlebt Serien-Ende

**Datum:** 2026-03-16
**Plattformen:** iOS + macOS (beide)
**Schwere:** High

## Symptom

User beendet "Zehnagel"-Serie ueber "Serie beenden". Task verschwindet aus UI. Nach App-Neustart taucht Task wieder auf — wiederholt.

---

## 5a. Zusammenfassung der Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- **3 vorherige Fix-Versuche**, alle unvollstaendig:
  - `9eaaa1d` (Feb 21): Repair-Funktion hinzugefuegt — kein Check ob Serie absichtlich beendet
  - `5c4c0c2` (Feb 21): Template-Dedup (18 → 5 Templates) — completed Tasks nicht konsolidiert
  - `b8af930` (Mrz 10): Template-Guard in Repair (`findTemplate` check) — prueft nur EINE GroupID
- **Fazit:** Jeder Fix adressierte ein Symptom, nicht die Architektur-Luecke.

### Agent 2: Datenfluss-Trace
- `recurrenceGroupID` wird an **4 Stellen geschrieben** (Lazy Migration, Template Migration, Dedup-Reassignment, Init)
- **Startup-Reihenfolge:** repair → migration → dedup (DIESE REIHENFOLGE IST KRITISCH)
- Dedup reassigned ALLE Kinder (auch completed) von alten GroupIDs zum Survivor
- `deleteRecurringTemplate()` loescht nur Tasks mit EINER GroupID

### Agent 3: Alle Schreiber
- **3 unabhaengige Pfade** erzeugen neue GroupIDs:
  1. Lazy Migration (RecurrenceService:99) — `UUID()` bei Completion ohne GroupID
  2. Template Migration (RecurrenceService:202) — `UUID()` bei App-Start fuer orphans
  3. Repair Fallback (RecurrenceService:410) — `task.id` als Ersatz-GroupID
- **Dedup (RecurrenceService:332)** reassigned Kinder, loescht alte Templates

### Agent 4: Alle Szenarien
- **9 Szenarien** analysiert, davon:
  - 4 SAFE (Normal End, Fallback-GroupID, Migration nach End, Undo)
  - 4 MEDIUM (Repair nach End + Sync-Delay, Dedup-Ordering, CloudKit-Konflikt, Startup-Order)
  - 1 LOW (Race Conditions — durch @MainActor geschuetzt)

### Agent 5: Blast Radius
- **ALLE recurring tasks betroffen**, nicht nur Zehnagel
- Betroffen: iOS Backlog, macOS Backlog, Coach-Backlog, Coach Intention Fulfillment
- RecurrenceService ist shared zwischen iOS und macOS
- 3 Schutzschichten (isVisibleInBacklog, View-Filter, SyncEngine) — aber Zombie umgeht sie

---

## 5b. ALLE moeglichen Ursachen

### Hypothese 1: Startup-Reihenfolge (repair VOR dedup) — HOCH

**Beschreibung:** Repair laeuft VOR dedup. Wenn noch alte Templates aus historischen Daten existieren (z.B. aus Reminders-Import oder vor Dedup-Fix), findet Repair ein Template und erstellt eine neue Instanz — BEVOR dedup diese alten Templates loeschen kann.

**Beweis DAFUER:**
- FocusBloxApp.swift:283-285: Reihenfolge ist `repair → migration → dedup`
- Repair prueft `findTemplate(groupID:)` (Zeile 418) — wenn altes Template noch existiert, wird repariert
- Dedup laeuft erst DANACH und wuerde das alte Template loeschen
- Ergebnis: Zombie-Instanz mit GroupID des alten Templates

**Beweis DAGEGEN:**
- Nach EINEM Durchlauf von dedup sollte es keine duplizierten Templates mehr geben
- Der Zombie wuerde nur einmal pro Restart auftreten (danach sind Templates konsolidiert)
- Wenn User die Serie DANACH nochmal beendet, sollte der Zombie endgueltig weg sein

**Wahrscheinlichkeit:** HOCH (erklaert "wiederholt" wenn App bei jedem Start alte Templates aus Sync zurueckbekommt)

---

### Hypothese 2: deleteRecurringTemplate neutralisiert completed Tasks nicht — HOCH

**Beschreibung:** `deleteRecurringTemplate(groupID:)` loescht nur `!isCompleted` Tasks. Completed Tasks behalten ihren `recurrenceGroupID` und `recurrencePattern`. Wenn bei einem spaeteren Startup ein Template fuer diese GroupID EXISTIERT (z.B. durch Migration oder Sync), wird Repair es finden und eine Zombie-Instanz erstellen.

**Beweis DAFUER:**
- SyncEngine.swift:207: `predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isCompleted }`
- Completed Tasks ueberleben IMMER das Serie-beenden
- Diese completed Tasks haben noch `recurrencePattern = "weekly"` (oder aehnlich)
- Repair (Zeile 387): `filter { $0.recurrencePattern != "none" }` — findet diese Tasks

**Beweis DAGEGEN:**
- Repair Guard (Zeile 418): `findTemplate(groupID:)` muss Template finden — nach Loeschung: nil → skip
- Wenn kein Template existiert, kann Repair nichts erstellen

**Wahrscheinlichkeit:** HOCH (completed Tasks sind der "Treibstoff" fuer den Zombie — aber nur wenn Template existiert)

---

### Hypothese 3: CloudKit-Sync bringt geloeschtes Template zurueck — MITTEL

**Beschreibung:** User beendet Serie auf Geraet A. Template wird lokal geloescht. Sync ist eventually-consistent — Geraet B hat Template noch. CloudKit-Merge bringt Template zurueck auf Geraet A. Naechster Startup: Repair findet Template, erstellt Zombie.

**Beweis DAFUER:**
- CloudKit ist eventually-consistent
- Deleted Template koennte durch Sync-Konflikt wiederhergestellt werden
- Wuerde "wiederholt" erklaeren (Sync-Zyklus wiederholt sich)

**Beweis DAGEGEN:**
- SwiftData/CloudKit hat delete-wins Semantik bei Konflikten (meistens)
- User muesste auf mehreren Geraeten gleichzeitig arbeiten
- Kein CloudKit-Code im Projekt sichtbar (moeglicherweise rein ueber SwiftData Container)

**Wahrscheinlichkeit:** MITTEL

---

### Hypothese 4: Migration-Zombie-Zyklus (von Devil's Advocate aufgedeckt) — MITTEL-HOCH

**Beschreibung:** Repair erstellt Zombie-Instanz (incomplete, recurring, GroupID X) und SPEICHERT (Zeile 425). Migration laeuft DANACH in derselben Startup-Sequenz, findet die Zombie-Instanz als "recurring task ohne Template" (Zeile 212: `tasks.contains(where: { $0.isTemplate })` → false), und erstellt ein neues Template fuer GroupID X. Naechster Restart: Repair findet Template → erstellt naechsten Zombie → **ENDLOS-ZYKLUS**.

**Beweis DAFUER:**
- Migration (Zeile 167): Sucht `!isCompleted && recurrencePattern != "none"` → findet Zombie-Instanz
- Repair speichert bei Zeile 425: `if repaired > 0 { try? modelContext.save() }`
- Migration laeuft DANACH (FocusBloxApp.swift:284) und sieht die gespeicherte Instanz
- Migration Zeile 210-215: Prueft `tasks.contains(where: { $0.isTemplate })` fuer GroupID X → KEIN Template → erstellt neues!
- Naechster Restart: Repair findet das neue Template → Zyklus wiederholt sich

**Beweis DAGEGEN:**
- Dieser Zyklus setzt voraus, dass im ERSTEN Durchlauf ein Template existierte (fuer Repair Guard Zeile 418)
- Nach b8af930: Wenn kein Template existiert, erstellt Repair nichts → Migration sieht nichts → kein Zyklus
- ABER: Wenn durch alte Daten EINMAL ein Template existiert, startet der Zyklus

**Wahrscheinlichkeit:** MITTEL-HOCH (erklaert "wiederholt" wenn der Zyklus einmal gestartet wurde)

**Konkreter Zyklus:**
1. Startup: Repair findet Template X (alt) → erstellt Zombie → speichert
2. Migration: sieht Zombie ohne Template → erstellt Template fuer X → speichert
3. Dedup: sieht Templates X und D → konsolidiert → Survivor
4. User sieht Zombie, beendet Serie → loescht Survivor-Template + offene Tasks
5. Naechster Startup: Wenn completed Tasks mit GroupID ueberleben, kann der Zyklus erneut starten

---

### Hypothese 5: Offene Frage — Ist BUG_108 nach b8af930 verifiziert? — HOCH

**Beschreibung:** Der Fix b8af930 (Template-Guard in Repair) wurde am 10. Maerz deployed. BUG_108 steht noch als OFFEN in ACTIVE-todos. Moeglicherweise wurde der Bug NACH dem Fix nicht erneut getestet.

**Szenario wenn b8af930 FUNKTIONIERT:**
1. User beendet Serie: Template + offene Tasks geloescht
2. Nur completed Tasks ueberleben (recurrencePattern != "none", GroupID X)
3. App-Neustart: Repair findet completed Task X, `findTemplate(X)` → nil → **SKIP**
4. Migration: keine incomplete recurring Tasks → nichts
5. Kein Zombie. Bug GELOEST.

**Warum der Bug trotzdem offen sein koennte:**
- Bug nie nach b8af930 verifiziert (nur Analyse-Dokument aktualisiert)
- Hennings Device hat Daten-Zustand der den Zyklus aus H4 ausloest
- CloudKit bringt Templates zurueck (H3)

**Wahrscheinlichkeit:** HOCH (muss geklaert werden: Tritt der Bug NACH b8af930 noch auf?)

---

## 5c. Wahrscheinlichste Ursache(n)

**Primaer: H5 — Bug moeglicherweise bereits durch b8af930 geloest.**

Der Fix b8af930 (guard findTemplate) sollte den einfachen Fall abdecken:
- Completed Tasks allein koennen KEINEN Zombie erzeugen (Repair braucht ein Template)
- Wenn kein Template existiert, passiert nichts

**Falls Bug NACH b8af930 noch auftritt: H4 (Migration-Zombie-Zyklus).**

Der Endlos-Zyklus:
1. Completed Tasks (H2) sind der Treibstoff — sie ueberleben IMMER
2. Wenn irgendein Mechanismus ein Template erzeugt (H1: alte Daten, H3: Sync, H4: Migration nach Repair), startet Repair
3. Repair erstellt Zombie → Migration erstellt Template fuer Zombie → naechster Restart: Repair findet Template → Zyklus

**Defensiver Fix:** Auch wenn b8af930 moeglicherweise ausreicht, sollte die Architektur den Zyklus strukturell verhindern:
- Completed Tasks neutralisieren (recurrencePattern = "none" beim Serie-beenden)
- Startup-Reihenfolge aendern (migration → dedup → repair)

**Warum H3 weniger wahrscheinlich:** Schwer zu beweisen, erfordert Multi-Device-Setup

---

## 5d. Debugging-Plan (WIE BEWEISE ICH DAS?)

### Logging zur Bestaetigung von H1+H2:

**In `repairOrphanedRecurringSeries()` (Zeile 409-422):**
```swift
for task in sorted {
    let groupID = task.recurrenceGroupID ?? task.id
    print("[Repair] Checking completed task: \(task.title) groupID=\(groupID) pattern=\(task.recurrencePattern)")
    guard !seenGroupIDs.contains(groupID) else { continue }
    seenGroupIDs.insert(groupID)
    guard !openGroupIDs.contains(groupID) else { continue }

    let template = findTemplate(groupID: groupID, in: modelContext)
    print("[Repair] Template for \(groupID.prefix(8)): \(template != nil ? "FOUND" : "nil")")
    guard template != nil else { continue }

    print("[Repair] ⚠️ CREATING ZOMBIE for: \(task.title) groupID=\(groupID)")
    // ... createNextInstance
}
```

**Erwarteter Output bei H1+H2:**
```
[Repair] Checking completed task: Zehnagel groupID=abc123 pattern=weekly
[Repair] Template for abc123..: FOUND
[Repair] ⚠️ CREATING ZOMBIE for: Zehnagel groupID=abc123
```

**Widerlegung von H1+H2:**
```
[Repair] Checking completed task: Zehnagel groupID=abc123 pattern=weekly
[Repair] Template for abc123..: nil
```
→ Wenn Template nil ist, muss die Ursache woanders liegen (z.B. H3 CloudKit oder ein View-Refresh-Problem).

**Beide Plattformen pruefen:** iOS UND macOS (identischer Code-Pfad, aber moeglicherweise unterschiedliche Daten durch Sync)

---

## 5e. Blast Radius

| Bereich | Risiko | Details |
|---------|--------|---------|
| iOS Backlog | HOCH | Zombie erscheint als normaler Task |
| iOS Coach-Backlog | HOCH | Zombie inflated Tier-Counts |
| macOS Backlog | HOCH | Identischer Code-Pfad |
| macOS Coach-Backlog | HOCH | Identischer Code-Pfad |
| Coach Intention Goals | MITTEL | Wenn Zombie completed wird, zaehlt er fuer Fulfillment |
| Streak/Kategorie-Tracking | MITTEL | Zombie-Completions verfaelschen Statistik |
| ALLE Recurring Tasks | HOCH | Nicht nur Zehnagel — jede Serie mit historischen GroupID-Fragmenten |
| Focus Block Assignment | NIEDRIG | Dedup-Check in createNextInstance verhindert Duplikate |
| Spotlight | NIEDRIG | Templates korrekt gefiltert |

---

## Devil's Advocate Challenge

**Verdict: LUECKEN → adressiert**

Wichtigste Findings des Challengers:
1. H4 (Migration-Zombie-Zyklus) war zu niedrig bewertet → auf MITTEL-HOCH korrigiert
2. Der b8af930 Fix KOENNTE bereits ausreichen — aber wurde nie auf Device verifiziert
3. Fehlender konkreter Template-Regenerator-Mechanismus identifiziert (Migration nach Repair)

---

## Offene Frage an Henning

**Tritt der Bug NACH dem 10. Maerz (Fix b8af930) noch auf?**
- Falls JA → H4 (Migration-Zyklus) oder H3 (CloudKit) ist aktiv → defensiver Fix noetig
- Falls NEIN oder UNSICHER → defensiver Fix trotzdem empfohlen (verhindert Wiederauftreten strukturell)

---

## Empfohlener Fix-Ansatz

**Defensiver Fix: 2 Massnahmen (unabhaengig ob b8af930 bereits ausreicht)**

### Massnahme 1: Completed Tasks neutralisieren beim Serie-beenden
**Datei:** `SyncEngine.swift` — `deleteRecurringTemplate(groupID:)`
- Zusaetzlich zum Loeschen von Template + offenen Tasks:
- Alle COMPLETED Tasks mit derselben GroupID: `recurrencePattern = "none"` setzen
- Effekt: Repair kann diese Tasks nie mehr als "recurring" identifizieren → kein Treibstoff
- ~10 LoC Aenderung

### Massnahme 2: Startup-Reihenfolge aendern
**Dateien:** `FocusBloxApp.swift:283-285` + `FocusBloxMacApp.swift:287-290`
- NEU: migration → dedup → repair (statt repair → migration → dedup)
- Effekt: Repair laeuft NUR auf sauberem Datenstand (nach Dedup-Konsolidierung)
- ~3 LoC Aenderung (Zeilen umsortieren)

**Gesamt:** 2 Dateien (3 mit macOS), ~15 LoC
**Kein Titel-Check noetig:** Massnahme 1 entfernt den Treibstoff, Massnahme 2 verhindert den Zyklus

### Warum KEIN Titel-Check:
- Massnahme 1+2 zusammen machen einen Titel-Check ueberfluessig
- Titel-Check waere fragil (Titel koennten sich aendern, Locale-abhaengig)
- Einfachheit > Cleverness
