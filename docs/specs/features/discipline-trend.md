---
entity_id: discipline-trend
type: feature
created: 2026-03-16
updated: 2026-03-16
status: draft
version: "1.0"
tags: [coach, discipline, trend, charts, visualization]
---

# Disziplin-Trend (Multi-Wochen) — FEATURE_023

## Approval

- [ ] Approved

## Purpose

Zeigt dem User in der "Mein Tag"-View (Coach-Modus) wie sich seine Disziplin-Verteilung ueber mehrere Wochen entwickelt — als gestapeltes Balkendiagramm mit Swift Charts. Erkennt Trends ("Konsequenz waechst seit 3 Wochen") und hebt die staerkste/schwaechste Disziplin hervor.

Aufbauend auf Phase 1 (FEATURE_016: Tages/Wochen-Snapshot, erledigt). Erfuellt das User-Story-Kriterium vollstaendig: "Ich sehe ueber die Zeit an welchen Disziplinen ich gewachsen bin."

## User Story Referenz

`docs/project/stories/monster-coach.md` — Erfolgskriterium:
> "Ich sehe ueber die Zeit an welchen Disziplinen ich gewachsen bin"

## Scope

- **Files:** 4 Produktiv-Dateien (1 CREATE, 3 MODIFY) + 2 Test-Dateien
- **Estimated LoC:** ~240 neue Zeilen
- **Risk:** LOW-MEDIUM (Swift Charts Erstnutzung, aber Apple-Standard-Framework)
- **Plattform:** iOS + macOS (shared Code in Sources/)

## Source

### Neue Dateien

- **File:** `Sources/Views/DisciplineTrendChart.swift`
- **Identifier:** `struct DisciplineTrendChart: View`

### Geaenderte Dateien

- **File:** `Sources/Services/DisciplineStatsService.swift` — neue Methoden `weeklyHistory()`, `trends()`
- **File:** `Sources/Views/ReviewComponents.swift` — neue Typen `WeeklyDisciplineSnapshot`, `DisciplineTrend`, `TrendDirection`
- **File:** `Sources/Views/CoachMeinTagView.swift` — neues Segment "Trend" in ReviewMode-Picker

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DisciplineStatsService` | Service (enum) | Bestehende `breakdown(for:)` Methode wird intern von `weeklyHistory()` aufgerufen |
| `DisciplineStat` | Struct | Bestehender Datentyp fuer Disziplin-Statistik pro Woche |
| `Discipline` | Model (enum) | Farben, Icons, Monster-Images fuer Chart-Darstellung |
| `LocalTask` | Model (SwiftData) | Datenquelle: `completedAt` fuer Wochen-Zuordnung |
| `CoachMeinTagView` | View (shared) | Integrationspunkt: neues "Trend"-Segment |
| Swift Charts | Framework | Apple-Standard seit iOS 16 / macOS 13 — `import Charts`, `BarMark` |

## Implementation Details

### 1. Neue Datentypen in ReviewComponents.swift (~25 LoC)

```swift
// MARK: - Discipline Trend Types

/// Woechentlicher Snapshot der Disziplin-Verteilung.
struct WeeklyDisciplineSnapshot: Identifiable {
    let weekStart: Date
    let stats: [DisciplineStat]
    var id: Date { weekStart }

    /// Gesamtzahl erledigter Tasks in dieser Woche.
    var total: Int { stats.first?.total ?? 0 }
}

/// Trend-Richtung einer Disziplin ueber mehrere Wochen.
enum TrendDirection {
    case growing    // Anteil steigt konsekutiv
    case declining  // Anteil sinkt konsekutiv
    case stable     // Kein klarer Trend
}

/// Erkannter Trend fuer eine einzelne Disziplin.
struct DisciplineTrend: Identifiable {
    let discipline: Discipline
    let direction: TrendDirection
    let consecutiveWeeks: Int
    var id: String { discipline.rawValue }
}
```

### 2. DisciplineStatsService Erweiterung (~60 LoC)

```swift
// MARK: - Multi-Week History

/// Berechnet Disziplin-Verteilung fuer die letzten N Wochen.
/// Gibt immer genau `weeksBack` Snapshots zurueck (aelteste zuerst).
/// Leere Wochen haben stats mit count=0.
static func weeklyHistory(
    tasks: [LocalTask],
    weeksBack: Int = 6,
    now: Date = Date()
) -> [WeeklyDisciplineSnapshot] {
    let calendar = Calendar.current
    var snapshots: [WeeklyDisciplineSnapshot] = []

    for weeksAgo in (0..<weeksBack).reversed() {
        guard let targetDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now),
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
            continue
        }

        let weekTasks = tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= weekInterval.start && completedAt < weekInterval.end
        }

        let stats = breakdown(for: weekTasks)
        snapshots.append(WeeklyDisciplineSnapshot(weekStart: weekInterval.start, stats: stats))
    }

    return snapshots
}

/// Erkennt Trends fuer jede Disziplin aus einer Serie von Wochen-Snapshots.
/// Ein Trend ist "growing" wenn der Anteil in 3+ aufeinanderfolgenden Wochen (mit Tasks) steigt.
/// Ein Trend ist "declining" wenn der Anteil in 3+ aufeinanderfolgenden Wochen sinkt.
/// Sonst "stable".
static func trends(from snapshots: [WeeklyDisciplineSnapshot]) -> [DisciplineTrend] {
    Discipline.allCases.map { discipline in
        let percentages: [(hasData: Bool, pct: Double)] = snapshots.map { snapshot in
            guard let stat = snapshot.stats.first(where: { $0.discipline == discipline }) else {
                return (false, 0)
            }
            let total = snapshot.total
            guard total > 0 else { return (false, 0) }
            return (true, Double(stat.count) / Double(total))
        }

        // Zaehle konsekutive Wochen mit steigendem/sinkendem Anteil (von hinten, nur Wochen mit Daten)
        let withData = percentages.filter { $0.hasData }
        guard withData.count >= 3 else {
            return DisciplineTrend(discipline: discipline, direction: .stable, consecutiveWeeks: 0)
        }

        var growingCount = 0
        var decliningCount = 0
        for i in stride(from: withData.count - 1, through: 1, by: -1) {
            if withData[i].pct > withData[i - 1].pct {
                growingCount += 1
            } else { break }
        }
        for i in stride(from: withData.count - 1, through: 1, by: -1) {
            if withData[i].pct < withData[i - 1].pct {
                decliningCount += 1
            } else { break }
        }

        if growingCount >= 2 {
            return DisciplineTrend(discipline: discipline, direction: .growing, consecutiveWeeks: growingCount + 1)
        } else if decliningCount >= 2 {
            return DisciplineTrend(discipline: discipline, direction: .declining, consecutiveWeeks: decliningCount + 1)
        }
        return DisciplineTrend(discipline: discipline, direction: .stable, consecutiveWeeks: 0)
    }
}
```

### 3. DisciplineTrendChart.swift (neue Datei, ~90 LoC)

```swift
import SwiftUI
import Charts

/// Gestapeltes Balkendiagramm: Disziplin-Verteilung ueber mehrere Wochen.
struct DisciplineTrendChart: View {
    let snapshots: [WeeklyDisciplineSnapshot]
    let trends: [DisciplineTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disziplin-Trend")
                .font(.headline)
                .accessibilityIdentifier("disciplineTrendHeader")

            if snapshots.allSatisfy({ $0.total == 0 }) {
                emptyState
            } else {
                chartSection
                trendHighlights
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .accessibilityIdentifier("disciplineTrendSection")
    }

    // MARK: - Chart

    private var chartSection: some View {
        Chart {
            ForEach(snapshots) { snapshot in
                ForEach(snapshot.stats) { stat in
                    BarMark(
                        x: .value("Woche", snapshot.weekStart, unit: .weekOfYear),
                        y: .value("Tasks", stat.count)
                    )
                    .foregroundStyle(stat.discipline.color)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { value in
                AxisValueLabel(format: .dateTime.week())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 200)
        .accessibilityIdentifier("disciplineTrendChart")
    }

    // MARK: - Trend Highlights

    private var trendHighlights: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(trends.filter { $0.direction != .stable }) { trend in
                HStack(spacing: 6) {
                    Image(systemName: trend.direction == .growing
                          ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(trend.direction == .growing ? .green : .orange)
                    Text(trendText(for: trend))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("disciplineTrend_\(trend.discipline.rawValue)")
            }

            if let strongest = strongestDiscipline {
                HStack(spacing: 6) {
                    Image(strongest.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                    Text("Staerkste Disziplin: \(strongest.displayName)")
                        .font(.caption.weight(.medium))
                }
                .accessibilityIdentifier("disciplineStrongest")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("Noch keine Daten fuer den Trend")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("disciplineTrendEmptyState")
    }

    // MARK: - Helpers

    private func trendText(for trend: DisciplineTrend) -> String {
        let directionText = trend.direction == .growing ? "waechst" : "sinkt"
        return "\(trend.discipline.displayName) \(directionText) seit \(trend.consecutiveWeeks) Wochen"
    }

    /// Staerkste Disziplin ueber den gesamten Zeitraum (hoechster Gesamtanteil).
    private var strongestDiscipline: Discipline? {
        let totals: [Discipline: Int] = snapshots.reduce(into: [:]) { result, snapshot in
            for stat in snapshot.stats {
                result[stat.discipline, default: 0] += stat.count
            }
        }
        return totals.max(by: { $0.value < $1.value })?.key
    }
}
```

### 4. CoachMeinTagView Integration (~50 LoC)

```swift
// ReviewMode erweitern:
private enum ReviewMode: String, CaseIterable {
    case today = "Heute"
    case week = "Diese Woche"
    case trend = "Trend"
}

// Neue State-Variable:
@State private var trendSnapshots: [WeeklyDisciplineSnapshot] = []
@State private var disciplineTrends: [DisciplineTrend] = []

// Neuer case in switch reviewMode:
case .trend:
    DisciplineTrendChart(
        snapshots: trendSnapshots,
        trends: disciplineTrends
    )
    .padding(.horizontal)

// Lazy Loading bei Segment-Wechsel:
.onChange(of: reviewMode) {
    if reviewMode == .week {
        Task { await loadWeeklyAIReflectionText() }
    }
    if reviewMode == .trend {
        loadTrendData()
    }
}

// Neue private Methode:
private func loadTrendData() {
    trendSnapshots = DisciplineStatsService.weeklyHistory(
        tasks: allLocalTasks,
        weeksBack: 6
    )
    disciplineTrends = DisciplineStatsService.trends(from: trendSnapshots)
}
```

## Expected Behavior

### Input
- User hat Coach-Modus aktiviert und oeffnet "Mein Tag"-Tab
- User tippt auf "Trend"-Segment im Picker (neben "Heute" und "Diese Woche")
- Es existieren erledigte Tasks ueber mehrere Wochen

### Output
- **Gestapeltes Balkendiagramm:** 6 Wochen auf X-Achse, jeder Balken zeigt 4 Disziplinen gestapelt in ihren Farben (Gruen/Grau/Rot/Blau)
- **Trend-Texte:** Unter dem Chart Hinweise wie "Konsequenz waechst seit 3 Wochen" (mit Pfeil-Icon)
- **Staerkste Disziplin:** Highlight mit Monster-Icon: "Staerkste Disziplin: Konsequenz"
- **Leerer Zustand:** "Noch keine Daten fuer den Trend" wenn keine Wochen mit erledigten Tasks

### Side Effects
- Keine — rein lesende Auswertung bestehender Daten. Kein neues Schema, keine Persistierung.

### Beispiel-Szenario

User hat 6 Wochen lang Tasks erledigt:
```
KW 7:  4 Tasks (2 Konsequenz, 1 Mut, 1 Ausdauer)
KW 8:  6 Tasks (3 Konsequenz, 1 Mut, 1 Fokus, 1 Ausdauer)
KW 9:  5 Tasks (3 Konsequenz, 1 Fokus, 1 Ausdauer)
KW 10: 8 Tasks (4 Konsequenz, 2 Mut, 1 Fokus, 1 Ausdauer)
KW 11: 3 Tasks (2 Konsequenz, 1 Ausdauer)
KW 12: 7 Tasks (4 Konsequenz, 1 Mut, 1 Fokus, 1 Ausdauer)
```

Chart zeigt gestapelte Balken pro Woche. Darunter:
- "Konsequenz waechst seit 3 Wochen" (Anteil steigt)
- "Staerkste Disziplin: Konsequenz"

## Accessibility Identifiers

| Element | Identifier | Typ |
|---------|-----------|-----|
| Trend Section Container | `disciplineTrendSection` | VStack |
| Section Header | `disciplineTrendHeader` | Text |
| Chart | `disciplineTrendChart` | Chart |
| Trend-Text (pro Disziplin) | `disciplineTrend_konsequenz` / `_ausdauer` / `_mut` / `_fokus` | HStack |
| Staerkste Disziplin | `disciplineStrongest` | HStack |
| Empty State | `disciplineTrendEmptyState` | Text |

## Test Plan

### Unit Tests (DisciplineTrendServiceTests.swift)

| Test | Beschreibung |
|------|-------------|
| `test_weeklyHistory_emptyTasks_returnsSnapshotsWithZeroCounts` | Keine Tasks → 6 Snapshots, alle counts=0 |
| `test_weeklyHistory_tasksInMultipleWeeks_correctDistribution` | Tasks in 3 verschiedenen Wochen → korrekte Zuordnung per completedAt |
| `test_weeklyHistory_respectsWeeksBackParameter` | weeksBack=4 → genau 4 Snapshots |
| `test_weeklyHistory_snapshotsInChronologicalOrder` | Aelteste Woche zuerst, neueste zuletzt |
| `test_trends_growingDiscipline_detected` | 3 Wochen mit steigendem Anteil → direction=.growing, consecutiveWeeks=3 |
| `test_trends_decliningDiscipline_detected` | 3 Wochen mit sinkendem Anteil → direction=.declining |
| `test_trends_stableDiscipline_noTrend` | Gleichbleibender Anteil → direction=.stable |
| `test_trends_emptyWeeksIgnored` | Wochen ohne Tasks zaehlen nicht als Wachstum/Abnahme |
| `test_trends_lessThanThreeWeeksData_allStable` | Weniger als 3 Wochen mit Daten → alle stable |

### UI Tests (DisciplineTrendUITests.swift)

| Test | Beschreibung |
|------|-------------|
| `test_trendSegment_visible` | Segmented Picker zeigt "Trend" als drittes Segment |
| `test_trendView_showsChartSection` | Nach Tap auf "Trend": `disciplineTrendSection` und `disciplineTrendChart` sichtbar |
| `test_trendView_showsHeader` | "Disziplin-Trend" Header sichtbar |

## Known Limitations

- **Keine Persistierung:** Trend-Daten werden live berechnet bei jedem Segment-Wechsel. Bei sehr vielen Tasks (1000+) koennte kurze Verzoegerung spuerbar sein.
- **Minimum 3 Wochen fuer Trend:** Trend-Erkennung braucht mindestens 3 Wochen mit erledigten Tasks. Neue User sehen zunaechst nur den Chart ohne Trend-Hinweise.
- **effectiveDuration fehlt manchmal:** Tasks ohne Focus-Block-Tracking haben keine genaue Dauer → werden als Ausdauer klassifiziert (Fokus nicht bestimmbar).
- **Keine Coach-Wahl-Historie:** Der Chart zeigt nicht welcher Coach pro Woche aktiv war — koennte in einem Folge-Ticket ergaenzt werden.
- **6 Wochen fest:** Der Zeitraum ist initial auf 6 Wochen fixiert. Ein konfigurierbarer Slider (4-8 Wochen) waere eine moegliche Erweiterung.

## Changelog

- 2026-03-16: Initial spec created (Phase 2)
