# Bug 48: Root Cause Analyse - Attribute Loss

**Datum:** 2026-02-13
**Status:** Root Cause identifiziert, nicht gefixt
**Prioritaet:** KRITISCH (Datenverlust)

---

## Problem

Erweiterte Attribute (Importance, Urgency, Duration, Tags) werden wiederholt geloescht wenn ein Task bearbeitet wird, obwohl diese Felder NICHT geaendert werden sollten.

**Beispiel:** User aendert nur den Titel eines Tasks mit Importance=2 und Urgency="urgent". Nach dem Speichern sind beide Werte verschwunden.

---

## Vorgeschichte

- **Bug 32** (2026-02-10): Race Condition beim Update von Importance/Urgency - angeblich gefixt
- **Bug 18** (2026-02-10): Reminders-Tasks Wichtigkeit/Dringlichkeit nicht speicherbar - angeblich gefixt
- **Bug 48** (2026-02-13): Problem tritt ERNEUT auf - vorherige Fixes waren Symptom-Behandlung, nicht Root Cause

---

## Analyse-Methode

**Verdachts-Stellen (aus Code-Review):**
1. ~~`TaskFormSheet.swift` - Priority nil wird zu `.medium` Hard-Coded~~ → Nicht relevant
2. ~~`BacklogView.swift` - updateTask() ueberschreibt Attribute mit Defaults~~ → Richtige Stelle, aber nicht Root Cause
3. ~~`RemindersSyncService.swift` - Priority-Mapping ueberschreibt lokale Werte~~ → Nicht relevant (Importance preserve-Logik OK)

**Ergebnis:** Root Cause liegt in `SyncEngine.updateTask()`, NICHT in den Views.

---

## Root Cause

### Datei: `Sources/Services/SyncEngine.swift`

**Zeilen 67-83:**
```swift
func updateTask(
    itemID: String,
    title: String,
    importance: Int?,         // ← PROBLEM: nil = "nicht gesetzt" ODER "loeschen"?
    duration: Int?,
    tags: [String],
    urgency: String?,         // ← PROBLEM: nil = "nicht gesetzt" ODER "loeschen"?
    taskType: String,
    dueDate: Date?,
    description: String?,
    recurrencePattern: String? = nil,
    recurrenceWeekdays: [Int]? = nil,
    recurrenceMonthDay: Int? = nil
) throws {
    guard let task = try findTask(byID: itemID) else { return }

    task.title = title
    task.importance = importance        // ← Zeile 72: ÜBERSCHREIBT IMMER
    task.estimatedDuration = duration
    task.tags = tags
    task.urgency = urgency              // ← Zeile 75: ÜBERSCHREIBT IMMER
    task.taskType = taskType
    task.dueDate = dueDate
    task.taskDescription = description
    task.recurrencePattern = recurrencePattern ?? "none"
    task.recurrenceWeekdays = recurrenceWeekdays
    task.recurrenceMonthDay = recurrenceMonthDay

    try modelContext.save()
}
```

**Problem:**
Die Methode unterscheidet NICHT zwischen:
- **"User will Wert auf nil setzen"** (absichtlich loeschen)
- **"User hat Wert nicht geaendert"** (soll erhalten bleiben)

Wenn ein Caller `nil` uebergibt, wird der existierende Wert IMMER GELOESCHT.

---

## Fehlerhafte Callsites

### Datei: `Sources/Views/BacklogView.swift`

#### 1. `saveTitleEdit()` - Zeile 459-469

**Kontext:** User aendert nur den Titel via Inline-Edit (Quick Edit)

```swift
try syncEngine.updateTask(
    itemID: task.id,
    title: title,               // ← NEU (vom User geaendert)
    importance: task.importance, // ← aus PlanItem (kann bereits nil sein!)
    urgency: task.urgency,       // ← aus PlanItem (kann bereits nil sein!)
    ...
)
```

**Problem:** `PlanItem` ist ein **Value Type** (struct) - wenn LocalTask urspruenglich `importance=2` hatte, aber das Mapping fehlschlaegt oder das Property nicht geladen wurde, steht in `task.importance` bereits `nil`.

**Ergebnis:** Attribute werden geloescht obwohl User nur Titel aendern wollte.

---

#### 2. `updateTask()` - Zeile 391-395

**Kontext:** Full-Edit Dialog (TaskFormSheet)

```swift
try syncEngine.updateTask(
    itemID: task.id,
    urgency: urgency,  // ← Parameter von EditTaskSheet (kann nil sein)
    ...
)
```

**Problem:** Wenn User im Dialog Urgency nicht auswaehlt, wird `nil` uebergeben. Falls Task vorher `urgency="urgent"` hatte, wird es geloescht.

---

#### 3. `updateImportance()`, `updateUrgency()`, `updateCategory()` - Zeilen 403-439

**Kontext:** User aendert NUR EINES der Felder (Importance, Urgency oder Category)

```swift
// updateImportance() - Zeile 407
try syncEngine.updateTask(
    itemID: item.id,
    title: item.title,
    importance: importance,     // ← NEU
    urgency: item.urgency,      // ← aus PlanItem (kann nil sein!)
    ...
)
```

**Problem:** Alle anderen Felder werden aus `item` (PlanItem struct) uebernommen. Wenn `item.urgency` bereits `nil` ist (z.B. weil Mapping fehlgeschlagen), wird der existierende Wert geloescht.

---

## Reproduktion

### Test 1: Titel-Edit (Quick Edit)
1. Task mit Importance=High (3) und Urgency="urgent" erstellen
2. Inline-Edit: Titel aendern (nicht Full-Edit Dialog)
3. Enter druecken → `saveTitleEdit()` aufgerufen
4. **Expected:** Importance und Urgency bleiben erhalten
5. **Actual (Bug):** Beide Werte sind nil

### Test 2: Full-Edit Dialog
1. Task mit Importance=Medium (2) und Urgency="later" erstellen
2. Full-Edit Dialog oeffnen (Tap auf Task)
3. NUR Due Date aendern, Importance/Urgency NICHT anfassen
4. Speichern → `updateTask()` aufgerufen mit Default-Werten
5. **Expected:** Importance und Urgency bleiben erhalten
6. **Actual (Bug):** Werte verschwinden wenn Dialog default-Werte (nil) hatte

### Test 3: Category-Switch
1. Task mit allen Attributen erstellen (Importance, Urgency, Duration)
2. Category (taskType) via Picker aendern → `updateCategory()` aufgerufen
3. **Expected:** Importance/Urgency/Duration bleiben
4. **Actual (Bug):** Geloescht wenn PlanItem-Werte bereits nil waren

---

## Warum PlanItem.importance/urgency nil sein kann

**PlanItem ist ein Value Type (struct) - keine Live-Referenz zu LocalTask!**

```swift
struct PlanItem {
    let importance: Int?
    let urgency: String?
    // ...

    init(localTask: LocalTask) {
        self.importance = localTask.importance
        self.urgency = localTask.urgency
        // ...
    }
}
```

**Problem-Szenarien:**
1. **Mapping-Fehler:** LocalTask hat Importance=2, aber Initializer mappt falsch → PlanItem.importance = nil
2. **Stale Data:** BacklogView hat alte PlanItem-Liste, LocalTask wurde zwischenzeitlich aktualisiert
3. **Lazy Loading:** SwiftData lädt Optional-Properties nicht sofort → nil beim ersten Zugriff

---

## Fix-Strategien

### Option A: Preserve-Logik in SyncEngine (empfohlen)

```swift
func updateTask(..., importance: Int?, urgency: String?, ...) throws {
    guard let task = try findTask(byID: itemID) else { return }

    task.title = title

    // Preserve-Logik: nur setzen wenn nicht-nil
    if let importance = importance {
        task.importance = importance
    }
    if let urgency = urgency {
        task.urgency = urgency
    }
    // Achtung: User kann dann NICHT auf nil zuruecksetzen!

    // Alternative: Expliziter "keep current" Sentinel-Wert
}
```

**Pro:**
- Einfach zu implementieren
- Bestehende Callsites funktionieren weiter

**Contra:**
- User kann Werte nicht mehr auf nil zuruecksetzen (TBD-State)
- Braucht zusaetzlichen Mechanismus fuer "explizit nil"

---

### Option B: Separate Update-Methoden (granular)

```swift
func updateTitle(itemID: String, title: String) throws
func updateImportance(itemID: String, importance: Int?) throws
func updateUrgency(itemID: String, urgency: String?) throws
func updateDuration(itemID: String, duration: Int?) throws
// ... bereits vorhanden: updateDuration(), updateNextUp(), etc.
```

**Pro:**
- Explizit: Caller sagt genau welches Feld geaendert wird
- Keine Ambiguitaet bei nil-Werten
- Bereits teilweise vorhanden (updateDuration, updateNextUp)

**Contra:**
- Mehr Methoden
- Full-Edit Dialog muss mehrere Methoden aufrufen

---

### Option C: Explicitly Pass Current Values (Caller-Verantwortung)

```swift
// Caller MUSS aktuelle Werte aus LocalTask laden, nicht aus PlanItem
let task = try findLocalTask(byID: item.id)
try syncEngine.updateTask(
    itemID: task.uuid.uuidString,
    title: newTitle,
    importance: task.importance,  // ← aus LocalTask, nicht PlanItem
    urgency: task.urgency,
    ...
)
```

**Pro:**
- SyncEngine bleibt simpel
- Keine API-Aenderung

**Contra:**
- Fehleranfaellig (Caller vergisst aktuelle Werte zu laden)
- Dupliziert Fetch-Logik
- Loest nicht das "explizit nil setzen" Problem

---

## Empfehlung

**Option B (Separate Methoden) + Refactoring von BacklogView**

1. **SyncEngine:**
   - Bestehende Single-Field-Methoden (updateDuration, updateNextUp) um weitere ergaenzen
   - `updateImportance()`, `updateUrgency()`, `updateTitle()`, `updateTags()`, etc.
   - Full-Edit weiter mit `updateTask()` (nimmt alle Felder)

2. **BacklogView:**
   - `saveTitleEdit()` → nur `updateTitle()` aufrufen
   - `updateImportance()` → bleibt wie ist (ruft aber neue Single-Field-Methode auf)
   - `updateUrgency()` → bleibt wie ist
   - `updateCategory()` → nur `updateTaskType()` aufrufen
   - Full-Edit Dialog → weiter `updateTask()` (aber mit ALLEN aktuellen Werten)

3. **TaskFormSheet (Full-Edit):**
   - Beim Oeffnen: LocalTask-Werte laden (nicht PlanItem)
   - Beim Speichern: Alle Felder explizit uebergeben

---

## Betroffene Dateien

- `Sources/Services/SyncEngine.swift` - Neue Single-Field Update-Methoden
- `Sources/Views/BacklogView.swift` - Callsites auf neue Methoden umstellen
- `Sources/Views/TaskFormSheet.swift` - Evtl. Init-Logik anpassen (LocalTask statt PlanItem)

**Geschaetzter Aufwand:** KLEIN (~50-100 LoC)

---

## Plattform-Impact

**iOS:** Betroffen (BacklogView nutzt fehlerhafte Callsites)
**macOS:** NICHT direkt betroffen - macOS hat noch kein Task-Edit implementiert

**ABER:** Wenn macOS in Zukunft Task-Bearbeitung bekommt, MUSS es die neuen Single-Field-Methoden nutzen, NICHT die alte `updateTask()`-Variante!

---

## Lessons Learned

1. **Value Types (PlanItem) sind NICHT live-synchronized mit Models (LocalTask)**
   - PlanItem.importance kann nil sein, auch wenn LocalTask.importance=2
   - Immer frisch aus SwiftData fetchen wenn aktuelle Werte benoetigt werden

2. **Optional-Parameter sind ambiguous:**
   - `nil` kann "nicht gesetzt" oder "explizit loeschen" bedeuten
   - Granulare Update-Methoden bevorzugen (Single Responsibility)

3. **Bug 32/18 waren Symptom-Fixes, nicht Root Cause:**
   - Race Condition war real, aber nicht die einzige Ursache
   - Preserve-Logik in RemindersSyncService war korrekt, aber BacklogView umging sie
   - Symptome bekaempfen != Problem loesen

---

## Naechste Schritte

1. **Spec schreiben** (`/write-spec`) mit Fix-Strategie
2. **TDD RED:** Tests fuer Single-Field Updates schreiben
3. **Implementieren:** Neue Methoden + Callsites umstellen
4. **Validieren:** Alle 3 Reproduktions-Tests durchfuehren

**ERST nach TDD RED + Spec-Approval implementieren!**

---

**Analysiert von:** Claude Sonnet 4.5
**Dokumentiert:** 2026-02-13
