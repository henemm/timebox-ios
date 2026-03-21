import SwiftUI

/// Vertikale Staging Area für "Next Up" Tasks
/// Zeigt Tasks, die der User als nächstes erledigen will
struct NextUpSection: View {
    let tasks: [PlanItem]
    let onRemoveFromNextUp: (String) -> Void
    var onEditTask: ((PlanItem) -> Void)?
    var onDeleteTask: ((PlanItem) -> Void)?
    var onStartFocusSprint: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
                Text("Next Up")
                    .font(.headline)
                Spacer()
                if !tasks.isEmpty {
                    Text("\(tasks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.blue.opacity(0.15)))
                }
            }
            .padding(.horizontal)

            if tasks.isEmpty {
                // Empty state
                Text("Tippe ↑ bei einem Task um ihn hierher zu verschieben")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                // Task list with swipe actions
                List {
                    ForEach(tasks) { task in
                        NextUpRow(task: task, onRemove: {
                            onRemoveFromNextUp(task.id)
                        }, onStartFocusSprint: onStartFocusSprint != nil ? {
                            onStartFocusSprint?(task.id)
                        } : nil)
                        .accessibilityIdentifier("nextUpRow")
                        .contextMenu {
                            if onStartFocusSprint != nil {
                                Button {
                                    onStartFocusSprint?(task.id)
                                } label: {
                                    Label("Focus Sprint starten", systemImage: "bolt.fill")
                                }
                                Divider()
                            }
                            Button {
                                onEditTask?(task)
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            Button {
                                onRemoveFromNextUp(task.id)
                            } label: {
                                Label("Aus Next Up entfernen", systemImage: "arrow.down.circle")
                            }
                            Divider()
                            Button(role: .destructive) {
                                onDeleteTask?(task)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        } preview: {
                            TaskPreviewView(task: task)
                        }
                        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDeleteTask?(task)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            Button {
                                onEditTask?(task)
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(tasks.count) * 50)
                .scrollDisabled(true)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

/// Einzelne Task-Zeile in der NextUpSection (vertikales Layout)
struct NextUpRow: View {
    let task: PlanItem
    let onRemove: () -> Void
    var onStartFocusSprint: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.blue)
                .frame(width: 6, height: 6)

            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text("\(task.effectiveDuration) min")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let onStartFocusSprint {
                Button {
                    onStartFocusSprint()
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.orange))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nextUpSprintButton_\(task.id)")
                .accessibilityLabel("Focus Sprint starten")
            }

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Einzelner Task-Chip in der NextUpSection
struct NextUpChip: View {
    let task: PlanItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)

            Text("\(task.effectiveDuration)m")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.3), lineWidth: 1)
        )
    }
}
