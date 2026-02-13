import SwiftUI
import SwiftData

/// Minimalistic quick capture view for fast task entry from Control Center widget
/// Features compact metadata buttons for importance, urgency, category, and duration
struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""

    @State private var title = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @FocusState private var isFocused: Bool

    // Metadata state
    @State private var importance: Int? = nil  // nil → 1 → 2 → 3 → nil
    @State private var urgency: String? = nil  // nil → not_urgent → urgent → nil
    @State private var taskType: String = "maintenance"
    @State private var estimatedDuration: Int? = nil

    // Sheet states
    @State private var showCategoryPicker = false
    @State private var showDurationPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showSuccess {
                    // Success feedback before auto-dismiss
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityIdentifier("quickCaptureSuccessIcon")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    TextField("Was gibt es zu tun?", text: $title)
                        .accessibilityIdentifier("quickCaptureTextField")
                        .focused($isFocused)
                        .font(.title2)
                        .padding()
                        .glassEffect()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .submitLabel(.done)
                        .onSubmit {
                            saveTask()
                        }

                    // Metadata row with cycle buttons
                    metadataRow

                    Button {
                        saveTask()
                    } label: {
                        Label("Speichern", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("quickCaptureSaveButton")
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .sensoryFeedback(.impact, trigger: isSaving)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring, value: showSuccess)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            if !initialTitle.isEmpty {
                title = initialTitle
            }
            isFocused = true
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPicker(currentCategory: taskType) { selected in
                taskType = selected
                showCategoryPicker = false
            }
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPicker(currentDuration: estimatedDuration ?? 0) { selected in
                estimatedDuration = selected
                showDurationPicker = false
            }
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 12) {
            // Importance cycle button
            importanceButton

            // Urgency cycle button
            urgencyButton

            // Category button (opens sheet)
            categoryButton

            // Duration button (opens sheet)
            durationButton

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Importance Button (cycles: nil → 1 → 2 → 3 → nil)

    private var importanceButton: some View {
        Button {
            cycleImportance()
        } label: {
            Image(systemName: importanceIcon)
                .font(.system(size: 16))
                .foregroundStyle(importanceColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(importanceColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("qc_importanceButton")
        .accessibilityLabel("Wichtigkeit: \(importanceLabel)")
        .sensoryFeedback(.impact(weight: .light), trigger: importance)
    }

    private func cycleImportance() {
        switch importance {
        case nil: importance = 1
        case 1: importance = 2
        case 2: importance = 3
        case 3: importance = nil
        default: importance = nil
        }
    }

    private var importanceIcon: String {
        ImportanceUI.icon(for: importance)
    }

    private var importanceColor: Color {
        ImportanceUI.color(for: importance)
    }

    private var importanceLabel: String {
        ImportanceUI.label(for: importance)
    }

    // MARK: - Urgency Button (cycles: nil → not_urgent → urgent → nil)

    private var urgencyButton: some View {
        Button {
            cycleUrgency()
        } label: {
            Image(systemName: urgencyIcon)
                .font(.system(size: 16))
                .foregroundStyle(urgencyColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(urgencyColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("qc_urgencyButton")
        .accessibilityLabel("Dringlichkeit: \(urgencyLabel)")
        .sensoryFeedback(.impact(weight: .medium), trigger: urgency)
    }

    private func cycleUrgency() {
        switch urgency {
        case nil: urgency = "not_urgent"
        case "not_urgent": urgency = "urgent"
        case "urgent": urgency = nil
        default: urgency = nil
        }
    }

    private var urgencyIcon: String {
        UrgencyUI.icon(for: urgency)
    }

    private var urgencyColor: Color {
        UrgencyUI.color(for: urgency)
    }

    private var urgencyLabel: String {
        UrgencyUI.label(for: urgency)
    }

    // MARK: - Category Button (opens sheet)

    private var categoryButton: some View {
        Button {
            showCategoryPicker = true
        } label: {
            Image(systemName: categoryIcon)
                .font(.system(size: 16))
                .foregroundStyle(categoryColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(categoryColor.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("qc_categoryButton")
        .accessibilityLabel("Kategorie: \(categoryLabel)")
    }

    private var categoryIcon: String {
        TaskCategory(rawValue: taskType)?.icon ?? "folder"
    }

    private var categoryColor: Color {
        TaskCategory(rawValue: taskType)?.color ?? .gray
    }

    private var categoryLabel: String {
        TaskCategory(rawValue: taskType)?.displayName ?? "Kategorie"
    }

    // MARK: - Duration Button (opens sheet)

    private var durationButton: some View {
        Button {
            showDurationPicker = true
        } label: {
            HStack(spacing: 2) {
                Image(systemName: estimatedDuration != nil ? "timer" : "questionmark")
                if let duration = estimatedDuration {
                    Text("\(duration)m")
                        .font(.caption)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(estimatedDuration != nil ? .blue : .gray)
            .frame(height: 40)
            .padding(.horizontal, estimatedDuration != nil ? 10 : 0)
            .frame(minWidth: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill((estimatedDuration != nil ? Color.blue : Color.gray).opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("qc_durationButton")
        .accessibilityLabel(estimatedDuration != nil ? "Dauer: \(estimatedDuration!) Minuten" : "Dauer nicht gesetzt")
    }

    // MARK: - Save Task

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true

        Task {
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                _ = try await taskSource.createTask(
                    title: trimmedTitle,
                    importance: importance,
                    estimatedDuration: estimatedDuration,
                    urgency: urgency,
                    taskType: taskType
                )

                await MainActor.run {
                    showSuccess = true
                }

                // Auto-dismiss after short success animation
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run {
                    dismiss()
                }
            } catch {
                isSaving = false
            }
        }
    }
}

#Preview {
    QuickCaptureView()
        .modelContainer(for: LocalTask.self, inMemory: true)
}
