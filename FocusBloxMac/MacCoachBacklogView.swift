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

    @AppStorage("intentionFilterOptions") private var intentionFilterOptions: String = ""

    // MARK: - Intention

    private var activeIntentionFilters: [IntentionOption] {
        guard !intentionFilterOptions.isEmpty else { return [] }
        return intentionFilterOptions.split(separator: ",").compactMap {
            IntentionOption(rawValue: String($0))
        }
    }

    private var primaryIntention: IntentionOption? {
        activeIntentionFilters.first
    }

    private var intention: DailyIntention {
        DailyIntention.load()
    }

    // MARK: - Task Sections

    private var incompleteTasks: [LocalTask] {
        tasks.filter { $0.modelContext != nil && !$0.isCompleted && !$0.isTemplate }
    }

    private var relevantTasks: [LocalTask] {
        let filters = activeIntentionFilters
        guard !filters.isEmpty, !filters.contains(.survival) else { return [] }
        return incompleteTasks.filter { matchesIntention(filters, task: $0) }
    }

    private var otherTasks: [LocalTask] {
        let filters = activeIntentionFilters
        guard !filters.isEmpty, !filters.contains(.survival) else { return incompleteTasks }
        let relevantIDs = Set(relevantTasks.map(\.id))
        return incompleteTasks.filter { !relevantIDs.contains($0.id) }
    }

    private func matchesIntention(_ options: [IntentionOption], task: LocalTask) -> Bool {
        options.contains { option in
            switch option {
            case .survival: true
            case .fokus: task.isNextUp
            case .bhag: task.importance == 3 || task.rescheduleCount >= 2
            case .balance: true
            case .growth: task.taskType == "learning"
            case .connection: task.taskType == "social" || task.taskType == "family"
            }
        }
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

    // MARK: - Monster Header

    private var monsterHeader: some View {
        VStack(spacing: 8) {
            if let primary = primaryIntention {
                let discipline = primary.monsterDiscipline
                Image(discipline.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .clipShape(Circle())

                Text(primary.label)
                    .font(.headline)
                    .foregroundStyle(discipline.color)
            } else if intention.isSet {
                let firstSelection = intention.selections.first
                let discipline = firstSelection?.monsterDiscipline ?? .ausdauer
                Image(discipline.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .clipShape(Circle())

                Text(firstSelection?.label ?? "")
                    .font(.headline)
                    .foregroundStyle(discipline.color)
            } else {
                Image(systemName: "sun.and.horizon")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                Text("Starte deinen Tag unter Mein Tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachMonsterHeader")
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
