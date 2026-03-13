# Bug 95: Neue Tasks bekommen immer Faelligkeitsdatum "heute"

## Bug-Beschreibung
- **Plattform:** iOS + macOS
- **Symptom:** Alle neu erstellten Tasks erhalten automatisch das Faelligkeitsdatum "heute"
- **Erwartetes Verhalten:** Neue Tasks sollen KEIN Default-Faelligkeitsdatum haben (nil/leer)

---

## 5a. Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- Bug 95 wurde NIE zuvor adressiert
- Commits c6171de + 650ba7c fixten TBD-Defaults fuer importance/urgency/duration — aber NICHT dueDate
- **Kritischer Fund:** TaskTitleEngine.swift Zeile 222-224 setzt dueDate NACH Task-Erstellung

### Agent 2 (Datenfluss-Trace)
- LocalTask.dueDate ist korrekt `Date?` (optional, kein Default)
- TaskFormSheet/CreateTaskView: Save-Logik `hasDueDate ? dueDate : nil` ist korrekt
- LocalTaskSource.createTask() respektiert nil — kein eigener Default
- Alle Non-Form Erstellungspfade (Share, Watch, QuickCapture, Siri) sind korrekt (nil)

### Agent 3 (Alle Schreiber)
- 9 Schreibstellen gefunden
- Verdaechtig: `@State private var dueDate = Date()` in TaskFormSheet + CreateTaskView
- Aber Save-Logik gated korrekt mit hasDueDate

### Agent 4 (Alle Szenarien)
- 10 Erstellungs-Szenarien analysiert
- SmartTaskEnrichmentService setzt dueDate NICHT
- RecurrenceService hat Fallback `dueDate ?? Date()` (Zeile 84)

### Agent 5 (Blast Radius)
- **CRASH-Risiko:** NotificationService.swift Zeile 62: `$0.dueDate!` (Force Unwrap)
- AI-Scoring: Tasks mit dueDate=heute bekommen kuenstlich hohe Scores
- Sortierung: Tasks mit dueDate=heute erscheinen oben in Overdue-Sections

### Ueberlappungen
- Alle Agenten bestaetigen: Die Save-Logik in den Views ist korrekt (nil wenn Toggle aus)
- Alle Agenten bestaetigen: LocalTask Model hat keinen Default-Wert fuer dueDate
- Agent 1 fand als einziger den TaskTitleEngine-Pfad als moegliche Root Cause

---

## 5b. ALLE moeglichen Ursachen

### Hypothese 1: TaskTitleEngine AI-Enrichment setzt dueDate (HOCH)

**Beschreibung:** Nach Task-Erstellung (mit korrektem `dueDate = nil`) laeuft automatisch `TaskTitleEngine.improveTitleIfNeeded()`. Die on-device AI analysiert den Titel und kann `dueDateRelative = "heute"` zurueckgeben, auch wenn kein Datum im Titel steht. Zeile 222-224 setzt dann `task.dueDate = today`.

**Beweis DAFUER:**
- `LocalTaskSource.swift` Zeile 130-132: `needsTitleImprovement = true` wird fuer JEDEN neuen Task gesetzt
- `TaskTitleEngine.swift` Zeile 222-224: `if task.dueDate == nil, let date = Self.relativeDateFrom(result.dueDateRelative) { task.dueDate = date }`
- Der System-Prompt (Zeile 206) fordert explizit: "Extrahiere Zeitangaben aus Floskeln: 'heute', 'morgen'..."
- Die AI koennte "heute" als Default-Antwort geben wenn kein Datum erkennbar ist (Halluzination)
- Dies erklaert warum ALLE Tasks betroffen sind — jeder Task durchlaeuft diesen Pfad

**Beweis DAGEGEN:**
- `@Guide` Annotation sagt: "Return nil if no date mentioned" — AI sollte nil zurueckgeben
- `dueDateRelative: String?` ist Optional — nil sollte moeglich sein
- `relativeDateFrom(nil)` gibt nil zurueck (Zeile 87: switch auf nil faellt nicht in einen case)
- Unklar ob Foundation Models @Generable tatsaechlich zuverlaessig nil produziert fuer String?

**Wichtige Einschraenkung (vom Challenger):**
- TaskTitleEngine laeuft NUR wenn Apple Intelligence verfuegbar UND aiScoringEnabled = true
- Zeile 154: `guard Self.isAvailable else { return }` / Zeile 155: `guard AppSettings.shared.aiScoringEnabled`
- Wenn der Bug auch OHNE AI auftritt, ist diese Hypothese FALSCH
- Der System-Prompt hat kein Nil-Beispiel: Zeile 207-208 zeigen nur Beispiele MIT Datum — das Modell koennte lernen IMMER ein Datum zurueckzugeben
- Diagnostik: Wenn dueDate = Mitternacht (startOfDay) → TaskTitleEngine. Wenn exakter Timestamp → anderer Pfad.

**Wahrscheinlichkeit: HOCH** (wenn AI aktiv), **UNKLAR** (wenn AI inaktiv)

### Hypothese 2: @State dueDate = Date() wird trotz Toggle an Task uebergeben (NIEDRIG)

**Beschreibung:** TaskFormSheet.swift Zeile 39 und CreateTaskView.swift Zeile 12 initialisieren `@State dueDate = Date()`. Obwohl die Save-Logik `hasDueDate ? dueDate : nil` korrekt ist, koennte ein SwiftUI-State-Bug dazu fuehren, dass der Wert trotzdem uebergeben wird.

**Beweis DAFUER:**
- `dueDate = Date()` ist unnoetig wenn `hasDueDate = false`
- Code-Smell: Nicht-optionaler State fuer optionales Feld

**Beweis DAGEGEN:**
- Save-Logik Zeile 467: `let finalDueDate: Date? = hasDueDate ? dueDate : nil` ist klar
- `hasDueDate` defaulted auf `false`
- Der ternary Operator ist trivial korrekt — kein SwiftUI-Bug bekannt
- Wenn dies der Bug waere, waere die AI-Enrichment irrelevant

**Wahrscheinlichkeit: NIEDRIG** — Logik ist korrekt, muesste SwiftUI-Framework-Bug sein

### Hypothese 3: RecurrenceService Fallback setzt dueDate (NIEDRIG fuer allgemeinen Fall)

**Beschreibung:** RecurrenceService.swift Zeile 84: `let baseDate = completedTask.dueDate ?? Date()`. Wenn ein Recurring-Task ohne dueDate completed wird, bekommt die neue Instanz dueDate = heute.

**Beweis DAFUER:**
- Expliziter `Date()` Fallback im Code
- Betrifft recurring Tasks

**Beweis DAGEGEN:**
- Bug sagt "ALLE neu erstellten Tasks" — nicht nur Recurring
- RecurrenceService laeuft nur bei Task-Completion, nicht bei Erstellung
- Erklaert nicht das Hauptsymptom

**Wahrscheinlichkeit: NIEDRIG** — Nur Teilproblem, nicht die Hauptursache

---

## 5c. Wahrscheinlichste Ursache

**Hypothese 1: TaskTitleEngine AI-Enrichment** ist die wahrscheinlichste Ursache weil:

1. Es ist der EINZIGE Pfad der dueDate NACH korrekter Erstellung (mit nil) ueberschreibt
2. Es laeuft bei JEDEM neuen Task (needsTitleImprovement = true in Zeile 130)
3. Es erklaert warum ALLE Tasks betroffen sind — unabhaengig vom Erstellungsweg
4. Die on-device AI (Foundation Models) koennte "heute" als Default zurueckgeben, besonders wenn:
   - `String?` in `@Generable` nicht zuverlaessig nil produziert
   - Die AI den Prompt woertlich nimmt und immer versucht ein Datum zu extrahieren

Hypothese 2 ist unwahrscheinlich weil die Save-Logik trivial korrekt ist.
Hypothese 3 ist ein separates Teilproblem nur fuer Recurring Tasks.

---

## 5d. Debugging-Plan

### Hypothese 1 BESTAETIGEN:
- An `TaskTitleEngine.swift` Zeile 222 ein `print()` hinzufuegen:
  ```swift
  print("[TaskTitleEngine] Task '\(task.title)': dueDateRelative=\(String(describing: result.dueDateRelative)), dueDate was nil=\(task.dueDate == nil)")
  ```
- Erwarteter Output wenn Hypothese STIMMT: `dueDateRelative=Optional("heute")` fuer generische Titel ohne Datum
- Erwarteter Output wenn Hypothese FALSCH: `dueDateRelative=nil` fuer generische Titel

### Hypothese 1 WIDERLEGEN:
- Task erstellen mit AI-Scoring deaktiviert (AppSettings.aiScoringEnabled = false)
- Wenn Task TROTZDEM dueDate = heute bekommt → Hypothese 1 ist FALSCH → Hypothese 2 untersuchen

### Plattform: iOS UND macOS (beide haben TaskTitleEngine)

---

## 5e. Blast Radius

### Direkt betroffen bei einem Fix:
1. **AI-Scoring:** Tasks ohne dueDate bekommen niedrigere Urgency-Scores — korrekt
2. **Sortierung:** Tasks ohne dueDate landen am Ende (statt oben) — korrekt
3. **NotificationService:** Zeile 62 hat Force-Unwrap `dueDate!` — CRASH wenn task.dueDate = nil in Badge-Berechnung
4. **Overdue-Section:** Weniger Tasks in "ueberfaellig" — korrekt

### Aehnliche Patterns:
- `RecurrenceService.swift` Zeile 84: `dueDate ?? Date()` — gleicher Fallback-Fehler

### NotificationService — KEIN Crash-Risiko (korrigiert nach Challenge):
- Zeile 55: Predicate filtert `$0.dueDate != nil` VOR dem Force-Unwrap auf Zeile 62
- Der Force-Unwrap ist durch den Predicate sicher abgesichert

---

## Offene Fragen (aus Challenge)

1. **Tritt der Bug auch ohne Apple Intelligence auf?** (AI deaktiviert, aelteres Geraet)
   - Falls JA: Hypothese 1 ist FALSCH, ein anderer Pfad ist die Ursache
   - Falls NEIN: Hypothese 1 bestaetigt
2. **Ist das dueDate = Mitternacht (00:00) oder exakter Zeitstempel?**
   - Mitternacht → TaskTitleEngine (nutzt `startOfDay`)
   - Exakter Zeitstempel → UI-State `Date()` (nutzt aktuelle Uhrzeit)
3. **Tritt der Bug bei 100% der Tasks auf oder nur manchmal?**
   - 100% → deterministischer Pfad (eher @Generable-Bug oder Prompt-Problem)
   - Manchmal → AI-Halluzination

## Uebersehene Hypothese (aus Challenge)

### Hypothese 4: @Generable String? kann kein nil produzieren (MITTEL)
Foundation Models `@Generable` mit `dueDateRelative: String?` — moeglicherweise
gibt das Modell nicht "null" zurueck sondern laesst den Key weg, was zu unterschiedlicher
Deserialisierung fuehren koennte. Der @Guide sagt "Return nil" aber das Modell
koennte einen leeren String zurueckgeben statt nil. Leerer String faellt im switch
in `default` → return nil. ABER: Andere nicht-nil Werte wie "keine" oder "none"
koennten ebenfalls nicht matchen → return nil. Diese Hypothese ist NUR relevant
wenn das Modell systematisch "heute" oder ein anderes bekanntes Keyword zurueckgibt.

### Hypothese 5: System-Prompt trainiert auf "immer Datum extrahieren" (HOCH)
Der Prompt in TaskTitleEngine.swift Zeile 207-208 zeigt NUR Beispiele MIT Datum:
- "Erinnere mich heute daran..." → dueDate='heute'
- "Ich muss morgen noch..." → dueDate='morgen'
Kein Beispiel zeigt: "Einkaufen gehen" → dueDate=nil

Das Modell lernt aus den Beispielen: "dueDateRelative bekommt IMMER einen Wert".
Ein einfacher Prompt-Fix (Nil-Beispiel hinzufuegen) koennte das Problem loesen.
