# Bug 97: Apple Shortcut — "heute" im Titel wird nicht als Datum erkannt

## Symptom

Task "Heute dringend noch ein LinkedIn Post verfassen zum Thema..." wurde per Apple Workflow/Shortcut erstellt. Der Task hat Prioritaet (!!!), Kategorie (Earn) und Score (53) — aber KEIN Faelligkeitsdatum, obwohl "Heute" im Titel steht.

## Plattform

iOS + macOS (Apple Shortcuts / Siri) — `CreateTaskIntent.swift` liegt in `Sources/` (Shared Code)

---

## Agenten-Ergebnisse (5 parallele Investigationen)

### Agent 1: Wiederholungs-Check
- Bug 95 (heute) war das GEGENTEIL: JEDER Task bekam "heute" als Datum
- Fix: `titleContainsDateKeyword()` als Guard vor AI-dueDate
- Der Guard selbst ist NICHT das Problem — er erkennt "heute" korrekt
- Das Problem: Die Enrichment-Pipeline wird fuer Shortcut-Tasks gar nicht aufgerufen

### Agent 2: Datenfluss-Trace
- **Shortcut-Pfad:** `CreateTaskIntent.perform()` → `LocalTask(title:)` → `context.save()` → FERTIG
- **UI-Pfad:** `LocalTaskSource.createTask()` → save → `SmartTaskEnrichmentService.enrichTask()` → `needsTitleImprovement = true` → `TaskTitleEngine.improveTitleIfNeeded()` → save
- **Shortcut setzt `needsTitleImprovement` NIE auf `true`**
- **Shortcut ruft weder SmartTaskEnrichmentService noch TaskTitleEngine auf**

### Agent 3: Alle Schreiber
- dueDate wird NUR in `TaskTitleEngine.performImprovement()` Zeile 244 gesetzt (fuer AI-Extraktion)
- Guard: `task.dueDate == nil && titleContainsDateKeyword(originalTitle) && relativeDateFrom(result.dueDateRelative) != nil`
- Shortcut-Tasks erreichen diese Stelle NIE

### Agent 4: Szenarien
- Case-Sensitivity: Kein Problem (`.lowercased()`)
- Keyword "heute": Korrekt in der Liste
- **Hauptursache: `needsTitleImprovement` Flag wird nicht gesetzt → TaskTitleEngine ueberspringt den Task**
- Sekundaer: `SmartTaskEnrichmentService.enrichAllTbdTasks()` laeuft zwar beim App-Start (erklaert Prio/Kategorie/Score), aber `improveAllPendingTitles()` prueft `needsTitleImprovement == true`

### Agent 5: Blast Radius
- Nur 1 Call-Site fuer `titleContainsDateKeyword()`: TaskTitleEngine.swift:242
- Betroffen: ALLE Tasks die per Shortcut/Siri erstellt werden (nie Enrichment)
- SmartTaskEnrichmentService laeuft separat (erklaert warum Prio/Kategorie funktionieren)
- "morgen", Wochentage etc. waeren ebenfalls betroffen (gleicher Pfad)

---

## Hypothesen

### Hypothese 1: `CreateTaskIntent` setzt `needsTitleImprovement` nicht (HOCH)

**Beweis DAFUER:**
- `CreateTaskIntent.swift:18`: `let task = LocalTask(title: taskTitle)` — keine weiteren Flags
- `LocalTask.init()` hat `needsTitleImprovement` Default = `false`
- `TaskTitleEngine.improveAllPendingTitles()` Zeile 188: `#Predicate { $0.needsTitleImprovement && !$0.isCompleted }` — filtert Tasks OHNE Flag raus
- Im Vergleich: `LocalTaskSource.createTask()` Zeile 130: `task.needsTitleImprovement = true` (explizit gesetzt)

**Beweis DAGEGEN:**
- Keiner. Der Code ist eindeutig.

**Wahrscheinlichkeit: HOCH (99%)**

### Hypothese 2: `titleContainsDateKeyword` erkennt "Heute" nicht (NIEDRIG)

**Beweis DAFUER:**
- Keiner. Die Funktion lowercased den Input und prueft "heute" — funktioniert.

**Beweis DAGEGEN:**
- Zeile 84: `let lower = title.lowercased()` — case-insensitive
- Zeile 86: `"heute"` ist explizit in der Keyword-Liste
- Unit-Test bestaetigt: `titleContainsDateKeyword("Heute Arzt anrufen")` → `true`

**Wahrscheinlichkeit: SEHR NIEDRIG (<1%)**

### Hypothese 3: AI-Enrichment scheitert / ist nicht verfuegbar (NIEDRIG)

**Beweis DAFUER:**
- Wenn Apple Intelligence nicht verfuegbar: Guard in Zeile 170 blockiert
- Wenn AI Scoring disabled: Guard in Zeile 171 blockiert

**Beweis DAGEGEN:**
- Der Task HAT AI-Enrichment (Prio, Kategorie, Score) → AI laeuft
- SmartTaskEnrichmentService funktioniert → Device hat AI-Support
- Aber: SmartTaskEnrichmentService ist ein ANDERER Service als TaskTitleEngine

**Wahrscheinlichkeit: NIEDRIG (5%)**

---

## Wahrscheinlichste Ursache

**Hypothese 1: `CreateTaskIntent` setzt `needsTitleImprovement = true` nicht.**

Der Vergleich der beiden Pfade ist eindeutig:

| Schritt | UI-Pfad (funktioniert) | Shortcut-Pfad (Bug) |
|---------|----------------------|---------------------|
| Task erstellen | `LocalTaskSource.createTask()` | `CreateTaskIntent.perform()` |
| SmartTaskEnrichment | Zeile 126-127: sofort | App-Start: `enrichAllTbdTasks()` |
| `needsTitleImprovement` | Zeile 130: `= true` | **FEHLT** → bleibt `false` |
| TaskTitleEngine | Zeile 131-132: sofort | **NIE** (Flag = false) |
| dueDate Extraktion | Ja (wenn Keyword vorhanden) | **NIE** |

Die anderen Hypothesen sind weniger wahrscheinlich weil:
- H2: Unit-Tests beweisen dass "heute" erkannt wird
- H3: Task hat Prio/Kategorie/Score → AI laeuft, nur TitleEngine wird nicht getriggert

---

## Debugging-Plan (falls gewuenscht)

**Bestaetigung:** Im `CreateTaskIntent.perform()` nach Zeile 18 ein `print("[CreateTaskIntent] needsTitleImprovement: \(task.needsTitleImprovement)")` einbauen → Output sollte `false` zeigen.

**Widerlegung:** Wenn Output `true` zeigt, dann ist die Ursache woanders (z.B. `improveAllPendingTitles()` wird nie aufgerufen).

---

## Blast Radius

- **ALLE Tasks per Apple Shortcut/Siri** sind betroffen — keine dueDate-Extraktion, kein Title-Cleanup, keine Urgency-Erkennung
- "morgen", "naechste Woche", Wochentage etc. ebenfalls betroffen (gleicher Pfad)
- SmartTaskEnrichment (Kategorie, Prio, Score) funktioniert — anderer Service mit eigenem Batch-Trigger

---

## Challenge-Ergebnisse (Devil's Advocate)

### Verdict: LUECKEN → adressiert

**Luecke 1: "dringend" noch im Titel?**
Im Screenshot steht "Heute dringend noch ein LinkedIn Post verfassen zum Them..." — "dringend" ist NOCH im Titel. `stripKeywords()` entfernt nur Prefix-Muster wie `dringend:`, nicht inline "dringend". Die TitleEngine-AI wuerde "dringend" entfernen. → **Bestaetigt: TitleEngine lief NIE.**

**Luecke 2: Bestehende Tasks nicht repariert**
Der Fix (Flag setzen) hilft nur fuer NEUE Tasks. Der bereits erstellte Task hat `needsTitleImprovement = false` und wird nie verarbeitet. → **Fix muss existierende Tasks migrieren.**

**Luecke 3: Deterministischer Fallback**
`titleContainsDateKeyword()` erkennt "heute" bereits deterministisch. Anstatt auf AI-Batch beim App-Start zu warten, koennte man dueDate SOFORT deterministisch setzen — schneller, zuverlaessiger. → **In den Fix einbauen: sofortige deterministische Extraktion in CreateTaskIntent.**

**Luecke 4: AI koennte bei langem Titel kein Datum zurueckgeben**
Selbst wenn Flag gesetzt: Wenn AI fuer "Heute dringend noch ein LinkedIn Post verfassen zum Thema..." `dueDateRelative = nil` liefert, bleibt dueDate leer. → **Deterministischer Fallback loest das.**

---

## Vorgeschlagener Fix (aktualisiert nach Challenge)

Zwei-Schichten-Ansatz in `CreateTaskIntent.perform()`:

**Schicht 1: Sofortige deterministische Datum-Extraktion**
```swift
let task = LocalTask(title: taskTitle)

// Deterministisch: Datum aus Keywords sofort extrahieren (kein AI noetig)
if TaskTitleEngine.titleContainsDateKeyword(taskTitle) {
    // Keyword finden und Datum setzen
    let keywords: [(String, String)] = [
        ("heute", "heute"), ("today", "heute"),
        ("morgen", "morgen"), ("tomorrow", "morgen"),
        // ... weitere
    ]
    let lower = taskTitle.lowercased()
    for (keyword, relative) in keywords {
        if lower.contains(keyword) {
            task.dueDate = TaskTitleEngine.relativeDateFrom(relative)
            break
        }
    }
}

task.needsTitleImprovement = true  // Schicht 2: Titel-Cleanup + Urgency spaeter per AI
context.insert(task)
try context.save()
```

**Schicht 2: AI-Batch beim naechsten App-Start**
`needsTitleImprovement = true` → Titel-Cleanup ("dringend" entfernen, Verb-Infinitiv, etc.) per TitleEngine beim naechsten App-Start.

**Vorteile:**
- dueDate wird SOFORT gesetzt (kein Warten auf App-Start)
- AI-Ausfall hat keinen Einfluss auf Datum-Erkennung
- Titel-Cleanup passiert trotzdem (async, beim naechsten App-Start)

**Aenderung:** 1 Datei (`CreateTaskIntent.swift`), ~10-15 Zeilen.

**Call-Sites:**
- `TaskTitleEngine.titleContainsDateKeyword()` — bereits public static, direkt aufrufbar
- `TaskTitleEngine.relativeDateFrom()` — bereits public static, direkt aufrufbar
- `FocusBloxApp.swift:287-288` — `improveAllPendingTitles()` fuer Titel-Cleanup
