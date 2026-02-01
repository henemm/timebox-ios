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
        case .backlog: return "tray.full"
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
}

struct SidebarView: View {
    @Binding var selectedSection: MainSection
    @Binding var selectedFilter: SidebarFilter
    let tbdCount: Int
    let nextUpCount: Int
    let overdueCount: Int
    let upcomingCount: Int
    let completedCount: Int

    var body: some View {
        List {
            // MARK: - Main Navigation
            Section("Bereiche") {
                ForEach(MainSection.allCases, id: \.self) { section in
                    HStack {
                        Label(section.rawValue, systemImage: section.icon)
                            .accessibilityIdentifier("sidebarSection_\(sectionIdentifier(section))")
                        Spacer()
                        if section == .backlog && nextUpCount > 0 {
                            Text("\(nextUpCount)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .tag(section)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSection = section
                    }
                    .listRowBackground(selectedSection == section ? Color.accentColor.opacity(0.2) : Color.clear)
                }
            }

            // MARK: - Backlog Filters (only show when Backlog is selected)
            if selectedSection == .backlog {
                Section("Filter") {
                    filterRow(label: "Alle Tasks", icon: "tray.full", filter: .all)

                    HStack {
                        Label("Next Up", systemImage: "arrow.up.circle.fill")
                            .accessibilityIdentifier("sidebarFilter_nextUp")
                        Spacer()
                        if nextUpCount > 0 {
                            Text("\(nextUpCount)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .clipShape(Capsule())
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
                            Text("\(tbdCount)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .tag(SidebarFilter.tbd)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFilter = .tbd }
                    .listRowBackground(selectedFilter == .tbd ? Color.accentColor.opacity(0.15) : Color.clear)

                    // Overdue (überfällige Tasks)
                    HStack {
                        Label("Überfällig", systemImage: "exclamationmark.circle.fill")
                            .accessibilityIdentifier("sidebarFilter_overdue")
                        Spacer()
                        if overdueCount > 0 {
                            Text("\(overdueCount)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .tag(SidebarFilter.overdue)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFilter = .overdue }
                    .listRowBackground(selectedFilter == .overdue ? Color.accentColor.opacity(0.15) : Color.clear)

                    // Upcoming (bald fällig)
                    HStack {
                        Label("Bald fällig", systemImage: "clock.fill")
                            .accessibilityIdentifier("sidebarFilter_upcoming")
                        Spacer()
                        if upcomingCount > 0 {
                            Text("\(upcomingCount)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.yellow.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .tag(SidebarFilter.upcoming)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFilter = .upcoming }
                    .listRowBackground(selectedFilter == .upcoming ? Color.accentColor.opacity(0.15) : Color.clear)

                    // Completed (erledigte Tasks)
                    HStack {
                        Label("Erledigt", systemImage: "checkmark.circle.fill")
                            .accessibilityIdentifier("sidebarFilter_completed")
                        Spacer()
                        if completedCount > 0 {
                            Text("\(completedCount)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .tag(SidebarFilter.completed)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFilter = .completed }
                    .listRowBackground(selectedFilter == .completed ? Color.accentColor.opacity(0.15) : Color.clear)
                }

                Section("Kategorien") {
                    categoryRow("income", "Geld verdienen", "dollarsign.circle")
                    categoryRow("maintenance", "Pflege", "wrench.and.screwdriver.fill")
                    categoryRow("recharge", "Energie", "battery.100")
                    categoryRow("learning", "Lernen", "book")
                    categoryRow("giving_back", "Weitergeben", "gift")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FocusBlox")
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

    private func sectionIdentifier(_ section: MainSection) -> String {
        switch section {
        case .backlog: return "backlog"
        case .planning: return "planning"
        case .assign: return "assign"
        case .focus: return "focus"
        case .review: return "review"
        }
    }

    private func filterIdentifier(_ filter: SidebarFilter) -> String {
        switch filter {
        case .all: return "all"
        case .nextUp: return "nextUp"
        case .tbd: return "tbd"
        case .overdue: return "overdue"
        case .upcoming: return "upcoming"
        case .completed: return "completed"
        case .category(let id): return id
        }
    }
}

#Preview {
    SidebarView(
        selectedSection: .constant(.backlog),
        selectedFilter: .constant(.all),
        tbdCount: 3,
        nextUpCount: 5,
        overdueCount: 2,
        upcomingCount: 4,
        completedCount: 10
    )
    .frame(width: 220)
}
