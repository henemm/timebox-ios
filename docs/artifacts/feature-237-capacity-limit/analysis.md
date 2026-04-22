# Feature-Analyse: Kapazitäts-Limit für Vorschläge (#237)

## User-Erwartung
- App soll nicht immer 5 Vorschläge zeigen wenn nur Platz für 1 ist
- Transparenz: Warum weniger Vorschläge? ("Du schaffst typisch 4/Tag, 3 geplant → 1 Platz")
- Kein Blockieren — Warnung/Info, aber User entscheidet selbst
- Fallback für neue User (<5 aktive Tage): feste Werte

## Technische Analyse
- BehavioralProfile.avgTasksPerDay existiert bereits (Zeile 45)
- NextUpSuggestionService.compute() bestimmt Vorschläge — aktuell feste Limits pro Tagesphase
- alreadyPlannedToday = items.filter { isNextUp && !isCompleted }.count
- Formel: maxSuggestions = max(0, avgTasksPerDay - alreadyPlannedToday)
- Fallback wenn Profil dünn (<5 Tage): bestehende feste Werte

## Scope: 2 Dateien, ~40 LoC
1. NextUpSuggestionService.swift — maxSuggestionsForLoad() + Aufruf in compute()
2. NextUpSuggestionServiceTests.swift — Tests
