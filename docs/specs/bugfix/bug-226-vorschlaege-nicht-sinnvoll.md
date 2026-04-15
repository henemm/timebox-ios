---
entity_id: bug_226_vorschlaege_nicht_sinnvoll
type: bugfix
created: 2026-04-15
updated: 2026-04-15
status: draft
version: "2.0"
tags: [coach, suggestions, nextup, ai, tags]
---

# Bug #226: Vorschläge nicht sinnvoll — Feature-Überarbeitung

## Approval

- [ ] Approved

## Problem

Vorschläge im Coach-Tab liefern keinen Mehrwert:
1. Wiederholen sich ständig (auch für bereits eingeplante Tasks)
2. Keine Intelligenz — einfach Top-N nach Priorität
3. Nutzen weder Energy-Level, Kapazität, Tags noch Kalender-Kontext
4. Tags werden von der AI-Enrichment-Engine ignoriert und im Coach nicht genutzt

## Scope: Bugs fixen + Stufe 1 + Stufe 2 + Tag-Integration

### Teil A: Bugs fixen (RC-1 bis RC-3)

#### RC-1: Cache wird in CoachView nicht invalidiert
- **Datei:** `Sources/Views/CoachView.swift:274`
- `addToToday()` ruft nicht `NextUpSuggestionService.invalidateCache()` auf
- **Fix:** 1 Zeile — Pattern wie `DayView.swift:202`

#### RC-2: Dismissals sind nicht persistent
- **Datei:** `Sources/Views/CoachView.swift:44`
- `dismissedTaskIDs` ist `@State` — bei App-Neustart leer
- **Fix:** `@AppStorage` mit Tages-Key (`dismissedSuggestions_YYYY-MM-dd`), JSON-codiert
- Abgelehnte Tasks kommen frühestens nach 3 Tagen wieder (nicht am nächsten Tag)

#### RC-3: Filter unvollständig
- **Dateien:** `CoachView.swift:214` + `NextUpSuggestionService.swift:68-74, 107-113`
- Filter prüft nur `!isNextUp`, nicht `isScheduled` / `assignedFocusBlockID`
- **Fix:** Filter erweitern um `!item.isScheduled && item.assignedFocusBlockID == nil`

### Teil B: Intelligentere Vorschläge (Stufe 1)

#### B1: Energy-Matching
- **Datei:** `NextUpSuggestionService.swift` (Score-Funktion)
- Morgens (vor morningEndHour): Tasks mit `aiEnergyLevel == "high"` bevorzugen
- Nachmittags: Tasks mit `aiEnergyLevel == "low"` bevorzugen
- Bonus-Faktor im Scoring: 1.3× bei Match, 0.8× bei Mismatch

#### B2: Kapazitäts-Limit
- **Datei:** `NextUpSuggestionService.swift` (maxSuggestions)
- `BehavioralProfile.avgTasksPerDay` nutzen statt fester 5/4/3
- Formel: `min(avgTasksPerDay - alreadyPlannedToday, maxForLoad)`
- Wenn User typisch 4 Tasks/Tag schafft und 3 schon geplant hat → 1 Vorschlag

#### B3: Persistente Dismissals mit Cooldown
- Abgelehnte Tasks: 3-Tage-Cooldown (nicht sofort am nächsten Tag wieder)
- Datenstruktur: `[taskID: lastDismissedDate]` in `@AppStorage`
- Filter: Task nur vorschlagen wenn `lastDismissed + 3 Tage < heute`

### Teil C: AI-Begründungen (Stufe 2)

#### C1: Natürliche Begründung pro Vorschlag
- **Datei:** Neuer Service oder Erweiterung von `NextUpSuggestionService`
- Apple Intelligence generiert einen Satz warum dieser Task jetzt passt
- Input-Kontext: Freie Zeit, Tageszeit, Energy-Level, Meeting-Dichte, Tags, Kalender
- Beispiele:
  - "Du hast 45 Minuten frei und erledigst Code-Tasks am liebsten morgens"
  - "3× verschoben — heute nur 15 Min, perfekt für die Lücke vor dem Meeting"
  - "Drei #garten Tasks offen — bündle sie in einem Rutsch"
- Fallback ohne AI: Bestehende `reasonText()` Logik (deterministisch)

### Teil D: Tag-Integration

#### D1: AI schlägt Tags vor (SmartTaskEnrichmentService)
- **Datei:** `Sources/Services/SmartTaskEnrichmentService.swift`
- `TaskEnrichment` um `suggestedTags: [String]` erweitern (max. 3)
- AI bekommt Kontext der **bestehenden Tags** des Users (letzte 90 Tage) → schlägt nur bekannte oder sehr naheliegende Tags vor
- Vorsichtig: Nur vorschlagen, nicht automatisch setzen — User bestätigt im TaskForm

#### D2: Coach bündelt nach Tags
- **Datei:** `Sources/Views/CoachView.swift` (morningContent)
- Wenn 2+ Vorschlags-Tasks denselben Tag haben → als Gruppe anzeigen
- Beispiel: "3 Aufgaben mit #computer — erledige sie in einem Rutsch"
- Gruppierung hat Vorrang vor Einzeldarstellung bei ≥2 Tasks mit gleichem Tag

#### D3: Tag-Affinität im Scoring
- **Datei:** `NextUpSuggestionService.swift`
- Bonus wenn mehrere Tasks denselben Tag teilen → Bündelungs-Anreiz
- Leichter Bonus (1.15×) damit Tags die Priorität nicht übersteuern

### Teil E: Tag-Onboarding für neue User

#### E1: Basis-Set als Seed
- Vordefinierte Kontext-Tags: `#computer`, `#telefon`, `#unterwegs`, `#zuhause`, `#einkauf`
- Gespeichert als statische Liste in `NextUpSuggestionService` oder eigener `TagSeedService`
- Werden der AI als "bekannte Tags" mitgegeben, auch wenn der User noch keine eigenen hat

#### E2: AI darf neue Tags vorschlagen
- Wenn der Task-Titel einen klaren Kontext hat (z.B. "Rasen mähen"), darf die AI einen neuen Tag vorschlagen (#garten), auch wenn er nicht im Seed-Set ist
- Constraint: Max 1 neuer Tag pro Enrichment (nicht 3 unbekannte auf einmal)
- Neue Tags vom User bestätigt → fließen in den Tag-Pool für zukünftige Vorschläge

#### E3: Kein erzwungenes Onboarding
- Kein Modal, kein Setup-Wizard — Tags erscheinen natürlich als Vorschläge im TaskForm
- User sieht beim ersten Task: "Vorgeschlagene Tags: #computer, #zuhause" und kann tippen oder ignorieren
- Das Seed-Set wird nur als AI-Kontext genutzt, nie automatisch gesetzt

## Affected Files

| Datei | Änderung |
|-------|----------|
| `Sources/Views/CoachView.swift` | RC-1 + RC-2 + RC-3 + Tag-Gruppierung (D2) |
| `Sources/Services/NextUpSuggestionService.swift` | RC-3 + Energy-Match (B1) + Kapazität (B2) + Tag-Scoring (D3) |
| `Sources/Services/SmartTaskEnrichmentService.swift` | Tag-Vorschläge (D1) |
| `Tests/NextUpSuggestionServiceTests.swift` | Tests für RC-3, B1, B2, D3 |
| `Tests/SmartTaskEnrichmentServiceTests.swift` | Tests für D1 |
| `Tests/FocusBloxUITests/CoachSuggestionUITests.swift` | UI Tests für Tag-Gruppierung + Dismissal |

## Expected Behavior (nach Fix)

1. Eingeplanter Task → verschwindet **sofort** aus Vorschlägen
2. Ausgeblendeter Task → kommt frühestens in **3 Tagen** wieder
3. Tasks auf Timeline/in FocusBlock → erscheinen **nicht** als Vorschlag
4. Morgens → bevorzugt Tiefenarbeit-Tasks, nachmittags → Routine
5. Anzahl Vorschläge passt zur realistischen Tages-Kapazität
6. Jeder Vorschlag hat einen **natürlichen Satz** warum er passt (AI) oder eine Kategorie-Begründung (Fallback)
7. Tasks mit gleichen Tags → als **Gruppe** gebündelt ("3× #computer")
8. Neue Tasks bekommen vorsichtige **Tag-Vorschläge** von der AI

## Out of Scope

- RC-4 (randomisiertes Scoring für Variation) → separates Ticket
- Lern-Feedback-Loop (Stufe 3: Annahme/Ablehnung fließt zurück) → separates Ticket
- Automatisches Tag-Setzen ohne User-Bestätigung

## Changelog

- 2026-04-15: v1.0 — Initial spec (nur Bugs)
- 2026-04-15: v2.0 — Erweitert um Stufe 1+2 + Tag-Integration
