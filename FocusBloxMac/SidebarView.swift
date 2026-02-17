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

/// Sidebar filter options for the backlog
enum SidebarFilter: Hashable {
    case all
    case category(String)
    case nextUp
    case tbd
    case overdue
    case upcoming
    case completed
    case aiRecommended
}

/// Sidebar view showing only filters (navigation moved to toolbar)
struct SidebarView: View {
    @Binding var selectedFilter: SidebarFilter
    let tbdCount: Int
    let nextUpCount: Int
    let overdueCount: Int
    let upcomingCount: Int
    let completedCount: Int

    var body: some View {
        List {
            // MARK: - Backlog Filters
            Section("Filter") {
                filterRow(label: "Alle Tasks", icon: "tray.full", filter: .all)

                HStack {
                    Label("Next Up", systemImage: "arrow.up.circle.fill")
                        .accessibilityIdentifier("sidebarFilter_nextUp")
                    Spacer()
                    if nextUpCount > 0 {
                        badgeView(count: nextUpCount, color: .blue)
                    }
                }
                .tag(SidebarFilter.nextUp)
                .contentShape(Rectangle())
                .onTapGesture { selectedFilter = .nextUp }
                .listRowBackground(selectedFilter == .nextUp ? Color.accentColor.opacity(0.15) : Color.clear)

                HStack {
                    Label("TBD", systemImage: "questionmark.circle")
                        .accessibilityIdentifier("sidebarFilter_tbd")
                    Spacer()
                    if tbdCount > 0 {
                        badgeView(count: tbdCount, color: .orange)
                    }
                }
                .tag(SidebarFilter.tbd)
                .contentShape(Rectangle())
                .onTapGesture { selectedFilter = .tbd }
                .listRowBackground(selectedFilter == .tbd ? Color.accentColor.opacity(0.15) : Color.clear)

                HStack {
                    Label("Überfällig", systemImage: "exclamationmark.circle.fill")
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
                    Label("Bald fällig", systemImage: "clock.fill")
                        .accessibilityIdentifier("sidebarFilter_upcoming")
                    Spacer()
                    if upcomingCount > 0 {
                        badgeView(count: upcomingCount, color: .yellow)
                    }
                }
                .tag(SidebarFilter.upcoming)
                .contentShape(Rectangle())
                .onTapGesture { selectedFilter = .upcoming }
                .listRowBackground(selectedFilter == .upcoming ? Color.accentColor.opacity(0.15) : Color.clear)

                HStack {
                    Label("Erledigt", systemImage: "checkmark.circle.fill")
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

                // AI Recommended (only when Apple Intelligence is available)
                if AITaskScoringService.isAvailable {
                    Label("KI-Empfehlung", systemImage: "wand.and.stars")
                        .accessibilityIdentifier("sidebarFilter_aiRecommended")
                        .tag(SidebarFilter.aiRecommended)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedFilter = .aiRecommended }
                        .listRowBackground(selectedFilter == .aiRecommended ? Color.accentColor.opacity(0.15) : Color.clear)
                }
            }

            Section("Kategorien") {
                categoryRow("income", "Geld verdienen", "dollarsign.circle")
                categoryRow("maintenance", "Pflege", "wrench.and.screwdriver.fill")
                categoryRow("recharge", "Energie", "battery.100")
                categoryRow("learning", "Lernen", "book")
                categoryRow("giving_back", "Weitergeben", "gift")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Filter")
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

    private func categoryRow(_ id: String, _ label: String, _ icon: String) -> some View {
        Label(label, systemImage: icon)
            .accessibilityIdentifier("sidebarCategory_\(id)")
            .tag(SidebarFilter.category(id))
            .contentShape(Rectangle())
            .onTapGesture { selectedFilter = .category(id) }
            .listRowBackground(selectedFilter == .category(id) ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    private func filterIdentifier(_ filter: SidebarFilter) -> String {
        switch filter {
        case .all: return "all"
        case .nextUp: return "nextUp"
        case .tbd: return "tbd"
        case .overdue: return "overdue"
        case .upcoming: return "upcoming"
        case .completed: return "completed"
        case .aiRecommended: return "aiRecommended"
        case .category(let id): return id
        }
    }
}

#Preview {
    SidebarView(
        selectedFilter: .constant(.all),
        tbdCount: 3,
        nextUpCount: 5,
        overdueCount: 2,
        upcomingCount: 4,
        completedCount: 10
    )
    .frame(width: 220)
}
