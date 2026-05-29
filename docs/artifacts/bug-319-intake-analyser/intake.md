# Bug #319 — Intake Analyser: Strukturierter Intake Report

## Symptom
SmartTaskEnrichmentService generiert für neue Tasks korrekt Wichtigkeit und Dringlichkeit, aber:
- `suggestedDurationMinutes` → `estimatedDuration` wird nicht promoted
- `suggestedTags` → `tags` fehlt komplett in `confirmSuggestions()`
- Tags sind nicht lowercase-normalisiert
- Lernkontext (fetchRecentTaskContext) berücksichtigt abgeschlossene Tasks nicht explizit

## Hennings Anforderungen
1. Dauer und Tags sollen wie Dringlichkeit/Wichtigkeit automatisch aus dem Titel abgeleitet werden
2. Apple Intelligence soll aus bestehenden (inkl. erledigten) Tasks lernen
3. ALLE Tags sollen lowercase sein — neu und bestehend

## Betroffene Dateien
- `Sources/Services/SmartTaskEnrichmentService.swift` (confirmSuggestions-Aufruf, fetchRecentTaskContext)
- `Sources/Models/LocalTask.swift` (confirmSuggestions — Tags-Promotion fehlt)
- Tag-Schreibpfade: TagInputView, LocalTaskSource
