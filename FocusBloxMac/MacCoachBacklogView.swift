//
//  MacCoachBacklogView.swift
//  FocusBloxMac
//
//  Coach-mode Backlog for macOS: Monster header + ranked tasks.
//  Replaces the normal backlog view when coachModeEnabled == true.
//

import SwiftUI
import SwiftData

struct MacCoachBacklogView: View {
    let tasks: [LocalTask]
    @Binding var selectedTasks: Set<UUID>

    @AppStorage("selectedCoach") private var selectedCoach: String = ""

    // MARK: - Task Sections (via shared CoachBacklogViewModel + PlanItem bridge)

    private var planItems: [PlanItem] {
        tasks.filter { $0.modelContext != nil }.map { PlanItem(localTask: $0) }
    }

    private var relevantTasks: [LocalTask] {
        let relevantIDs = Set(CoachBacklogViewModel.relevantTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
        return tasks.filter { relevantIDs.contains($0.id) }
    }

    private var nextUpTasks: [LocalTask] {
        let nextUpIDs = Set(CoachBacklogViewModel.nextUpTasks(from: planItems).map(\.id))
        return tasks.filter { nextUpIDs.contains($0.id) }
    }

    private var otherTasks: [LocalTask] {
        let otherIDs = Set(CoachBacklogViewModel.otherTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
        return tasks.filter { otherIDs.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        List(selection: $selectedTasks) {
            monsterHeader
                .listRowSeparator(.hidden)

            if !nextUpTasks.isEmpty {
                Section {
                    ForEach(nextUpTasks, id: \.uuid) { task in
                        coachRow(task)
                            .tag(task.uuid)
                    }
                } header: {
                    HStack {
                        Label("Next Up", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(nextUpTasks.count)")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .accessibilityIdentifier("coachNextUpSection")
            }

            if !relevantTasks.isEmpty {
                Section {
                    ForEach(relevantTasks, id: \.uuid) { task in
                        coachRow(task)
                            .tag(task.uuid)
                    }
                } header: {
                    Text("Dein Schwerpunkt")
                        .font(.headline)
                }
                .accessibilityIdentifier("coachRelevantSection")
            }

            Section {
                ForEach(otherTasks, id: \.uuid) { task in
                    coachRow(task)
                        .tag(task.uuid)
                }
            } header: {
                if !relevantTasks.isEmpty {
                    Text("Weitere Tasks")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("coachOtherSection")
        }
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Monster Header (shared component)

    private var monsterHeader: some View {
        MonsterIntentionHeader(selectedCoach: selectedCoach, imageHeight: 80)
    }

    // MARK: - Coach Row

    private func coachRow(_ task: LocalTask) -> some View {
        let discipline = Discipline.resolveOpen(
            manualDiscipline: task.manualDiscipline,
            rescheduleCount: task.rescheduleCount,
            importance: task.importance
        )
        return MacBacklogRow(
            task: task,
            disciplineColor: discipline.color
        )
        .contextMenu {
            Section("Next Up") {
                Button {
                    task.isNextUp.toggle()
                    if task.isNextUp && task.nextUpSortOrder == nil {
                        task.nextUpSortOrder = Int.max
                    } else if !task.isNextUp {
                        task.nextUpSortOrder = nil
                    }
                    task.modifiedAt = Date()
                    try? task.modelContext?.save()
                } label: {
                    Label(task.isNextUp ? "Aus Next Up entfernen" : "Zu Next Up hinzufügen",
                          systemImage: task.isNextUp ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                }
            }
            Section("Disziplin") {
                ForEach(Discipline.allCases, id: \.self) { d in
                    Button {
                        task.manualDiscipline = d.rawValue
                        task.modifiedAt = Date()
                        try? task.modelContext?.save()
                    } label: {
                        Label(d.displayName, systemImage: d.icon)
                    }
                    .tint(d.color)
                }
                if task.manualDiscipline != nil {
                    Divider()
                    Button {
                        task.manualDiscipline = nil
                        task.modifiedAt = Date()
                        try? task.modelContext?.save()
                    } label: {
                        Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }
}
