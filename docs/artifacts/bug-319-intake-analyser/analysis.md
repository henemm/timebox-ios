# Bug #319 — Intake Analyser: Analyse

## User-Erwartung (User Advocate)
"Ich tippe einen Task, die App schaut in meine Geschichte und sagt: Das hat 30 Minuten gedauert, das war in Kategorie Finanzen. Und die Felder sind ausgefüllt." Die App denkt nach — und trotzdem sind Dauer und Tags leer. Das fühlt sich an wie ein Assistent der sagt "Das ist dringend!" aber nicht weiß wie lange es dauert.

## Root Causes

### 1. Tags werden nie übernommen (Hauptbug)
`confirmSuggestions()` in `LocalTask.swift:340-361` promoted ALLE suggested-Felder auf Hauptfelder — aber `suggestedTags → tags` fehlt komplett. Die KI befüllt `suggestedTags` korrekt, aber es gibt keinen Schritt der sie in `task.tags` transferiert.

### 2. Batch-Enrichment ruft confirmSuggestions() nie auf
Im Batch-Pfad (`enrichAllTbdTasks → performEnrichment`) wird `confirmSuggestions()` nie aufgerufen. `suggestedDuration` bleibt dauerhaft im Staging-Feld, `estimatedDuration` bleibt nil.

### 3. Tags nicht lowercase — 9 Schreibpfade ohne Normalisierung
`TagInputView.addCurrentTag()` (Zeile 133), `LocalTaskSource.createTask()` (Zeile 119), `LocalTaskSource.updateTask()` (Zeile 202) und 6 weitere Stellen speichern Tags ohne `.lowercased()`. Nur AI-Vorschläge in `filterTagSuggestions()` werden normalisiert — manuell eingetippte nie.

### 4. Quick Capture hat keinen Enrichment-Aufruf
`QuickCaptureView.createTask()` erstellt Tasks ohne SmartTaskEnrichmentService — weder Live- noch Batch-Enrichment. Tasks aus Quick Capture bleiben immer ohne KI-Attribute.

### 5. fetchRecentTaskContext: bereits gut, aber ausbaubar
Die Methode hat keinen `isCompleted`-Filter — sie bezieht bereits alle Tasks ein (offen + erledigt). Limit: 30 Tasks mit Attributen. Tags aus dem Kontext werden an den AI-Prompt übergeben.

## Betroffene Dateien
- `Sources/Models/LocalTask.swift` — confirmSuggestions() Tags-Promotion fehlt
- `Sources/Services/SmartTaskEnrichmentService.swift` — Batch-Pfad ruft confirmSuggestions() nicht auf; fetchRecentTaskContext Limit
- `Sources/Views/TagInputView.swift` — lowercase fehlt
- `Sources/Services/TaskSources/LocalTaskSource.swift` — lowercase fehlt in create/update

## Scope
4 Dateien, ~40-60 LoC + einmalige Tag-Migration
