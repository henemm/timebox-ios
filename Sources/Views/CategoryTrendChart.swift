import SwiftUI
import Charts

/// Stacked bar chart showing category distribution over multiple weeks.
/// Replaces DisciplineTrendChart for meaningful trend visualization.
struct CategoryTrendChart: View {
    let snapshots: [WeeklyCategorySnapshot]
    let trends: [CategoryTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategorie-Trend")
                .font(.headline)
                .accessibilityIdentifier("categoryTrendHeader")

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
        .accessibilityIdentifier("categoryTrendSection")
    }

    // MARK: - Chart

    private var chartSection: some View {
        Chart {
            ForEach(snapshots) { snapshot in
                ForEach(snapshot.stats.filter { $0.count > 0 }) { stat in
                    BarMark(
                        x: .value("Woche", snapshot.weekStart, unit: .weekOfYear),
                        y: .value("Tasks", stat.count)
                    )
                    .foregroundStyle(colorFor(stat.category))
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
        .accessibilityIdentifier("categoryTrendChart")
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
                .accessibilityIdentifier("categoryTrend_\(trend.id)")
            }

            if let strongest = strongestCategory {
                HStack(spacing: 6) {
                    Image(systemName: strongest.icon)
                        .foregroundStyle(strongest.color)
                    Text("Staerkste Kategorie: \(strongest.displayName)")
                        .font(.caption.weight(.medium))
                }
                .accessibilityIdentifier("categoryStrongest")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("Noch keine Daten fuer den Trend")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("categoryTrendEmptyState")
    }

    // MARK: - Helpers

    private func colorFor(_ category: TaskCategory?) -> Color {
        category?.color ?? .gray
    }

    private func nameFor(_ category: TaskCategory?) -> String {
        category?.displayName ?? "Sonstiges"
    }

    private func trendText(for trend: CategoryTrend) -> String {
        let directionText = trend.direction == .growing ? "waechst" : "sinkt"
        return "\(nameFor(trend.category)) \(directionText) seit \(trend.consecutiveWeeks) Wochen"
    }

    private var strongestCategory: TaskCategory? {
        let totals: [String: Int] = snapshots.reduce(into: [:]) { result, snapshot in
            for stat in snapshot.stats {
                let key = stat.category?.rawValue ?? ""
                result[key, default: 0] += stat.count
            }
        }
        guard let max = totals.filter({ !$0.key.isEmpty }).max(by: { $0.value < $1.value }),
              max.value > 0 else { return nil }
        return TaskCategory(rawValue: max.key)
    }
}
