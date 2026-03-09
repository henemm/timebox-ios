import AppIntents
import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Extracts clipboard text from mock launch arguments (for testing) or system pasteboard
enum ClipboardHelper {
    static func mockText(from arguments: [String]) -> String? {
        guard let idx = arguments.firstIndex(of: "-MockClipboard"),
              idx + 1 < arguments.count else { return nil }
        return arguments[idx + 1]
    }

    static func currentText() -> String? {
        if let mock = mockText(from: ProcessInfo.processInfo.arguments) {
            return mock
        }
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}

/// Minimalistic quick capture view for fast task entry from Control Center widget
/// Features compact metadata buttons for importance, urgency, category, and duration
struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""

    @State private var title = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    // Metadata state
    @State private var importance: Int? = nil  // nil → 1 → 2 → 3 → nil
    @State private var urgency: String? = nil  // nil → not_urgent → urgent → nil
    @State private var taskType: String = "maintenance"
    @State private var estimatedDuration: Int? = nil
    @State private var isNextUp = false

    // Clipboard state
    @State private var clipboardText: String?

    // Sheet states
    @State private var showCategoryPicker = false
    @State private var showDurationPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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

                    // Clipboard paste button (visible when field is empty and clipboard has text)
                    if title.trimmingCharacters(in: .whitespaces).isEmpty, clipboardText != nil {
                        clipboardButton
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
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            if !initialTitle.isEmpty {
                title = initialTitle
            }
            clipboardText = ClipboardHelper.currentText()
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

    // MARK: - Clipboard Button

    private var clipboardButton: some View {
        Button {
            if let text = clipboardText {
                title = text
                clipboardText = nil
            }
        } label: {
            Label("Einfügen", systemImage: "doc.on.clipboard")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .accessibilityIdentifier("qc_clipboardButton")
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.secondary)
        .transition(.opacity.combined(with: .move(edge: .top)))
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

            // Next Up toggle
            nextUpButton

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

    // MARK: - Next Up Button

    private var nextUpButton: some View {
        Button {
            isNextUp.toggle()
        } label: {
            Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
                .font(.system(size: 16))
                .foregroundStyle(isNextUp ? .blue : .gray)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill((isNextUp ? Color.blue : Color.gray).opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("qc_nextUpButton")
        .accessibilityLabel(isNextUp ? "Next Up aktiv" : "Next Up")
        .sensoryFeedback(.impact(weight: .light), trigger: isNextUp)
    }

    // MARK: - Save Task

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true

        // Capture values before dismiss invalidates the view
        let capturedImportance = importance
        let capturedDuration = estimatedDuration
        let capturedUrgency = urgency
        let capturedTaskType = taskType
        let capturedContext = modelContext
        let shouldMarkNextUp = isNextUp

        // Dismiss synchronously FIRST — async dismiss inside Task{} breaks on iOS 26
        dismiss()

        // Create task in background after sheet is dismissed
        Task {
            do {
                let taskSource = LocalTaskSource(modelContext: capturedContext)
                let task = try await taskSource.createTask(
                    title: trimmedTitle,
                    importance: capturedImportance,
                    estimatedDuration: capturedDuration,
                    urgency: capturedUrgency,
                    taskType: capturedTaskType
                )

                if shouldMarkNextUp {
                    task.isNextUp = true
                    task.nextUpSortOrder = Int.max
                    try? capturedContext.save()
                }

                // ITB-G1: Donate intent so Siri learns task creation patterns
                let donationIntent = CreateTaskIntent()
                donationIntent.taskTitle = trimmedTitle
                try? await IntentDonationManager.shared.donate(intent: donationIntent)
            } catch {
                // Task creation failed — sheet already dismissed
            }
        }
    }
}

#Preview {
    QuickCaptureView()
        .modelContainer(for: LocalTask.self, inMemory: true)
}
