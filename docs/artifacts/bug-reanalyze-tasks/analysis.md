# Bug-Analyse: "Bestehende Tasks analysieren" tut nichts

## Bug-Beschreibung
Button in Einstellungen > "Bestehende Tasks analysieren" wird gedrückt, aber bestehende Tasks werden nicht mit dem neuen Regelwerk (Datums-Keywords + KI) überarbeitet.

## Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check)
- 4 vorherige Enrichment-Fixes, alle fokussiert auf **Creation-Paths** (nicht Batch-Button)
- Bekannte Architektur: Zwei parallele Services (SmartTaskEnrichmentService + TaskTitleEngine)
- `improveTitleIfNeeded()` hat Guard auf `needsTitleImprovement` — bei bestehenden Tasks `false`

### Agent 2 (Datenfluss-Trace)
- Button → `reanalyzeAllTasks()` → `performFullReanalysis()` (4-Schritt-Pipeline)
- Pipeline: cleanTitle → Date-Extraction → AI-Enrichment → Category/Duration
- Flow ist strukturell korrekt nach Korrektur

### Agent 3 (Alle Schreiber)
- `suggestedDuration` und `suggestedCategory` werden NUR von `TaskTitleEngine.enrichWithSuggestions()` geschrieben
- 30+ Schreibstellen insgesamt, 4 Hauptquellen (UI, Sync, AI-Services, Integration Points)
- `confirmSuggestions()` appliziert Suggestions → hat Guard auf `lifecycleStatus == raw`

### Agent 4 (Szenarien)
- 12 Szenarien identifiziert in denen Button "nichts tut"
- Kritischste: Tasks mit allen Attributen → 0 aktualisiert, Silent AI-Failures
- `reanalyzeAllTasks()` hat keinen `aiScoringEnabled`-Guard (aber Button nur sichtbar wenn Toggle ON)

### Agent 5 (Blast Radius)
- Keine UI Tests für `batchEnrichButton`
- App-Start nutzt `enrichAllTbdTasks()` (Fire & Forget) — nicht betroffen
- macOS bereits identisch geändert
- BacklogView + ContentView nutzen `enrichAllTbdTasks()` für CloudKit-Sync — nicht betroffen

## Hypothesen

### Hypothese 1: `enrichAllTbdTasks()` ruft TaskTitleEngine nie auf (HOCH)
**Beweis dafür:** Code-Analyse bestätigt — `performBatchEnrichment()` ruft nur `performEnrichment()` auf, nie `TaskTitleEngine.cleanTitle()`, `stripKeywords()`, oder `extractDeterministicDueDate()`.
**Beweis dagegen:** Keiner — der Code ist eindeutig.
**Wahrscheinlichkeit:** HOCH — das ist die primäre Root Cause für das Original-Problem.

### Hypothese 2: `improveTitleIfNeeded()` Guard blockiert Suggestions (HOCH)
**Beweis dafür:** `TaskTitleEngine.swift:239` — `guard task.needsTitleImprovement else { return }`. Bei bestehenden Tasks ist `needsTitleImprovement = false`, also werden `suggestedCategory`/`suggestedDuration` NIE gesetzt.
**Beweis dagegen:** Keiner.
**Wahrscheinlichkeit:** HOCH.

### Hypothese 3: Suggestions werden nie in Hauptfelder promoted (HOCH)
**Beweis dafür:** `confirmSuggestions()` hat Guard `lifecycleStatus == raw` (LocalTask.swift:297). Bestehende Tasks haben Status `active`. Selbst wenn H2 gefixt wird und Suggestions gesetzt werden, landen sie nie in `taskType`/`estimatedDuration`.
**Beweis dagegen:** Keiner.
**Wahrscheinlichkeit:** HOCH — Suggestion-Felder sind Staging-Felder, nicht sichtbar im UI.

### Hypothese 4: Counter lügt (MITTEL)
**Beweis dafür:** Im ersten Fix-Versuch setzte `changed = true` nach dem `improveTitleIfNeeded()`-Aufruf, obwohl der Guard sofort returnte. Der Counter zeigte "X aktualisiert" obwohl nichts passiert war.
**Status:** Gefixt — `changed = true` wird jetzt nur gesetzt wenn `needsCategoryOrDuration` true ist, und `enrichCategoryAndDuration()` schreibt direkt auf Hauptfelder.

### Hypothese 5: Section-Name "Apple Intelligence" verwirrt User (NIEDRIG)
**Status:** Gefixt — umbenannt zu "Automatische Task-Analyse".

## Challenge-Ergebnis (Devil's Advocate)

**Verdict: LÜCKEN → nach Korrektur SOLIDE**

Kritische Lücken die korrigiert wurden:
1. ~~`improveTitleIfNeeded()` Guard macht Step 4 zu Dead Code~~ → Ersetzt durch `enrichCategoryAndDuration()` die direkt auf Hauptfelder schreibt
2. ~~Suggestions werden nie promoted~~ → Umgangen durch direktes Schreiben auf `taskType`/`estimatedDuration`
3. ~~Counter lügt~~ → Korrigiert durch korrekte `changed`-Flag-Logik

## Fix-Implementierung

### Ansatz
Neue Methode `enrichCategoryAndDuration()` in SmartTaskEnrichmentService die:
- Direkt auf `task.taskType` und `task.estimatedDuration` schreibt (nicht auf Suggestion-Felder)
- Keinen `needsTitleImprovement`-Guard hat
- Nur aufgerufen wird wenn `taskType.isEmpty || estimatedDuration == nil`

### Geänderte Dateien
1. `Sources/Services/SmartTaskEnrichmentService.swift` — `reanalyzeAllTasks()` + `performFullReanalysis()` + `enrichCategoryAndDuration()`
2. `Sources/Views/SettingsView.swift` — Button ruft `reanalyzeAllTasks()`, Section "Automatische Task-Analyse"
3. `FocusBloxMac/MacSettingsView.swift` — identische Änderungen

### Pipeline (4 Steps)
1. **Title Cleanup** (deterministisch): Entfernt Datums-Keywords, Urgency-Keywords, Intro-Phrasen
2. **Date Extraction** (deterministisch): Extrahiert dueDate aus originalem Titel
3. **AI Enrichment** (KI): Setzt importance, urgency, taskType, aiEnergyLevel (nur wenn nil/leer)
4. **Category + Duration** (KI): Setzt taskType, estimatedDuration direkt (nur wenn leer/nil)

## Blast Radius
- App-Start-Flows nicht betroffen (nutzen `enrichAllTbdTasks()` + `improveAllPendingTitles()`)
- CloudKit-Sync nicht betroffen (nutzt `enrichAllTbdTasks()`)
- Keine bestehenden UI Tests für den Button → müssen geschrieben werden
- Beide Plattformen (iOS + macOS) geändert und getestet
