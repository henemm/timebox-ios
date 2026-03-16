import SwiftUI
import Charts

/// Stacked bar chart showing discipline distribution over multiple weeks.
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
        .accessibilityElement(children: .contain)
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
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
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

    private var strongestDiscipline: Discipline? {
        let totals: [Discipline: Int] = snapshots.reduce(into: [:]) { result, snapshot in
            for stat in snapshot.stats {
                result[stat.discipline, default: 0] += stat.count
            }
        }
        guard let max = totals.max(by: { $0.value < $1.value }), max.value > 0 else { return nil }
        return max.key
    }
}
