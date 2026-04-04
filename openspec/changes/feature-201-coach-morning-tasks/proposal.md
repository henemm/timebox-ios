# FEATURE_201 — Coach Morning: Task-Vorschläge statt Intention-Chips

**GitHub Issue:** #201
**Modus:** ÄNDERUNG

---

## Was und Warum

### Problem
- Intention-Chips ("Was soll heute zählen?") sind zu abstrakt und ähnlich
- Task-Vorschläge nach Intention-Auswahl haben unverständliche Icons (grüner Haken/X)
- Keine Begründung warum ein Task vorgeschlagen wird
- Task-Darstellung weicht vom Backlog-Style ab

### Lösung
- Intention-Picker komplett entfernen
- Direkt konkrete Task-Vorschläge anzeigen (aus NextUpSuggestionService)
- Jeder Vorschlag als BacklogRow + 1-Satz-Begründung
- Swipe rechts → "In heute packen", Swipe links → entfernen

---

## Implementierung (3 Dateien, ~200 LoC)

### 1. `Sources/Services/NextUpSuggestionService.swift` (~30 LoC)

Neue statische Methode `reasonText(for:now:)`:
```swift
static func reasonText(for item: PlanItem, now: Date = Date()) -> String
```
- dueDate innerhalb 48h → "Deadline morgen/übermorgen"
- rescheduleCount >= 3 → "Schon \(count)x verschoben"
- importance == 3 → "Sehr wichtig"
- aiScore > 70 → "Hohe Priorität"
- Fallback: Kategorie ("Guter Zeitpunkt für \(category.localizedName)")

### 2. `Sources/Views/MorningCoachingSection.swift` (~100 LoC Umbau)

Komplett umbauen:
- Header: "Vorschläge für heute" statt "Vorschlaege"
- ForEach über suggestions:
  - BacklogRow(item: suggestion.planItem) — read-only (keine Callbacks)
  - Darunter: `reasonText` in grau/kursiv
  - `.swipeActions(edge: .trailing)` → "Heute" Button (isNextUp = true)
  - `.swipeActions(edge: .leading)` → "Entfernen" Button

### 3. `Sources/Views/CoachView.swift` (~70 LoC Umbau)

- `morningContent`: intentionPickerView entfernen, intentionSetView vereinfachen
- Wenn keine morningSuggestions: "Keine Vorschläge — alles geplant!"
- Wenn morningSuggestions: MorningCoachingSection direkt anzeigen
- `intentionSuggestions` State-Variable entfernen
- IntentionSuggestionService-Aufruf in loadAllData() entfernen
- DayIntention-Logik entfernen (todayIntention, yesterdayIntention, selectIntention)

### Nicht in diesem Issue
- DayIntention SwiftData-Model löschen (separater Cleanup)
- Nudge-Logik anpassen (separates Issue)
- Freie Lücken interaktiv machen (#206)
