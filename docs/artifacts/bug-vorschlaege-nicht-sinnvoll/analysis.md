# Bug #226: Vorschläge nicht sinnvoll — Analyse

## User-Erwartung (User Advocate)

Der User erwartet, dass Vorschläge sich wie ein aufmerksamer Assistent anfühlen:
- Eingeplante Tasks verschwinden **sofort** aus den Vorschlägen
- Ignorierte/abgelehnte Tasks kommen nicht ständig wieder
- Die Vorschläge **rotieren** — nicht immer dieselben
- Lieber 2 gute Vorschläge als 10 generische

**Kern-Frustration:** "Die App weiß nicht was ich tue. Sie schaltet einfach im Kreis."

## Root Causes (4 unabhängige Defekte)

### RC-1: Cache wird in CoachView nicht invalidiert
- **Datei:** `Sources/Views/CoachView.swift`, Zeile ~274
- `addToToday()` ruft `loadAllData()` auf, aber **nicht** `NextUpSuggestionService.invalidateCache()`
- DayView macht es richtig (Zeile 202), CoachView fehlt dieser Aufruf
- **Effekt:** Gerade eingeplanter Task erscheint weiter als Vorschlag

### RC-2: Dismissals sind nicht persistent
- **Datei:** `Sources/Views/CoachView.swift`, Zeile 44
- `dismissedTaskIDs` ist `@State var` — bei App-Neustart leer
- **Effekt:** Abgelehnte Tasks kommen nach jedem App-Start wieder

### RC-3: Filter unvollständig — eingeplante Tasks werden nicht herausgefiltert
- **Datei:** `Sources/Views/CoachView.swift`, Zeile ~214 und `NextUpSuggestionService.swift`, Zeile ~107-113
- Filter prüft nur `!isNextUp`, aber **nicht** `assignedFocusBlockID == nil` und `!isScheduled`
- **Effekt:** Tasks die per Calendar-Drop oder FocusBlock zugewiesen sind, erscheinen weiter als Vorschlag

### RC-4: Deterministisches Scoring ohne Variation
- **Datei:** `Sources/Services/NextUpSuggestionService.swift`, Zeile ~128-138
- Score = `priorityScore × timeAffinity × rescheduleBonus` — rein deterministisch
- **Effekt:** Dieselben Top-Tasks gewinnen jeden Tag, keine Rotation

## Blast Radius

| Datei | Rolle | Plattform |
|-------|-------|-----------|
| `Sources/Services/NextUpSuggestionService.swift` | Kern-Service (Cache, Scoring, Filter) | Beide |
| `Sources/Views/CoachView.swift` | Haupt-Anzeige der Vorschläge | Beide |
| `Sources/Views/DayView.swift` | Morning-Coaching-Sektion | iOS |
| `Sources/Views/MorningCoachingSection.swift` | Zeigt NextUpSuggestion-Liste | Beide |
| `Sources/Intents/OrganizeMyDayIntent.swift` | Siri Shortcut | iOS |

**Bestehende Tests:** `NextUpSuggestionServiceTests.swift` (10 Tests) und `CoachMorningSuggestionTests.swift` (6 Tests) — keiner deckt die identifizierten Defekte ab.

## Empfehlung

**Scope für diesen Bug-Fix (RC-1 + RC-2 + RC-3):**
- Cache-Invalidierung in CoachView → 1 Zeile
- Persistente Dismissals via AppStorage mit Tages-Key → ~15 Zeilen
- Filter erweitern um `isScheduled` und `assignedFocusBlockID` → ~5 Zeilen
- Geschätzt: 2-3 Dateien, ~50-80 LoC

**Separat (RC-4 Scoring-Rotation):** Eigenständiges Feature-Ticket, da Design-Entscheidung nötig.
