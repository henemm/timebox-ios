# Bug-Analyse: Enrichment-Qualität — Importance/Urgency willkürlich gesetzt

## Bug-Beschreibung

Beim Klick auf "Bestehende Tasks analysieren" in den Einstellungen werden Importance und Urgency willkürlich gesetzt. Viele Tasks erhalten `importance=3, urgency=urgent` obwohl sie weder wichtig noch dringend sind. Duration bleibt oft `nil`. Kein sichtbarer Fortschritt in der UI.

**Fokus dieser Analyse:** Qualität der Enrichment-Ergebnisse (nicht das fehlende Fortschritts-Feedback).

## Konkrete Symptome aus der Konsole

| Task | Bekam | Korrekt wäre |
|------|-------|-------------|
| "Fokus Bloc Task übertragen" | imp=3, urg=urgent | imp=1-2, urg=not_urgent |
| "Schuhe etc. zur Bahnhofsmission bringen" | imp=3, urg=urgent | imp=2, urg=not_urgent |
| "Linux Rechner Update machen ," | imp=3, urg=urgent, type=income | imp=2, urg=not_urgent, type=maintenance |
| "Nachmittag Cannabis Öl herstellen" | guardrailViolation | — (Apple Safety Filter) |
| Viele Tasks | dur=nil | dur=15/30/60 |

## Agenten-Ergebnisse (5 parallel, alle completed)

### Agent 1: Wiederholungs-Check
- Enrichment wurde **mindestens 12 Mal** angefasst seit Februar 2026
- Issues #149-#154 alle am selben Tag (31.03) geöffnet UND geschlossen, Specs auf "draft"
- Die "100%/97%" Scores kamen aus einem Python-Eval-Script mit 30 festen Test-Cases — nie auf echten User-Tasks getestet

### Agent 2: Datenfluss-Trace
- **ZWEI getrennte Enrichment-Pfade:** SmartTaskEnrichmentService + TaskTitleEngine
- "Bestehende Tasks analysieren" löst `reanalyzeAllTasks()` aus → ruft `reanalyzeTask()` pro Task
- `reanalyzeTask()` hat 7 Schritte: 5 deterministisch + 2 AI (performEnrichment + enrichCategoryAndDuration)
- `performEnrichment()` schreibt DIREKT zu Hauptfeldern (importance, urgency), NICHT zu suggested*

### Agent 3: Alle Schreiber
- **3 unabhängige AI-Services** schreiben importance/urgency:
  1. SmartTaskEnrichmentService.performEnrichment() (Zeile 332-336)
  2. AITaskScoringService.performScoring() (Zeile 135-139)
  3. TaskTitleEngine.enrichWithSuggestions() (nur suggestedCategory/suggestedDuration)
- Alle haben `if task.importance == nil` Guards — wer zuerst kommt, gewinnt

### Agent 4: Fehlerszenarien
- **TaskEnrichment @Generable hat KEINE .anyOf() Constraints** auf suggestedImportance (SmartTaskEnrichmentService:58)
  - Vergleich: TaskSuggestion HAT .anyOf() Constraints (TaskTitleEngine:316-323)
- **Kein Fallback** wenn AI scheitert — Task behält nil-Werte
- **Deterministische Urgency** kann zu aggressiv sein ("bis [Wochentag]" matched zu breit)
- **Safety Filter** → nur geloggt, keine Fallback-Werte

### Agent 5: Blast Radius
- Priority Score (TaskPriorityScoringService) nutzt importance + urgency für 0-100 Score
- Falsches importance/urgency → falsche Backlog-Sektion (Dringend/Bald/Später)
- NextUpSuggestionService filtert nach estimatedDuration → fehlende Duration = Task nie vorgeschlagen
- WidgetRelevanceCalculator nutzt urgency → falsche Widget-Priorität

## Hypothesen

### Hypothese 1: AI-Prompt ist zu aggressiv bei Importance (HOCH)

**Beweis dafür:**
- System-Prompt (SmartTaskEnrichmentService:304-307):
  - `1 = nice to have (Freizeit, Hobby, optional)`
  - `2 = should do (Routine, Haushalt, Einkaufen)`
  - `3 = must do (Pflichten, Deadlines, Finanzen, Bewerbungen, Gesundheit)`
- Die meisten Alltagstasks ("Schuhe zur Bahnhofsmission", "Linux Update") könnten als "Pflicht" interpretiert werden
- Das ~3B On-Device-Modell hat limitierte Nuancen-Fähigkeit → default zu höherem Wert

**Beweis dagegen:**
- Python-Eval hat 100% Score → aber nur 30 Test-Cases, nicht repräsentativ für 263 echte Tasks

### Hypothese 2: TaskEnrichment struct hat keine .anyOf() Constraints (HOCH)

**Beweis dafür:**
- SmartTaskEnrichmentService:58-59: `@Guide(description: "Importance 1-3: ...")` — NUR Beschreibung, kein `.anyOf([1,2,3])`
- Im Vergleich: TaskTitleEngine:316-323 HAT `.anyOf()` für category und duration
- Ohne Constraints kann das Modell theoretisch jeden Int-Wert zurückgeben

**Beweis dagegen:**
- `max(1, min(3, result.suggestedImportance))` (Zeile 333) clampt auf 1-3 → ungültige Werte werden gefangen
- Aber: Die fehlenden Constraints könnten das Modell dazu verleiten, häufiger 3 zu wählen

### Hypothese 3: Urgency wird zu oft auf "urgent" gesetzt (MITTEL)

**Beweis dafür:**
- System-Prompt: `"Dringlichkeit: true wenn zeitkritisch (Termin, Frist, morgen, heute, bis [Datum])"`
- Das Modell interpretiert "Pflichten" als zeitkritisch → suggestedUrgent=true
- Deterministische Urgency: `extractDeterministicUrgency()` matched "dringend" in originalTitle und ÜBERSCHREIBT AI-Wert (Zeile 170-176)

**Beweis dagegen:**
- "Schuhe zur Bahnhofsmission" hat kein Urgency-Keyword → rein AI-getrieben

### Hypothese 4: Duration fehlt weil enrichCategoryAndDuration() scheitert (MITTEL)

**Beweis dafür:**
- Konsole zeigt viele Tasks mit `dur=nil` nach Enrichment
- `enrichCategoryAndDuration()` schreibt nur bei `[5,15,30,60].contains(minutes)` (Zeile 352)
- Wenn Modell andere Werte zurückgibt (z.B. 20, 45) → wird verworfen

**Beweis dagegen:**
- TaskSuggestion hat `.anyOf(["5","15","30","60"])` Constraint → sollte gültige Werte erzwingen

### Hypothese 5: Zwei AI-Services überschreiben sich (NIEDRIG)

**Beweis dafür:**
- SmartTaskEnrichmentService + AITaskScoringService setzen beide importance/urgency
- Keine Koordination zwischen den Services

**Beweis dagegen:**
- Beide haben `if task.importance == nil` Guards → der zweite überspringt wenn der erste bereits gesetzt hat
- Aber: Reihenfolge ist nicht deterministisch bei async Calls

### Hypothese 6: Feedback-Schleife durch Context-Injection (HOCH) — vom Challenger gefunden

**Beweis dafür:**
- `buildPrompt()` (Zeile 409-414) injiziert `fetchRecentTaskContext()` in JEDEN Prompt
- `fetchRecentTaskContext()` (Zeile 368-390) lädt die letzten 30 Tasks mit gesetzten Attributen
- Prompt enthält: "Bestehende Tasks des Nutzers (orientiere dich an deren Attributen für ähnliche Tasks):"
- Wenn Batch-Lauf startet und die ersten Tasks importance=3 bekommen, werden diese als Kontext für ALLE folgenden Tasks genutzt → Snowball-Effekt
- Das Modell sieht "30 Tasks mit importance=3" und setzt den nächsten auch auf 3

**Beweis dagegen:**
- Einzelne Task-Erstellung (nicht Batch) wäre davon weniger betroffen
- Aber: Genau beim "Bestehende Tasks analysieren" (Batch) ist das Problem am stärksten

### Hypothese 7: Duration-Bug ist strukturell, nicht AI (HOCH) — vom Challenger gefunden

**Beweis dafür:**
- `performEnrichment()` schreibt Duration zu `task.suggestedDuration` (Zeile 350-353) — NICHT zu `estimatedDuration`
- `confirmSuggestions()` (LocalTask.swift:301-302) promotet `suggestedDuration` → `estimatedDuration`
- `reanalyzeTask()` ruft `confirmSuggestions()` **NIEMALS** auf
- Ergebnis: suggestedDuration wird gesetzt, aber estimatedDuration bleibt nil
- Step 7 (`enrichCategoryAndDuration()`) prüft `estimatedDuration == nil` → läuft nochmal und schreibt DIREKT zu `estimatedDuration` (Zeile 280-283)
- Aber: Wenn `enrichCategoryAndDuration()` scheitert (Guardrail, Timeout), bleibt Duration nil — kein Fallback

**Beweis dagegen:**
- enrichCategoryAndDuration() als Step 7 ist der "Rettungsanker" — wenn er funktioniert, wird Duration gesetzt
- Aber: Zwei AI-Calls pro Task (Step 6 + Step 7) verdoppeln das Fehlerrisiko

## Wahrscheinlichste Ursachen (nach Challenge korrigiert)

1. **Feedback-Schleife (Hypothese 6)** — Context-Injection vergiftet den Batch-Lauf. Erste Tasks mit importance=3 werden zum Vorbild für alle folgenden
2. **AI-Prompt + fehlende Constraints (Hypothese 1+2)** — Das ~3B Modell tendiert zu höheren Werten, verstärkt durch die Feedback-Schleife
3. **Duration strukturell gebrochen (Hypothese 7)** — performEnrichment() schreibt zu suggestedDuration statt estimatedDuration, confirmSuggestions() wird nie aufgerufen

## Vorgeschlagener Fix (3 Hebel)

### Hebel 1: Feedback-Schleife unterbrechen
- `reanalyzeAllTasks()` sollte `fetchRecentTaskContext()` EINMAL vor dem Batch laden, nicht pro Task
- Oder: Context-Injection bei Batch-Enrichment deaktivieren

### Hebel 2: Duration-Promotion fixen
- In `reanalyzeTask()` nach Step 6: `task.confirmSuggestions()` aufrufen (oder direkt `estimatedDuration = suggestedDuration` setzen)

### Hebel 3: Prompt-Balance verbessern
- Default-Bias im Prompt anpassen: "Im Zweifel importance=2 (should do), NICHT 3"
- `.anyOf()` Constraints auf TaskEnrichment struct hinzufügen (wie bei TaskSuggestion)

## Debugging-Plan

Um die Hypothesen zu BEWEISEN:
1. **Feedback-Schleife:** Logging in `buildPrompt()` das den Context-Block ausgibt. Prüfen ob die injizierten Tasks überwiegend importance=3 haben
2. **Duration:** Logging in `performEnrichment()` nach Zeile 353 das `suggestedDuration` ausgibt. Prüfen ob der Wert gesetzt wird aber in estimatedDuration nicht ankommt
3. **Prompt-Bias:** Logging der rohen AI-Response BEVOR Clamping/Validation

## Blast Radius
- Priority Score → Backlog-Sektionen → NextUp-Vorschläge → Widget-Relevanz
- Falsches importance=3 verschiebt Tasks in "Dringend"-Sektion
- Fehlende Duration → Tasks nie in NextUp vorgeschlagen
