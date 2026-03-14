---
entity_id: coach-views-meintag
type: feature
created: 2026-03-14
updated: 2026-03-14
status: draft
version: "1.0"
tags: [monster-coach, coach-views, meintag, intention, reflection]
---

# CoachMeinTagView — Eigene "Mein Tag" View im Coach-Modus

## Approval

- [ ] Approved

## Purpose

Wenn der Coach-Modus aktiv ist, zeigt der "Mein Tag"-Tab eine eigene View statt der DailyReviewView. Die Coach-Elemente (MorningIntentionView, EveningReflectionCard) werden nicht mehr in die Review-Statistiken eingebettet, sondern leben in einer eigenen, dafuer konzipierten View.

## Gesamtkonzept

Teil des uebergreifenden Konzepts "Coach-Modus = eigene Views":

| Tab | Coach AUS | Coach AN |
|-----|-----------|----------|
| Backlog | BacklogView | CoachBacklogView (Phase 5a) |
| Mein Tag | DailyReviewView | **CoachMeinTagView** (dieses Ticket) |
| Blox/Focus | unveraendert | unveraendert |

## Verhaltens-Spezifikation

### 1. View-Umschaltung (MainTabView)

Wenn `coachModeEnabled == true`: "Mein Tag"-Tab zeigt `CoachMeinTagView` statt `DailyReviewView`.

```swift
// MainTabView.swift — Review/MeinTag-Tab
if coachModeEnabled {
    CoachMeinTagView()
} else {
    DailyReviewView()
}
```

Tab-Label bleibt dynamisch: "Mein Tag" bei Coach AN, "Review" bei Coach AUS (bereits implementiert).

### 2. CoachMeinTagView Layout

**Aufbau von oben nach unten:**

1. **MorningIntentionView** (bestehende Komponente)
   - Intention setzen oder anzeigen (unveraendert wiederverwendet)
   - Nimmt vollen Platz ein, nicht als kleine Karte in einer Liste

2. **Tages-Fortschritt** (neu, einfach)
   - Kompakte Anzeige: "X Tasks erledigt" bezogen auf die Intention
   - Bei gesetzter Intention: Erfuellungsgrad als visueller Indikator
   - accessibilityIdentifier: `"coachDayProgress"`

3. **EveningReflectionCard** (bestehende Komponente, ab 18 Uhr)
   - Nur sichtbar wenn: `showEveningReflection && DailyIntention.load().isSet`
   - Unveraendert wiederverwendet
   - AI-Texte werden async geladen (bestehende Logik)

4. **Tages-Statistiken** (vereinfacht)
   - Completion-Ring und Kategorie-Balken aus DailyReviewView wiederverwendet
   - Aber unterhalb der Coach-Elemente, nicht darueber

### 3. Was CoachMeinTagView NICHT hat

- Keinen "Heute / Diese Woche" Segmented Picker (nur Tagesansicht)
- Keine Wochen-Statistiken
- Keine Block-Detail-Karten (die sind in der normalen Review-View)

### 4. Was sich an DailyReviewView aendert

Coach-spezifische Elemente werden entfernt:
- `if coachModeEnabled && reviewMode == .today { MorningIntentionView() ... }` → entfernen
- `if showEveningReflection && DailyIntention.load().isSet { EveningReflectionCard(...) }` → entfernen
- `coachModeEnabled` AppStorage wird nicht mehr benoetigt in DailyReviewView
- `navigationTitle` bleibt statisch "Review" (Coach-Fall wird von MainTabView abgefangen)
- `aiReflectionTexts` State kann entfernt werden

## Aenderungen an bestehenden Dateien

### MainTabView.swift (~5 LoC, Erweiterung von Phase 5a)
- Bedingte View-Auswahl fuer Review-Tab: `coachModeEnabled ? CoachMeinTagView() : DailyReviewView()`
- Wenn Phase 5a bereits implementiert: nur den Review-Tab ergaenzen

### DailyReviewView.swift (~20 LoC entfernen)
- Coach-Karten entfernen (MorningIntentionView, EveningReflectionCard Einbettung)
- `coachModeEnabled` AppStorage entfernen
- `aiReflectionTexts` State entfernen
- `navigationTitle` auf statisch "Review" setzen

## Neue Datei

### CoachMeinTagView.swift (~120-150 LoC)
- NavigationStack mit Titel "Mein Tag"
- MorningIntentionView (wiederverwendet)
- Tages-Fortschritt Sektion
- EveningReflectionCard (wiederverwendet, bedingt)
- Vereinfachte Tages-Statistiken
- AI-Text-Loading Logik (aus DailyReviewView uebernommen)

## Scope

| Metrik | Wert |
|--------|------|
| Dateien geaendert | 2 (MainTabView, DailyReviewView) |
| Dateien neu | 1 (CoachMeinTagView) |
| Geschaetzte LoC | ~120-150 (neu) + ~20 (entfernt) |
| Tests geplant | 3-4 UI Tests |

## Test-Plan

### UI Tests
- Coach-Modus AN → "Mein Tag"-Tab zeigt CoachMeinTagView (MorningIntentionView sichtbar)
- Coach-Modus AUS → "Review"-Tab zeigt DailyReviewView (keine MorningIntentionView)
- Intention setzen in CoachMeinTagView → Zusammenfassung erscheint
- EveningReflectionCard erscheint ab 18 Uhr (via `-ForceEveningReflection` Launch-Arg)

## Abhaengigkeiten

| Entity | Type | Purpose |
|--------|------|---------|
| MorningIntentionView | View | Intention setzen/anzeigen (Wiederverwendung) |
| EveningReflectionCard | View | Abend-Spiegel (Wiederverwendung) |
| DailyIntention | Model | Intention laden fuer Fortschritt |
| IntentionEvaluationService | Service | Erfuellungsgrad berechnen |
| EveningReflectionTextService | Service | AI-Texte generieren |
| Phase 5a (CoachBacklogView) | Feature | MainTabView-Aenderung wird erweitert |

## Known Limitations

- Wochen-Ansicht nur in der normalen Review-View verfuegbar
- Tages-Fortschritt ist vereinfacht (kein detailliertes Block-Tracking)
- AI-Text-Loading wird aus DailyReviewView dupliziert (koennte spaeter in eigenen Service extrahiert werden)

## Changelog

- 2026-03-14: Spec erstellt als Teil des Coach-Views Gesamtkonzepts.
