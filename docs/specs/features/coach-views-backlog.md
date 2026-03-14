---
entity_id: coach-views-backlog
type: feature
created: 2026-03-14
updated: 2026-03-14 (v1.1)
status: draft
version: "1.0"
tags: [monster-coach, coach-views, backlog, ranking, discipline]
---

# CoachBacklogView — Eigene Backlog-View im Coach-Modus

## Approval

- [ ] Approved

## Purpose

Wenn der Coach-Modus aktiv ist, zeigt der Backlog-Tab eine eigene View statt der normalen BacklogView. Diese zeigt das Monster oben als Schwerpunkt-Anzeige, darunter eine einzige Task-Liste — passende Tasks werden einfach nach oben gerankt (kein Hard-Filter, keine getrennten Sektionen). Farbige Discipline-Kreise zeigen die Zuordnung. Der Schwerpunkt ist jederzeit transparent durch den Monster-Header erkennbar.

## Gesamtkonzept (uebergreifend)

Coach-Modus = eigene Views, nicht Modifikationen an bestehenden Views.

| Tab | Coach AUS | Coach AN |
|-----|-----------|----------|
| Backlog | BacklogView | **CoachBacklogView** (dieses Ticket) |
| Mein Tag | DailyReviewView | **CoachMeinTagView** (separates Ticket) |
| Blox/Focus | unveraendert | unveraendert |

## Verhaltens-Spezifikation

### 1. View-Umschaltung (MainTabView)

Wenn `coachModeEnabled == true`: Backlog-Tab zeigt `CoachBacklogView` statt `BacklogView`.

```swift
// MainTabView.swift — Backlog-Tab
if coachModeEnabled {
    CoachBacklogView()
} else {
    BacklogView()
}
```

### 2. CoachBacklogView Layout

**Aufbau von oben nach unten:**

1. **Monster-Header** (ca. 120px hoch)
   - Monster-Grafik der aktuellen Intention (z.B. Eule fuer Fokus)
   - Schwerpunkt-Label (z.B. "Fokus — Stolz: nicht verzettelt")
   - Wenn keine Intention gesetzt: Hinweis "Starte deinen Tag unter Mein Tag"
   - accessibilityIdentifier: `"coachMonsterHeader"`

2. **Task-Liste** (zwei Sektionen fuer Transparenz)
   - Passende Tasks (zur Intention) in Sektion "Dein Schwerpunkt" oben
   - Nicht-passende Tasks in Sektion "Weitere Tasks" darunter
   - Jeder Task mit farbigem Discipline-Kreis statt normalem Checkbox
   - Sektions-Header machen den aktiven Filter transparent sichtbar (loest das Kernproblem)
   - accessibilityIdentifier: `"coachTaskList"` (List), `"coachRelevantSection"`, `"coachOtherSection"`

### 3. Ranking-Logik (statt Hard-Filter)

Die bestehende `IntentionOption.matchesFilter()` wird wiederverwendet, aber als **Ranking-Boost** statt als Filter:

```
Alle Tasks → sortiert nach: matchesFilter() == true ZUERST, dann Rest
             Innerhalb beider Gruppen: bestehende Sortierung (Priority-Tier) beibehalten
```

Ergebnis: Passende Tasks stehen in eigener Sektion oben ("Dein Schwerpunkt"), der Rest folgt in "Weitere Tasks". Die Sektions-Header machen transparent, dass und welcher Filter aktiv ist.

**Sonderfaelle:**
- `survival` / `balance` → Normales Ranking, keine Sonderbehandlung noetig (alles eine Liste)
- Keine Intention gesetzt → Alle Tasks in normaler Reihenfolge, Monster-Header zeigt Hinweis "Starte deinen Tag"

### 4. Farbige Discipline-Kreise (Phase 4b)

Der Abhak-Kreis in den Task-Zeilen zeigt die Discipline-Farbe:

**Klassifizierung fuer offene Tasks:**
- `rescheduleCount >= 2` → Konsequenz (gruen)
- `importance == 3` → Mut (orange/rot)
- Sonst → Ausdauer (grau, Default)
- Fokus (blau) erst nach Erledigung bestimmbar

**Visuelle Darstellung:**
- Kreis in Discipline-Farbe statt `Color.secondary`
- Kraeftiger/dicker als der normale Checkbox (lineWidth: 2.5 statt 1.5)
- Bei Tap: Task als erledigt markieren (wie bisher)

### 5. Bestehende Features

CoachBacklogView uebernimmt folgende Features aus BacklogView:
- Task erstellen (+Button)
- Task antippen → EditTaskSheet
- Swipe-Aktionen (bearbeiten, loeschen)
- Suche (Searchbar)
- Pull-to-refresh

CoachBacklogView hat NICHT:
- ViewMode-Picker (priority/recent/overdue/completed/recurring)
- Intention-Filter-Chips (nicht mehr noetig — Ranking ersetzt Filter)
- Overdue-Sektion oben

## Aenderungen an bestehenden Dateien

### MainTabView.swift (~10 LoC)
- Bedingte View-Auswahl: `coachModeEnabled ? CoachBacklogView() : BacklogView()`

### BacklogView.swift (~15 LoC entfernen)
- `intentionFilterOptions` AppStorage bleibt (wird von MorningIntentionView geschrieben)
- `intentionFilterChips` View bleibt (fuer den Fall dass jemand Coach-Modus ausschaltet waehrend Filter aktiv)
- KEINE strukturellen Aenderungen — BacklogView bleibt wie sie ist

### Discipline.swift (~10 LoC)
- Neue Methode `classifyOpen(rescheduleCount:importance:)` — vereinfachte Variante ohne Duration-Parameter fuer offene Tasks

## Neue Datei

### CoachBacklogView.swift (~150-180 LoC)
- Monster-Header mit Intention
- Zwei Sektionen: "Dein Schwerpunkt" + "Weitere Tasks"
- Discipline-farbige Task-Zeilen
- Wiederverwendet BacklogRow oder eigene vereinfachte Row

## Scope

| Metrik | Wert |
|--------|------|
| Dateien geaendert | 2 (MainTabView, Discipline) |
| Dateien neu | 1 (CoachBacklogView) |
| Geschaetzte LoC | ~180-200 |
| Tests geplant | 3-5 UI Tests + 2-3 Unit Tests |

## Test-Plan

### Unit Tests
- `Discipline.classifyOpen()` — Konsequenz bei reschedule>=2, Mut bei importance==3, Default Ausdauer
- Ranking-Logik: matchesFilter teilt Tasks korrekt in zwei Gruppen

### UI Tests
- Coach-Modus AN → CoachBacklogView sichtbar (Monster-Header vorhanden)
- Coach-Modus AUS → normale BacklogView sichtbar (kein Monster-Header)
- Intention gesetzt → passende Tasks erscheinen vor nicht-passenden in der Liste
- Monster-Header zeigt aktuellen Schwerpunkt (Transparenz)
- Discipline-Kreise sichtbar in Task-Zeilen

## Abhaengigkeiten

| Entity | Type | Purpose |
|--------|------|---------|
| Discipline | Model | Farben, classifyOpen() |
| DailyIntention | Model | Aktuelle Intention laden |
| IntentionOption | Enum | matchesFilter() fuer Ranking |
| BacklogRow | View | Task-Zeilen (Wiederverwendung oder Anpassung) |
| MorningIntentionView | View | Schreibt intentionFilterOptions (Input fuer Ranking) |

## Known Limitations

- CoachBacklogView hat keinen ViewMode-Picker — nur eine Ansicht
- Fokus-Discipline erst nach Erledigung bestimmbar (Design-Entscheidung)
- Balance-Intention: Gruppierung nach Kategorie ist vereinfacht (keine Luecken-Erkennung in der View)

## Changelog

- 2026-03-14: Spec erstellt. PO-Entscheidungen: Ranking statt Filter, eigene Views, Phase 4b integriert.
- 2026-03-14 v1.1: Vereinfacht — eine einzige Liste statt zwei Sektionen. Passende Tasks werden nach oben gerankt, keine sichtbare Trennung. Sonderfaelle (survival/balance) ebenfalls vereinfacht.
