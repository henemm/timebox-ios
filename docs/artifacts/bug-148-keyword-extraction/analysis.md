# BUG_148: Deterministische Keyword-Extraktion unvollständig

## Zusammenfassung

3 Lücken in `TaskTitleEngine.stripKeywords()` und `improveTitleIfNeeded()`:

1. **Importance-Keywords nicht implementiert** — "wichtig", "unwichtig", "important" werden weder erkannt noch gestripped
2. **Standalone Urgency-Stripping fehlt** — "dringend" als Standalone-Wort wird erkannt (setzt urgency) aber NICHT aus dem Titel entfernt. Nur `(dringend)` und `dringend:` werden gestripped.
3. **Dauer-Keywords nicht implementiert** — "30min", "1h", "15 Minuten", "2 Stunden" werden weder erkannt noch gestripped

## Root Cause

Keine Regression — Features wurden **nie implementiert**. Die deterministische Pipeline in RW_1.4 wurde nur für Urgency (Klammer/Prefix) und Datum gebaut, aber nie für Importance, Standalone-Urgency oder Duration erweitert.

## Hypothesen

### H1: Features nie implementiert (BESTÄTIGT — hoch)
- **Beweis:** `stripKeywords()` enthält keine Regex für "wichtig", "important", standalone "dringend" oder Dauer-Patterns
- **Beweis:** `improveTitleIfNeeded()` hat keinen Block für Importance-Extraktion oder Duration-Extraktion
- **Beweis:** 58 von 73 KeywordSystemTests schlagen fehl

### H2: Features implementiert aber nicht aufgerufen (WIDERLEGT)
- Kein Code für diese Features existiert irgendwo im Repository
- `git log --all --oneline | grep -i wichtig` liefert keine Implementierungs-Commits

### H3: AI sollte das übernehmen (TEILWEISE)
- AI setzt importance/urgency/duration über SmartTaskEnrichmentService — aber nur wenn AI verfügbar
- Kein deterministischer Fallback für explizite Keywords
- AITitleQualityTests hatten gezeigt dass AI bei Kategorisierung/Duration gut ist → aber KEIN Ersatz für deterministische Keyword-Erkennung

## Blast Radius

Alle Eingabewege betroffen (Shared Code in Sources/):
- CreateTaskIntent (Siri/Shortcuts)
- LocalTaskSource.createTask() (Quick Capture)
- SmartTaskEnrichmentService.reanalyzeTask() ("Bestehende Tasks analysieren")
- TaskTitleEngine.improveTitleIfNeeded() (App-Start Batch)

## Fix-Plan

### Datei 1: `Sources/Services/TaskTitleEngine.swift`

**A) `stripKeywords()` erweitern:**
- Importance-Keywords: standalone, (klammer), prefix: — "wichtig", "unwichtig", "important"
- Standalone Urgency: \b-basiertes Stripping für "dringend", "sofort", "eilig", "urgent", "asap"
- Duration-Keywords: `\d+\s*min(uten)?`, `\d+\s*h`, `\d+\s*Stunde(n)?`, `\d+\s*hour(s)?`, `\d+\s*minutes?`, `(\d+\s*min)`

**B) `improveTitleIfNeeded()` erweitern:**
- Importance-Extraktion: "wichtig"/"important" → importance=3, "unwichtig" → importance=1
- Duration-Extraktion: Neue Methode `extractDeterministicDuration()` analog zu `extractDeterministicDueDate()`

### Datei 2: `Sources/Services/SmartTaskEnrichmentService.swift`

**C) `reanalyzeTask()` erweitern:**
- Step 2.5: Deterministic importance extraction (analog urgency in improveTitleIfNeeded)
- Step 2.6: Deterministic duration extraction

## Call-Sites (kein Dead Code)

- `stripKeywords()` → aufgerufen von `LocalTaskSource.createTask()` (Zeile 106) und `cleanTitle()` (Zeile 107)
- `improveTitleIfNeeded()` → aufgerufen von `LocalTaskSource.createTask()` (Zeile 137) und `improveAllPendingTitles()` (Zeile 143)
- `reanalyzeTask()` → aufgerufen von `reanalyzeAllTasks()` (Zeile 101) → Settings-Button

## Tests

73 Tests in `FocusBloxTests/KeywordSystemTests.swift` — 58 RED (fehlende Features), 15 GREEN (Negativ/Boundary).
