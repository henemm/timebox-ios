# Feature-Analyse: AI-Enrichment aus erledigten Tasks (#184)

## User-Erwartung (User Advocate)

Der User tippt einen Task-Titel und bekommt sofort dezente Vorschläge:
- Tag bereits markiert (abwählbar)
- Dauer als Platzhalter (z.B. "20 min", leicht gegraut)
- Priorität voreingestellt

Alles unaufdringlich, wie eine freundliche Ergänzung. Der User hat immer das letzte Wort.

**Wow-Moment:** "Steuern vorbereiten" → App schlägt 90 min + Hoch vor, weil ähnliche Tasks immer so waren.
**Nervt-Moment:** Vorschläge zu langsam oder überschreiben bereits eingegebene Werte.

## Technische Analyse (Feature Planner)

### Bereits vorhanden (#235)
- `SmartTaskEnrichmentService.suggestTagsForTitle()` — Live AI-Call beim Tippen
- `TagInputView` — AI-Vorschlag-Chips mit lila Farbe
- `TaskFormSheet` — 1.5s Debounce für Tag-Suggestions
- `LocalTask.suggestedTags/suggestedDuration/suggestedImportance` — Modell-Felder existieren

### Delta für #184
1. **Erledigte Tasks als Lernbasis:** `fetchRecentTaskContext()` schaut nur auf offene Tasks
2. **Live Dauer-Vorschlag:** `suggestedDuration` wird nur im Batch berechnet, nicht live in TaskFormSheet
3. **Live Wichtigkeit-Vorschlag:** Analog — existiert im Modell, nicht im UI

### Betroffene Dateien (3 Dateien, ~150 LoC)
- `Sources/Services/SmartTaskEnrichmentService.swift` — Erweiterung fetchRecentTaskContext + kombinierter Live-Call
- `Sources/Views/TaskFormSheet.swift` — Debounce erweitern + UI-Hints für Dauer/Wichtigkeit
- `Sources/Services/TaskSources/LocalTaskSource.swift` — ggf. Hilfsmethode für erledigte Tasks

## Scope-Schätzung
- Size: S-M (Erweiterung bestehender Patterns)
- Kein neues Datenmodell nötig
- Ein kombinierter AI-Call statt drei separate
