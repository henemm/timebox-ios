# BUG_117 Analyse: Unit Test Default-Werte phase/category fehlen

## Symptom

Test `test_localTask_defaultValues_phase1` schlägt fehl:
```
XCTAssertEqual(task.urgency, "not_urgent")   → FAIL: nil
XCTAssertEqual(task.taskType, "maintenance") → FAIL: ""
```

## Agenten-Ergebnisse

### 1. Wiederholungs-Check
- BUG_117 ist als "known pre-existing failure" in Memory gelistet
- **Verursacher:** Commit `c6171de` ("fix: TBD Tasks - keine Defaults beim Erstellen", 2026-01-31) hat absichtlich Urgency-Defaults aus Views entfernt, aber den Test NICHT angepasst
- Test war vorher GRÜN (belegt in Artifacts: reminders-urgency-importance-fix, live-activity, app-group-swiftdata)
- Verwandt: BUG_116 (Sort-Order-Tests), BUG_115 (Action-Count-Tests) — gleiche Muster: Test-Erwartung vs. Code-Realität

### 2. Datenfluss-Trace
- `LocalTask.init()` setzt `urgency = nil`, `taskType = ""`
- `LocalTaskSource.createTask()` hat `taskType: String = "maintenance"` als Parameter-Default — aber der Test ruft `LocalTask(title:)` direkt auf, NICHT `createTask()`
- AI-Enrichment setzt Werte NACH Erstellung (nicht im Model)
- TBD-Konzept: nil/leer = "noch nicht definiert"

### 3. Alle Schreiber
- 14+ Stellen schreiben `taskType`, 8+ schreiben `urgency`
- Nur `LocalTaskSource.createTask()` hat "maintenance" Default
- Siri Intent, Share Extension, Reminders Import: alle ohne Defaults

### 4. Szenarien
- Direkte `LocalTask(title:)` Erstellung → immer nil/leer
- Siri, Share Extension, Reminders → keine Defaults
- Recurring Children → erben vom Parent (gut wenn Parent Werte hat)
- CloudKit Sync → keine Post-Sync-Enrichment

### 5. Blast Radius
- BehavioralProfileService: Braucht kategorisierte Tasks für Affinität
- SmartTaskEnrichmentService: Prüft `taskType.isEmpty` → leerer String wird als "gesetzt" behandelt
- isTbd computed property: `urgency == nil` → Task gilt als "to be defined"
- CategoryStats: Leere Tasks landen im "uncategorized" Bucket

## Hypothesen

### H1: Vergessenes Test-Update nach bewusster TBD-Entscheidung (HOCH)
**Dafür:**
- Commit `c6171de` (2026-01-31) hat das TBD-Konzept eingeführt: "keine Defaults beim Erstellen"
- Model-Kommentar Zeile 30: `// TBD Tasks (Optional Fields - keine Fake-Defaults)`
- Kommentar Zeile 50: `// Empty string = not set (TBD concept - no defaults)`
- Das TBD-System (`isTbd` computed property) basiert DARAUF, dass urgency nil ist
- Commit hat Views geändert (BacklogRow, BacklogView, CreateTaskView, TaskFormSheet) aber KEIN Test-File
- Test war vorher GRÜN → c6171de ist der präzise Bruchpunkt

**Dagegen:**
- Könnte sein dass c6171de selbst falsch umgesetzt war (hätte auch init-Defaults ändern müssen)

### H2: c6171de war selbst falsch umgesetzt (NIEDRIG)
**Dafür:**
- Spec (task-creation-ux-refactor.md) definiert Defaults explizit
- `LocalTaskSource.createTask()` behält "maintenance" Default → Widerspruch zum TBD-Konzept

**Dagegen:**
- Die expliziten Kommentare "keine Fake-Defaults" und "TBD concept" sind bewusst formuliert
- Das gesamte TBD-Feature (isTbd, BacklogRow blocked state) hängt von nil-Defaults ab
- Wenn urgency Default "not_urgent" wäre, wäre kein Task je "TBD" bzgl. Urgency
- Das TBD-Feature funktioniert korrekt → die Entscheidung war richtig, nur der Test vergessen

### H3: Model-Defaults fehlen versehentlich (NIEDRIG)
**Dagegen:**
- Eindeutig widerlegt durch die bewussten Code-Kommentare und das funktionierende TBD-System

## Wahrscheinlichste Ursache

**H1: Vergessenes Test-Update.** Commit `c6171de` hat absichtlich das TBD-Konzept eingeführt (nil = "noch nicht definiert"). Die Views wurden angepasst, der Test nicht. Keine Architektur-Divergenz — ein konkretes, vergessenes Test-Update nach einer bewussten Code-Entscheidung.

## Fix

### Test an TBD-Konzept anpassen (einzige sinnvolle Option)
- `urgency`: erwarte `nil` statt `"not_urgent"`
- `taskType`: erwarte `""` statt `"maintenance"`
- Konsistent mit Model-Design, Kommentaren und allen Code-Pfaden

### Model-Defaults setzen (GEFÄHRLICH — nicht empfohlen)
- `urgency` Default → "not_urgent" → **bricht `isTbd`**: Kein Task wäre je "TBD" für Urgency
- `taskType` Default → "maintenance" → **bricht AI-Enrichment**: `.isEmpty`-Check schlägt nicht an
- Würde Siri/Share/Import Tasks fälschlich als "fertig kategorisiert" markieren

## Blast Radius

**Test-Fix:** Kein Blast Radius — nur der Test ändert sich.

## Devil's Advocate Challenge

**Verdict: LÜCKEN → adressiert**

Challenger fand:
1. Test war vorher GRÜN (nicht "immer kaputt") → ✅ Commit c6171de als Verursacher identifiziert
2. LocalTaskSource-Default irrelevant für diesen Test → ✅ Klargestellt
3. Einfachere Erklärung (vergessenes Test-Update) statt Architektur-Widerspruch → ✅ H1 neu formuliert
