import SwiftUI
import AppIntents

/// Interactive SwiftUI view shown in Siri/Spotlight snippet after title input.
/// Uses Button(intent:) for each metadata button - iOS 26 Interactive Snippet pattern.
struct QuickCaptureSnippetView: View {
    let title: String
    let state: QuickCaptureState

    var body: some View {
        VStack(spacing: 12) {
            // Title display
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Metadata buttons row
            HStack(spacing: 10) {
                importanceButton
                urgencyButton
                categoryButton
                durationButton
                Spacer()
            }

            // Save button
            Button(intent: SaveQuickCaptureIntent(taskTitle: title)) {
                Label("Erstellen", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(12)
    }

    // MARK: - Importance Button

    private var importanceButton: some View {
        Button(intent: CycleImportanceIntent()) {
            Image(systemName: importanceIcon)
                .font(.system(size: 14))
                .foregroundStyle(importanceColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(importanceColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
    }

    private var importanceIcon: String {
        ImportanceUI.icon(for: state.importance)
    }

    private var importanceColor: Color {
        ImportanceUI.color(for: state.importance)
    }

    // MARK: - Urgency Button

    private var urgencyButton: some View {
        Button(intent: CycleUrgencyIntent()) {
            Image(systemName: urgencyIcon)
                .font(.system(size: 14))
                .foregroundStyle(urgencyColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(urgencyColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
    }

    private var urgencyIcon: String {
        UrgencyUI.icon(for: state.urgency)
    }

    private var urgencyColor: Color {
        UrgencyUI.color(for: state.urgency)
    }

    // MARK: - Category Button

    private var categoryButton: some View {
        Button(intent: CycleCategoryIntent()) {
            Image(systemName: categoryIcon)
                .font(.system(size: 14))
                .foregroundStyle(categoryColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
    }

    private var categoryIcon: String {
        TaskCategory(rawValue: state.taskType)?.icon ?? "folder"
    }

    private var categoryColor: Color {
        TaskCategory(rawValue: state.taskType)?.color ?? .gray
    }

    // MARK: - Duration Button

    private var durationButton: some View {
        Button(intent: CycleDurationIntent()) {
            HStack(spacing: 2) {
                Image(systemName: state.estimatedDuration != nil ? "timer" : "questionmark")
                if let d = state.estimatedDuration {
                    Text("\(d)m")
                        .font(.caption2)
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(state.estimatedDuration != nil ? .blue : .gray)
            .frame(height: 36)
            .padding(.horizontal, state.estimatedDuration != nil ? 8 : 0)
            .frame(minWidth: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill((state.estimatedDuration != nil ? Color.blue : Color.gray).opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }
}
