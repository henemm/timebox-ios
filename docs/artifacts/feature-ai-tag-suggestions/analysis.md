# Feature #235: AI schlägt Tags vor beim Task-Erstellen — Analyse

## User-Erwartung (User Advocate)

Der User tippt einen Task-Titel, nach kurzer Pause (1-2 Sekunden) erscheinen dezente Pill-Chips mit Tag-Vorschlägen darunter. Ein Tipp genügt — Tag gesetzt. Nochmal tippen — Tag wieder weg. Ignorieren ist jederzeit möglich, kein Zwang.

**Kernerwartungen:**
- Vorschläge müssen passen ("Rasen mähen" → #garten, NICHT #computer)
- Kein Flackern beim Tippen, Debounce nach Pause
- Gross genug zum Antippen
- Lieber keine Vorschläge als schlechte

**Mögliche Verwirrungen:**
- Neuer Tag-Vorschlag vs. bestehender Tag nicht unterscheidbar
- Basis-Set bei neuen Usern könnte "fremd" wirken
- Zu spätes Erscheinen enttäuscht

## Technische Analyse (Feature Planner)

**Bestehende Systeme die wir nutzen:**
- `TagInputView` — bereits Chips, Autocomplete, FlowLayout vorhanden
- `SmartTaskEnrichmentService` — neues `suggestTagsForTitle()` (leichtgewichtig, getrennt vom post-save Enrichment)
- `LocalTaskSource.fetchAllUsedTags()` — liefert User-Tags sortiert nach Häufigkeit
- `TaskFormSheet` — aktiver Task-Erstellen-Flow

**Betroffene Dateien (4):**
1. `SmartTaskEnrichmentService` — neue Methode `suggestTagsForTitle()`
2. `TagInputView` — optionaler `aiSuggestions` Parameter
3. `TaskFormSheet` — debounced Aufruf bei Titeländerung
4. Tests

**Kein neues DB-Feld nötig** — suggestedTags leben nur im View-State.

**Scope:** ~200 LoC, 4 Dateien — passt in Limits.

## Scope-Schätzung

- Size: S-M
- Dateien: 4 (+Tests)
- LoC: ~200
- Plattform: iOS + macOS (TagInputView ist shared)
