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

    private var otherTasks: [LocalTask] {
        let otherIDs = Set(CoachBacklogViewModel.otherTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
        return tasks.filter { otherIDs.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        List(selection: $selectedTasks) {
            monsterHeader
                .listRowSeparator(.hidden)

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
        let discipline = Discipline.classifyOpen(
            rescheduleCount: task.rescheduleCount,
            importance: task.importance
        )
        return MacBacklogRow(
            task: task,
            disciplineColor: discipline.color
        )
    }
}
