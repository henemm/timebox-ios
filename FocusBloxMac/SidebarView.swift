//
//  SidebarView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

/// Main navigation sections
enum MainSection: String, Hashable, CaseIterable {
    case backlog = "Backlog"
    case planning = "Planen"
    case assign = "Zuweisen"
    case focus = "Focus"
    case review = "Review"

    var icon: String {
        switch self {
        case .backlog: return "list.bullet"
        case .planning: return "calendar"
        case .assign: return "arrow.up.arrow.down"
        case .focus: return "target"
        case .review: return "chart.bar"
        }
    }
}

/// Sidebar filter options for the backlog (matches iOS ViewMode)
enum SidebarFilter: Hashable {
    case priority
    case recent
    case overdue
    case recurring
    case completed
}

/// Sidebar view showing only filters (navigation moved to toolbar)
/// Matches iOS BacklogView.ViewMode: Priorität, Zuletzt, Überfällig, Wiederkehrend, Erledigt
struct SidebarView: View {
    @Binding var selectedFilter: SidebarFilter
    let overdueCount: Int
    let completedCount: Int
    let recurringCount: Int

    var body: some View {
        List {
            Section("Ansicht") {
                filterRow(label: "Priorität", icon: "chart.bar.fill", filter: .priority)
                filterRow(label: "Zuletzt", icon: "clock.arrow.circlepath", filter: .recent)

                HStack {
                    Label("Überfällig", systemImage: "exclamationmark.circle")
                        .accessibilityIdentifier("sidebarFilter_overdue")
                    Spacer()
                    if overdueCount > 0 {
                        badgeView(count: overdueCount, color: .red)
                    }
                }
                .tag(SidebarFilter.overdue)
                .contentShape(Rectangle())
                .onTapGesture { selectedFilter = .overdue }
                .listRowBackground(selectedFilter == .overdue ? Color.accentColor.opacity(0.15) : Color.clear)

                HStack {
                    Label("Wiederkehrend", systemImage: "arrow.triangle.2.circlepath")
                        .accessibilityIdentifier("sidebarFilter_recurring")
                    Spacer()
                    if recurringCount > 0 {
                        badgeView(count: recurringCount, color: .purple)
                    }
                }
                .tag(SidebarFilter.recurring)
                .contentShape(Rectangle())
                .onTapGesture { selectedFilter = .recurring }
                .listRowBackground(selectedFilter == .recurring ? Color.accentColor.opacity(0.15) : Color.clear)

                HStack {
                    Label("Erledigt", systemImage: "checkmark.circle")
                        .accessibilityIdentifier("sidebarFilter_completed")
                    Spacer()
                    if completedCount > 0 {
                        badgeView(count: completedCount, color: .green)
                    }
                }
                .tag(SidebarFilter.completed)
                .contentShape(Rectangle())
                .onTapGesture { selectedFilter = .completed }
                .listRowBackground(selectedFilter == .completed ? Color.accentColor.opacity(0.15) : Color.clear)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Ansicht")
    }

    @ViewBuilder
    private func badgeView(count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }

    private func filterRow(label: String, icon: String, filter: SidebarFilter) -> some View {
        Label(label, systemImage: icon)
            .accessibilityIdentifier("sidebarFilter_\(filterIdentifier(filter))")
            .tag(filter)
            .contentShape(Rectangle())
            .onTapGesture { selectedFilter = filter }
            .listRowBackground(selectedFilter == filter ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    private func filterIdentifier(_ filter: SidebarFilter) -> String {
        switch filter {
        case .priority: return "priority"
        case .recent: return "recent"
        case .overdue: return "overdue"
        case .completed: return "completed"
        case .recurring: return "recurring"
        }
    }
}

#Preview {
    SidebarView(
        selectedFilter: .constant(.priority),
        overdueCount: 2,
        completedCount: 10,
        recurringCount: 3
    )
    .frame(width: 220)
}
