# Feature-Analyse: KI-gestützte Task-Ideen beim Erstellen (#199)

## User-Erwartung (User Advocate)

**Kerngefühl:** "Oh stimmt, das hatte ich vergessen" — wie ein Kollege, der neugierig fragt "hast du auch an X gedacht?"

- Vorschläge erscheinen beiläufig, nicht aufdringlich — wie Haftnotizen
- Antippen = sofort als eigenständiger Task übernommen, ohne Rückfrage
- Ignorieren = kein Problem, kein "Nag"-Effekt
- Vorschläge müssen kontextbezogen sein, nicht generisch ("Strategie überprüfen" = Spam)
- Bereich darf nicht den eigentlichen Task-Erstellungsprozess stören

**Mögliche Frustrationen:**
- Generische, irrelevante Vorschläge → fühlt sich wie Werbung an
- Jeden Tag dieselben Vorschläge → nervt
- Unklar ob Antippen = gespeichert oder nur ins Feld kopiert
- Zu viel Platz → stört beim eigentlichen Task-Erstellen

## Technische Analyse (Feature Planner)

**Pattern-Vorlage:** `IntentionSuggestionService` — 1:1 übertragbar (FoundationModels, Generable, Fallback)

**Betroffene Dateien:**

| Datei | Änderung | LoC |
|-------|----------|-----|
| `Sources/Services/TaskIdeaSuggestionService.swift` | NEU — Service analog IntentionSuggestionService | +120 |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | Neuer Section + State + `.task {}` | +50 |
| `Sources/Models/AppSettings.swift` | 1 neue @AppStorage-Property | +4 |
| `Sources/Views/SettingsView.swift` | 1 neuer Toggle in AI-Sektion | +8 |
| Tests | Unit + UI Tests | +60 |

**Gesamt:** ~242 LoC, 5 Dateien — im Scope-Limit.

**Bestehende Patterns:**
- `TaskSuggestionService.fetchAllTasks()` für Kontext-Daten
- `AppSettings` + `SettingsView` für Toggle-Pattern
- `CreateTaskView` bereits mit Suggestion-Bereich

**Risiken:**
- Prompt-Qualität entscheidend (konkrete Tasks, nicht generisch)
- Ladezeit 1-3s → ProgressView nötig
- Kontext-Budget begrenzen (max 10-15 Tasks)
- macOS-Parität automatisch gegeben (shared View)

## Scope-Schätzung
- **Größe:** M (mittel)
- **Dateien:** 5 (knapp am Limit)
- **LoC:** ~242 (knapp am Limit)
