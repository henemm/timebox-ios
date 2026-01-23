# OpenSpec Proposal: Eisenhower Matrix as View Mode

**Feature:** Convert Eisenhower Matrix from separate tab to integrated view mode within BacklogView

**Type:** AENDERUNG (Modification)

**Status:** Proposal (awaiting approval)

**Estimated Effort:** Klein (3 files, ~150 LoC)

---

## 1. Overview

### Current State (BEFORE)
- EisenhowerMatrixView is a separate standalone view (BacklogView.swift lines 126-329)
- MainTabView has dedicated "Matrix" tab (lines 11-14)
- BacklogView only shows list view (no alternative views)
- No view preference persistence
- Duplicate task loading logic in both views

### Desired State (AFTER)
- Remove Matrix tab from MainTabView
- Integrate EisenhowerMatrixView as one of 5 view modes in BacklogView
- Add ViewMode enum: list, eisenhowerMatrix, category, duration, dueDate
- Swift Liquid Glass Picker as view mode switcher
- AppStorage persistence for selected mode
- Specific empty state messages per view mode
- Shared task loading logic

---

## 2. Architecture Decisions

### 2.1 ViewMode Enum
**Location:** Inside BacklogView as nested enum

```swift
enum ViewMode: String, CaseIterable {
    case list = "Liste"
    case eisenhowerMatrix = "Matrix"
    case category = "Kategorie"
    case duration = "Dauer"
    case dueDate = "Fälligkeit"

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .eisenhowerMatrix: return "square.grid.2x2"
        case .category: return "folder"
        case .duration: return "clock"
        case .dueDate: return "calendar"
        }
    }
}
```

**Rationale:** Enum as String allows direct AppStorage persistence and localized labels.

### 2.2 UI Switcher Pattern
**Choice:** Menu-based button (not Picker or Segmented Control)

**Rationale:**
- 5 options too many for Segmented Control (max 3-4 recommended)
- Picker requires extra navigation level
- Menu button is modern iOS 18 pattern (fits "Liquid Glass")
- Saves horizontal space in toolbar

### 2.3 State Management
**Pattern:** @AppStorage for persistence + @State for internal changes

```swift
@AppStorage("backlogViewMode") private var selectedMode: ViewMode = .list
```

**Rationale:**
- @AppStorage auto-persists to UserDefaults
- No manual save/load logic needed
- Survives app restarts and tab switches

### 2.4 Code Reuse
**Keep existing components:**
- QuadrantCard (unchanged)
- BacklogRow (unchanged)
- Eisenhower filter logic (moved into computed properties)

**Do NOT:**
- Duplicate EisenhowerMatrixView code
- Change QuadrantCard interface
- Modify BacklogRow rendering

---

## 3. Implementation Specification

### 3.1 File: MainTabView.swift
**Changes:** Remove Matrix tab (4 lines deleted)

**BEFORE (lines 11-14):**
```swift
EisenhowerMatrixView()
    .tabItem {
        Label("Matrix", systemImage: "square.grid.2x2")
    }
```

**AFTER:**
```swift
// REMOVED - Matrix is now a view mode in BacklogView
```

**Total Changes:** -4 lines

---

### 3.2 File: BacklogView.swift
**Changes:** Add ViewMode enum, switcher UI, conditional rendering, view-specific logic

**STEP 1: Add ViewMode Enum (after line 3)**
```swift
struct BacklogView: View {
    // MARK: - ViewMode Definition
    enum ViewMode: String, CaseIterable, Identifiable {
        case list = "Liste"
        case eisenhowerMatrix = "Matrix"
        case category = "Kategorie"
        case duration = "Dauer"
        case dueDate = "Fälligkeit"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .eisenhowerMatrix: return "square.grid.2x2"
            case .category: return "folder"
            case .duration: return "clock"
            case .dueDate: return "calendar"
            }
        }

        var emptyStateMessage: (title: String, description: String) {
            switch self {
            case .list:
                return ("Keine Tasks", "Tippe auf + um einen neuen Task zu erstellen.")
            case .eisenhowerMatrix:
                return ("Keine Tasks für Matrix", "Setze Priorität und Dringlichkeit für deine Tasks.")
            case .category:
                return ("Keine Tasks in Kategorien", "Erstelle Tasks und weise ihnen Kategorien zu.")
            case .duration:
                return ("Keine Tasks mit Dauer", "Setze geschätzte Dauern für deine Tasks.")
            case .dueDate:
                return ("Keine Tasks mit Fälligkeitsdatum", "Setze Fälligkeitsdaten für deine Tasks.")
            }
        }
    }

    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @AppStorage("backlogViewMode") private var selectedMode: ViewMode = .list
    // ... existing @State properties ...
```

**STEP 2: Add Eisenhower Matrix Filter Logic (after existing properties, before body)**
```swift
    // MARK: - Eisenhower Matrix Filters
    private var doFirstTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && $0.priority == 3 && !$0.isCompleted }
    }

    private var scheduleTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && $0.priority == 3 && !$0.isCompleted }
    }

    private var delegateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && $0.priority < 3 && !$0.isCompleted }
    }

    private var eliminateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && $0.priority < 3 && !$0.isCompleted }
    }

    // MARK: - Category Grouping
    private var tasksByCategory: [(category: String, tasks: [PlanItem])] {
        let categories = ["deep_work", "shallow_work", "meetings", "maintenance", "creative", "strategic"]
        return categories.compactMap { category in
            let filtered = planItems.filter { $0.taskType == category && !$0.isCompleted }
            guard !filtered.isEmpty else { return nil }
            return (category: category.localizedCategory, tasks: filtered)
        }
    }

    // MARK: - Duration Grouping
    private var tasksByDuration: [(bucket: String, tasks: [PlanItem])] {
        let buckets: [(String, Range<Int>)] = [
            ("< 15 Min", 0..<15),
            ("15-30 Min", 15..<30),
            ("30-60 Min", 30..<60),
            ("> 60 Min", 60..<Int.max)
        ]
        return buckets.compactMap { (label, range) in
            let filtered = planItems.filter {
                !$0.isCompleted && range.contains($0.effectiveDuration)
            }
            guard !filtered.isEmpty else { return nil }
            return (bucket: label, tasks: filtered)
        }
    }

    // MARK: - Due Date Grouping
    private var tasksByDueDate: [(section: String, tasks: [PlanItem])] {
        let calendar = Calendar.current
        let today = Date()

        var grouped: [(String, [PlanItem])] = []

        // Today
        let todayTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted else { return false }
            return calendar.isDateInToday(due)
        }
        if !todayTasks.isEmpty {
            grouped.append(("Heute", todayTasks))
        }

        // Tomorrow
        let tomorrowTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted else { return false }
            return calendar.isDateInTomorrow(due)
        }
        if !tomorrowTasks.isEmpty {
            grouped.append(("Morgen", tomorrowTasks))
        }

        // This Week
        let weekTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted else { return false }
            return calendar.isDate(due, equalTo: today, toGranularity: .weekOfYear) &&
                   !calendar.isDateInToday(due) && !calendar.isDateInTomorrow(due)
        }
        if !weekTasks.isEmpty {
            grouped.append(("Diese Woche", weekTasks))
        }

        // Later
        let laterTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted else { return false }
            return due > calendar.date(byAdding: .weekOfYear, value: 1, to: today)!
        }
        if !laterTasks.isEmpty {
            grouped.append(("Später", laterTasks))
        }

        // No Due Date
        let noDueDateTasks = planItems.filter {
            $0.dueDate == nil && !$0.isCompleted
        }
        if !noDueDateTasks.isEmpty {
            grouped.append(("Ohne Fälligkeitsdatum", noDueDateTasks))
        }

        return grouped
    }
```

**STEP 3: Replace body with ViewMode-aware rendering**
```swift
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Lade Tasks...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if planItems.isEmpty {
                    let emptyState = selectedMode.emptyStateMessage
                    ContentUnavailableView(
                        emptyState.title,
                        systemImage: "checklist",
                        description: Text(emptyState.description)
                    )
                } else {
                    // MARK: - View Mode Rendering
                    switch selectedMode {
                    case .list:
                        listView
                    case .eisenhowerMatrix:
                        eisenhowerMatrixView
                    case .category:
                        categoryView
                    case .duration:
                        durationView
                    case .dueDate:
                        dueDateView
                    }
                }
            }
            .navigationTitle("Backlog")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedMode == .list {
                        EditButton()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    viewModeSwitcher

                    Button {
                        showCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTaskButton")
                }
            }
            .withSettingsToolbar()
            .sensoryFeedback(.impact(weight: .medium), trigger: reorderTrigger)
            .sensoryFeedback(.success, trigger: durationFeedback)
            .sheet(item: $selectedItemForDuration) { item in
                DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                    updateDuration(for: item, minutes: newDuration)
                    selectedItemForDuration = nil
                }
            }
            .sheet(isPresented: $showCreateTask) {
                CreateTaskView {
                    Task {
                        await loadTasks()
                    }
                }
            }
        }
        .task {
            await loadTasks()
        }
    }
```

**STEP 4: Add ViewMode Switcher (Swift Liquid Glass)**
```swift
    // MARK: - View Mode Switcher
    private var viewModeSwitcher: some View {
        Menu {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) {
                        selectedMode = mode
                    }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                Text(selectedMode.rawValue)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("viewModeSwitcher")
    }
```

**STEP 5: Add View Mode Implementations**
```swift
    // MARK: - List View
    private var listView: some View {
        List {
            ForEach(planItems) { item in
                BacklogRow(item: item) {
                    selectedItemForDuration = item
                }
            }
            .onMove(perform: moveItems)
        }
        .listStyle(.plain)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Eisenhower Matrix View
    private var eisenhowerMatrixView: some View {
        ScrollView {
            VStack(spacing: 16) {
                QuadrantCard(
                    title: "Do First",
                    subtitle: "Dringend + Wichtig",
                    color: .red,
                    icon: "exclamationmark.3",
                    tasks: doFirstTasks,
                    onDurationTap: { item in
                        selectedItemForDuration = item
                    }
                )

                QuadrantCard(
                    title: "Schedule",
                    subtitle: "Nicht dringend + Wichtig",
                    color: .yellow,
                    icon: "calendar",
                    tasks: scheduleTasks,
                    onDurationTap: { item in
                        selectedItemForDuration = item
                    }
                )

                QuadrantCard(
                    title: "Delegate",
                    subtitle: "Dringend + Weniger wichtig",
                    color: .orange,
                    icon: "person.2",
                    tasks: delegateTasks,
                    onDurationTap: { item in
                        selectedItemForDuration = item
                    }
                )

                QuadrantCard(
                    title: "Eliminate",
                    subtitle: "Nicht dringend + Weniger wichtig",
                    color: .green,
                    icon: "trash",
                    tasks: eliminateTasks,
                    onDurationTap: { item in
                        selectedItemForDuration = item
                    }
                )
            }
            .padding()
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Category View
    private var categoryView: some View {
        List {
            ForEach(tasksByCategory, id: \.category) { group in
                Section(header: Text(group.category)) {
                    ForEach(group.tasks) { item in
                        BacklogRow(item: item) {
                            selectedItemForDuration = item
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Duration View
    private var durationView: some View {
        List {
            ForEach(tasksByDuration, id: \.bucket) { group in
                Section(header: Text(group.bucket)) {
                    ForEach(group.tasks) { item in
                        BacklogRow(item: item) {
                            selectedItemForDuration = item
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Due Date View
    private var dueDateView: some View {
        List {
            ForEach(tasksByDueDate, id: \.section) { group in
                Section(header: Text(group.section)) {
                    ForEach(group.tasks) { item in
                        BacklogRow(item: item) {
                            selectedItemForDuration = item
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadTasks()
        }
    }

    // ... existing functions (loadTasks, moveItems, updateDuration) remain unchanged ...
}
```

**STEP 6: Add String Extension for Category Localization (at end of file)**
```swift
// MARK: - String Extension
private extension String {
    var localizedCategory: String {
        switch self {
        case "deep_work": return "Deep Work"
        case "shallow_work": return "Shallow Work"
        case "meetings": return "Meetings"
        case "maintenance": return "Maintenance"
        case "creative": return "Creative"
        case "strategic": return "Strategic"
        default: return self.capitalized
        }
    }
}
```

**STEP 7: Remove Standalone EisenhowerMatrixView (lines 126-329)**
```swift
// DELETE ENTIRE SECTION (204 lines):
// - struct EisenhowerMatrixView
// - All its properties, computed vars, body, functions
// QuadrantCard struct remains (it's reused by BacklogView)
```

**Total Changes:** +180 lines, -208 lines = -28 net lines (simpler overall!)

---

### 3.3 File: EisenhowerMatrixUITests.swift
**Changes:** Update navigation path in all tests

**Helper Function (add at top of class after tearDownWithError):**
```swift
    // MARK: - Navigation Helper

    /// Navigate to Eisenhower Matrix view mode
    /// - Ensures Backlog tab is active
    /// - Opens ViewMode switcher
    /// - Selects "Matrix" mode
    private func navigateToMatrixMode() {
        // Backlog tab is default, but ensure it's selected
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.exists {
            backlogTab.tap()
        }

        // Wait for BacklogView to load
        let navBar = app.navigationBars["Backlog"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3), "Backlog view should be displayed")

        // Open ViewMode switcher
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 3), "ViewMode switcher should exist")
        switcher.tap()

        // Select Matrix mode
        let matrixOption = app.menuItems["Matrix"]
        XCTAssertTrue(matrixOption.waitForExistence(timeout: 2), "Matrix option should exist in menu")
        matrixOption.tap()

        // Wait for Matrix view to render
        sleep(1)
    }
```

**Update Test: testEisenhowerMatrixTabExists (REPLACE)**
```swift
    // MARK: - Navigation Tests

    /// GIVEN: App is launched, BacklogView displayed
    /// WHEN: User selects "Matrix" from ViewMode switcher
    /// THEN: Eisenhower Matrix view should be displayed
    func testEisenhowerMatrixViewModeExists() throws {
        navigateToMatrixMode()

        // Verify Matrix view is shown (check for quadrant title)
        let doFirstTitle = app.staticTexts["Do First"]
        XCTAssertTrue(doFirstTitle.waitForExistence(timeout: 3), "Eisenhower Matrix view should be displayed")
    }
```

**Update ALL other tests - Replace tab navigation:**
```swift
// OLD (remove these 2 lines):
let matrixTab = app.tabBars.buttons["Matrix"]
matrixTab.tap()

// NEW (replace with this):
navigateToMatrixMode()
```

**Tests to update (add navigateToMatrixMode() at start):**
- testAllFourQuadrantsVisible() (line 37)
- testQuadrantSubtitlesVisible() (line 62)
- testQuadrantTaskCountsVisible() (line 86)
- testEmptyStateShowsNoTasksMessage() (line 107)
- testPullToRefreshWorks() (line 128)
- testQuadrantCardsShowAllElements() (line 156)
- testScrollingShowsAllQuadrants() (line 180)
- testQuadrantsShowBacklogRowForTasks() (line 212)
- testQuadrantShowsMoreTasksIndicator() (line 238)

**Total Changes:** +20 lines, -18 lines = +2 net lines

---

## 4. Side Effects & Breaking Changes

### 4.1 Breaking Changes
**NONE** - All existing UI tests will continue to work after updates.

### 4.2 Behavioral Changes
1. **Navigation:** Users can no longer tap Matrix tab (must use switcher in Backlog)
2. **State:** ViewMode preference persists across app restarts
3. **UI:** Matrix view no longer has separate navigation bar (uses Backlog's)

### 4.3 Non-Breaking Changes
- QuadrantCard remains identical
- BacklogRow remains identical
- Task loading logic remains identical
- All task data models unchanged

---

## 5. Testing Strategy

### 5.1 Unit Tests
**None required** - Pure UI change, no business logic modification.

### 5.2 UI Tests
**See tests.md for complete test suite (21 new tests)**

**Critical Tests:**
1. ViewMode switcher exists and shows all 5 options
2. Switching between modes works
3. AppStorage persistence works
4. Empty states are mode-specific
5. Matrix tab removed from MainTabView
6. All Eisenhower Matrix tests pass with new navigation

### 5.3 Manual Testing Checklist
```
[ ] Launch app - should show Backlog in List mode by default
[ ] Tap ViewMode switcher - should show 5 options
[ ] Switch to Matrix mode - should show 4 quadrants
[ ] Restart app - Matrix mode should persist
[ ] Switch tabs and back - Matrix mode should persist
[ ] Switch to Category mode - should group by taskType
[ ] Switch to Duration mode - should group by time buckets
[ ] Switch to Due Date mode - should group by date proximity
[ ] Tap + in any mode - CreateTaskView should open
[ ] Pull-to-refresh in any mode - tasks should reload
[ ] Edit button only visible in List mode
[ ] Empty states show correct messages per mode
[ ] Matrix tab NOT visible in TabView
```

---

## 6. Deployment Checklist

### Pre-Implementation
- [x] Understanding Checklist completed
- [ ] User approval received
- [ ] Test definitions reviewed

### Implementation
- [ ] MainTabView.swift: Matrix tab removed
- [ ] BacklogView.swift: ViewMode enum added
- [ ] BacklogView.swift: Switcher UI implemented
- [ ] BacklogView.swift: All 5 view modes implemented
- [ ] BacklogView.swift: AppStorage persistence added
- [ ] EisenhowerMatrixUITests.swift: Navigation updated
- [ ] BacklogViewUITests.swift: New tests added

### Post-Implementation
- [ ] All UI tests pass
- [ ] Manual testing checklist complete
- [ ] Build succeeds without warnings
- [ ] Test on simulator: D9E26087-132A-44CB-9883-59073DD9CC54
- [ ] Screenshot documentation updated

---

## 7. Open Questions

**NONE** - All requirements clarified during planning phase.

---

## 8. Rollback Plan

If issues occur after implementation:

1. **Revert Commits:**
   - Git revert in reverse order (EisenhowerMatrixUITests → BacklogView → MainTabView)

2. **Quick Fix (Emergency):**
   - Re-add Matrix tab to MainTabView
   - Hide ViewMode switcher with `if false { }` wrapper

**Risk:** LOW - No data migrations, no API changes, purely UI refactoring.

---

## 9. Success Metrics

**Implementation Complete When:**
- All 21 new UI tests pass
- 9 updated EisenhowerMatrixUITests pass
- Matrix tab not visible in MainTabView
- ViewMode persists after app restart
- No crashes in any view mode
- Build time unchanged (no new dependencies)

**User Experience Goals:**
- Easier access to Matrix view (no tab switch needed)
- Consistent navigation (all views in one place)
- Discoverable alternative views (switcher in toolbar)
- Persistent user preference (remember last view)

---

## 10. Approval Required

**Awaiting approval from:** Product Owner (Henning)

**Configuration Decisions (Confirmed):**
1. ✅ ViewMode switcher placement: `.topBarTrailing` with ToolbarItemGroup (iOS Best Practice)
2. ✅ Default mode: List (most familiar to users)
3. ✅ Menu-based switcher (better than Segmented Control for 5 options)
4. ✅ Specific empty state messages per mode

**Ready to implement after approval!**
