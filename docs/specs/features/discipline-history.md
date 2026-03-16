---
entity_id: discipline-history
type: feature
created: 2026-03-16
updated: 2026-03-16
status: draft
version: "1.0"
tags: [coach, discipline, stats, visualization]
---

# Disziplin-Entwicklung sichtbar machen (Phase 1)

## Approval

- [ ] Approved

## Purpose

Zeigt dem User in der "Mein Tag"-View (Coach-Modus) wie sich seine erledigten Tasks auf die 4 Disziplinen verteilen — heute und diese Woche. Damit wird das Erfolgskriterium "Ich sehe ueber die Zeit an welchen Disziplinen ich gewachsen bin" aus der Monster Coach User Story adressiert.

Phase 1 liefert den Wochen/Tages-Breakdown. Phase 2 (separates Ticket) wuerde Multi-Wochen-Trends mit Swift Charts ergaenzen.

## User Story Referenz

`docs/project/stories/monster-coach.md` — Erfolgskriterium:
> "Ich sehe ueber die Zeit an welchen Disziplinen ich gewachsen bin"

## Scope

- **Files:** 5 (2 CREATE, 3 MODIFY)
- **Estimated LoC:** ~180 neue Zeilen
- **Risk:** LOW (rein additiv, keine bestehende Logik geaendert, keine Schema-Aenderung)
- **Plattform:** iOS + macOS (shared View in Sources/)

## Source

### Neue Dateien

- **File:** `Sources/Services/DisciplineStatsService.swift`
- **Identifier:** `enum DisciplineStatsService`

### Geaenderte Dateien

- **File:** `Sources/Views/ReviewComponents.swift` — neue Typen `DisciplineStat`, `DisciplineBar`
- **File:** `Sources/Views/CoachMeinTagView.swift` — neue Section `disciplineBreakdownSection`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Discipline` | Model (enum) | `classify()` fuer completed Tasks, `resolveOpen()` fuer Manual Override |
| `LocalTask` | Model (SwiftData) | Datenquelle: `completedAt`, `rescheduleCount`, `importance`, `estimatedDuration`, `manualDiscipline` |
| `IntentionEvaluationService` | Service | `completedToday()`, `completedThisWeek()` — Filter completed Tasks nach Zeitraum |
| `CoachMeinTagView` | View (shared) | Integrationsort: Discipline-Section in Heute + Woche Ansicht |
| `ReviewComponents` | View Components | Bestehende `CategoryBar` als Pattern-Vorbild |

## Implementation Details

### 1. DisciplineStatsService (~40 LoC)

```swift
// Sources/Services/DisciplineStatsService.swift
enum DisciplineStatsService {

    /// Berechnet Discipline-Verteilung fuer eine Liste von Tasks.
    /// Nur completed Tasks (completedAt != nil) werden gezaehlt.
    /// Manual Override hat Vorrang vor Auto-Klassifikation.
    static func breakdown(for tasks: [LocalTask]) -> [DisciplineStat] {
        let completed = tasks.filter { $0.isCompleted && $0.completedAt != nil }
        var counts: [Discipline: Int] = [:]
        for d in Discipline.allCases { counts[d] = 0 }

        for task in completed {
            let discipline = resolveDiscipline(for: task)
            counts[discipline, default: 0] += 1
        }

        let total = completed.count
        return Discipline.allCases.map { d in
            DisciplineStat(discipline: d, count: counts[d] ?? 0, total: total)
        }
        .sorted { $0.count > $1.count }
    }

    /// Resolve discipline fuer einen completed Task.
    /// 1. Manual Override (manualDiscipline)
    /// 2. classify() mit allen Feldern
    private static func resolveDiscipline(for task: LocalTask) -> Discipline {
        if let manual = task.manualDiscipline,
           let discipline = Discipline(rawValue: manual) {
            return discipline
        }
        return Discipline.classify(
            rescheduleCount: task.rescheduleCount,
            importance: task.importance,
            effectiveDuration: task.effectiveDuration ?? 0,
            estimatedDuration: task.estimatedDuration
        )
    }
}
```

### 2. DisciplineStat + DisciplineBar (~35 LoC in ReviewComponents.swift)

```swift
// In ReviewComponents.swift

/// Disziplin-Statistik fuer Visualization
struct DisciplineStat: Identifiable {
    let discipline: Discipline
    let count: Int
    let total: Int
    var id: String { discipline.rawValue }
}

/// Visueller Balken fuer eine Disziplin (analog CategoryBar)
struct DisciplineBar: View {
    let stat: DisciplineStat

    private var percentage: CGFloat {
        guard stat.total > 0 else { return 0 }
        return CGFloat(stat.count) / CGFloat(stat.total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(stat.discipline.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                Text(stat.discipline.displayName)
                    .font(.subheadline)
                Spacer()
                Text("\(stat.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stat.discipline.color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stat.discipline.color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .animation(.spring(), value: percentage)
                }
            }
            .frame(height: 8)
        }
        .accessibilityIdentifier("disciplineBar_\(stat.discipline.rawValue)")
    }
}
```

### 3. CoachMeinTagView Integration (~40 LoC)

```swift
// In CoachMeinTagView.swift — neue computed properties + Section

private var todayDisciplineStats: [DisciplineStat] {
    let todayTasks = IntentionEvaluationService.completedToday(allLocalTasks)
    return DisciplineStatsService.breakdown(for: todayTasks)
}

private var weekDisciplineStats: [DisciplineStat] {
    let weekTasks = IntentionEvaluationService.completedThisWeek(allLocalTasks)
    return DisciplineStatsService.breakdown(for: weekTasks)
}

// In content body, nach weekProgressSection (Woche) bzw. nach EveningReflectionCard (Heute):
private func disciplineBreakdownSection(stats: [DisciplineStat]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Dein Disziplin-Profil")
            .font(.headline)
            .accessibilityIdentifier("disciplineProfileHeader")

        if stats.allSatisfy({ $0.count == 0 }) {
            Text("Noch keine Tasks erledigt")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("disciplineEmptyState")
        } else {
            ForEach(stats) { stat in
                DisciplineBar(stat: stat)
            }
        }
    }
    .padding()
    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
}
```

**Integration in content body:**
- `case .today:` → `disciplineBreakdownSection(stats: todayDisciplineStats)` nach EveningReflectionCard
- `case .week:` → `disciplineBreakdownSection(stats: weekDisciplineStats)` nach weeklyReflectionSection

## Expected Behavior

### Input
- User hat Coach-Modus aktiviert und oeffnet "Mein Tag"-Tab
- Es existieren erledigte Tasks (mit `completedAt` heute/diese Woche)

### Output
- **Heute-Ansicht:** 4 farbige Balken zeigen Disziplin-Verteilung der heute erledigten Tasks
- **Wochen-Ansicht:** 4 farbige Balken zeigen Disziplin-Verteilung der diese Woche erledigten Tasks
- Balken sortiert nach Anzahl (hoechste zuerst)
- Jeder Balken: Monster-Bild (24x24) + Disziplin-Name + Count + Prozent-Balken in Disziplin-Farbe
- Bei 0 erledigten Tasks: "Noch keine Tasks erledigt" Platzhalter

### Side Effects
- Keine — rein lesende Auswertung bestehender Daten

### Beispiel-Szenario
User hat diese Woche 10 Tasks erledigt:
- 3x aufgeschoben (rescheduleCount >= 2) → Konsequenz (gruen)
- 2x importance=3 → Mut (rot)
- 2x innerhalb Schaetzung → Fokus (blau)
- 3x default → Ausdauer (grau)

Anzeige:
```
Dein Disziplin-Profil
[Troll 24x24] Konsequenz    3  ████████████░░░░ (30%)
[Golem 24x24] Ausdauer      3  ████████████░░░░ (30%)
[Feuer 24x24] Mut           2  ████████░░░░░░░░ (20%)
[Eule  24x24] Fokus         2  ████████░░░░░░░░ (20%)
```

## Accessibility Identifiers

| Element | Identifier | Typ |
|---------|-----------|-----|
| Section Header | `disciplineProfileHeader` | Text |
| Discipline Bar (pro Disziplin) | `disciplineBar_konsequenz` / `_ausdauer` / `_mut` / `_fokus` | VStack |
| Empty State | `disciplineEmptyState` | Text |

## Test Plan

### Unit Tests (DisciplineStatsServiceTests.swift)

| Test | Beschreibung |
|------|-------------|
| `test_breakdown_emptyList_returnsAllZeroCounts` | Leere Task-Liste → 4 DisciplineStats mit count=0 |
| `test_breakdown_mixedTasks_correctDistribution` | 10 Tasks mit verschiedenen Eigenschaften → korrekte Verteilung |
| `test_breakdown_manualOverride_takesPrecedence` | Task mit manualDiscipline="mut" aber rescheduleCount>=2 → zaehlt als Mut |
| `test_breakdown_onlyCompletedTasksCounted` | Offene Tasks werden ignoriert |
| `test_breakdown_sortedByCountDescending` | Ergebnis sortiert: hoechster Count zuerst |
| `test_breakdown_fokusClassification` | Task mit effectiveDuration <= estimatedDuration → Fokus |

### UI Tests (DisciplineHistoryUITests.swift)

| Test | Beschreibung |
|------|-------------|
| `test_coachMeinTag_weekView_showsDisciplineProfile` | Wochenansicht zeigt "Dein Disziplin-Profil" Header |
| `test_disciplineProfile_showsFourBars` | Alle 4 DisciplineBar-Elemente sichtbar |
| `test_disciplineProfile_emptyState` | Ohne erledigte Tasks: Platzhalter-Text sichtbar |

## Known Limitations

- **Phase 1 nur Snapshot**: Zeigt nur aktuelle Woche/heute — kein Multi-Wochen-Trend (→ Phase 2)
- **Keine Persistierung**: Discipline-Stats werden live berechnet, nicht gespeichert. Bei grosser Task-Menge koennte Berechnung kurz dauern.
- **effectiveDuration fehlt manchmal**: Tasks die per Checkbox erledigt werden (nicht im Sprint) haben keine effectiveDuration → Fokus-Klassifikation nicht moeglich, Fallback zu Ausdauer
- **Nur im Coach-Modus**: DisciplineProfile erscheint nur in CoachMeinTagView, nicht in der Standard-DailyReviewView

## Future Work (Phase 2 — separates Ticket)

- Multi-Wochen-Trend-Ansicht mit Swift Charts (gestapeltes Balkendiagramm, 4-8 Wochen)
- Trend-Erkennung ("Konsequenz waechst seit 3 Wochen")
- Staerkstes/schwaechstes Disziplin-Highlight
- Optional: Coach-Wahl-Historie einblenden (welcher Coach pro Tag)

## Changelog

- 2026-03-16: Initial spec created (Phase 1)
