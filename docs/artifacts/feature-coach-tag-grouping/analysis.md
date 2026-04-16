# Feature-Analyse: Coach bündelt Vorschläge nach Tags (#236)

## User-Erwartung (User Advocate)

- Morgens zeigt der Coach eine gemischte Liste: Einzelvorschläge wie bisher + neue Gruppen-Karten für Tasks mit gleichem Tag
- Gruppe kommuniziert klar WARUM gebündelt ("3 Aufgaben mit #computer")
- Der Hinweis "in einem Rutsch erledigen" motiviert, spart Kontext-Wechsel
- Gruppe fühlt sich wie hilfreicher Vorschlag an, nicht wie Pflichtpaket
- Fallstricke: Erzwingen vs. Vorschlagen, zu viele Gruppen, unklare Tag-Bedeutung

## Technische Analyse (Feature Planner)

### Aktueller Zustand
- `morningContent` (CoachView:227-252) gruppiert Tasks bereits nach Grund-Kategorie via `groupTasksByReason` (deadline, stuck, important...)
- `tagClusterBonus` (NextUpSuggestionService:319-329) gibt Tags-Gruppen 1.15x Scoring-Bonus — aber nur fürs Ranking, nicht für die Darstellung

### Delta
- VOR der reason-basierten Gruppierung: Tag-Cluster-Erkennung
- Tasks mit >=2 gemeinsamen Tags werden als eigene Gruppe herausgezogen
- Spezifischer Coach-Text: "X Aufgaben mit #tag — erledige sie in einem Rutsch"
- Rest läuft wie bisher durch `groupTasksByReason`

### Betroffene Dateien
- `Sources/Views/CoachView.swift` — Tag-Gruppierungslogik + Darstellung (~55 LoC)
- Optional: `Sources/Services/NextUpSuggestionService.swift` — Tag-Info exponieren (~15 LoC)

### Scope
- 1-2 Dateien, ~55-70 LoC — klar im Rahmen
