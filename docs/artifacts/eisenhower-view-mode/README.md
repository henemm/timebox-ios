# Eisenhower Matrix as View Mode - Feature Planning

**Status:** Proposal (awaiting approval)

**Type:** AENDERUNG (Modification of existing feature)

**Estimated Effort:** Klein (3 files, ~150 LoC)

---

## Quick Summary

This feature converts the Eisenhower Matrix from a separate tab to an integrated view mode within BacklogView, along with 4 additional view modes (Category, Duration, Due Date).

**Current State:**
- Separate "Matrix" tab in MainTabView
- BacklogView only shows list view
- No view mode persistence

**After Implementation:**
- Matrix tab removed
- 5 view modes in BacklogView: List, Matrix, Category, Duration, Due Date
- Swift Liquid Glass switcher in toolbar
- AppStorage persistence
- Specific empty states per mode

---

## Documents in This Artifact

### 1. tests.md
**TDD Red Phase: Test Definitions**
- 21 new UI tests for view mode functionality
- 9 modified tests for Eisenhower Matrix navigation
- Complete test coverage for all 5 view modes
- AppStorage persistence tests
- Empty state tests per mode

### 2. spec.md
**OpenSpec Proposal: Technical Specification**
- Complete architecture decisions
- ViewMode enum structure
- Swift Liquid Glass switcher implementation
- Exact code changes for 3 files (line-by-line)
- Side effects analysis
- Testing strategy
- Deployment checklist

### 3. README.md (this file)
**Overview and navigation**

---

## Files to be Changed

1. **MainTabView.swift**
   - Remove Matrix tab (4 lines)
   - Net change: -4 lines

2. **BacklogView.swift**
   - Add ViewMode enum with 5 cases
   - Add Swift Liquid Glass switcher
   - Add 5 view mode implementations
   - Remove standalone EisenhowerMatrixView
   - Net change: -28 lines (simpler overall!)

3. **EisenhowerMatrixUITests.swift**
   - Update navigation helper
   - Update 9 existing tests
   - Net change: +2 lines

**Total:** ~150 LoC changes (within 250 limit)

---

## Key Architecture Decisions

1. **ViewMode Enum:** String-based for AppStorage compatibility
2. **UI Switcher:** Menu button (not Picker/Segmented) - 5 options need space
3. **State Management:** @AppStorage for auto-persistence
4. **Code Reuse:** Keep QuadrantCard, BacklogRow unchanged
5. **Filter Logic:** Move into computed properties (no duplication)

---

## Test Coverage

**Total Tests:** 21 new + 9 modified = 30 tests

**Coverage Areas:**
- ViewMode switcher UI (3 tests)
- ViewMode switching (4 tests)
- AppStorage persistence (2 tests)
- Empty states per mode (5 tests)
- MainTabView changes (2 tests)
- Cross-mode interactions (2 tests)
- Eisenhower Matrix navigation (9 modified tests)

**Test Execution Time:** ~5-8 minutes

---

## Manual Testing Checklist

```
[ ] ViewMode switcher visible in toolbar
[ ] All 5 modes selectable from menu
[ ] Default mode is List
[ ] Matrix mode shows 4 quadrants
[ ] Category mode groups by taskType
[ ] Duration mode groups by time buckets
[ ] Due Date mode groups by date proximity
[ ] ViewMode persists after app restart
[ ] ViewMode persists across tab switches
[ ] + button works in all modes
[ ] Pull-to-refresh works in all modes
[ ] Edit button only in List mode
[ ] Empty states show correct messages
[ ] Matrix tab NOT in TabView
```

---

## Configuration Decisions (Confirmed)

1. ✅ **Switcher Placement:** `.topBarTrailing` with ToolbarItemGroup (iOS Best Practice)
2. ✅ **Default Mode:** List mode as default
3. ✅ **Empty Messages:** Specific messages per mode
4. ✅ **Switcher Style:** Menu button (better than Segmented Control for 5 options)

---

## Next Steps

1. **USER:** Review tests.md and spec.md
2. **USER:** Answer open questions (if any)
3. **USER:** Approve with "approved" message
4. **CLAUDE:** Run `/implement` to execute implementation
5. **CLAUDE:** Run UI tests to verify (TDD Green phase)
6. **USER:** Manual testing on device

---

## Success Criteria

Implementation complete when:
- All 30 UI tests pass (21 new + 9 modified)
- Matrix tab not visible
- ViewMode persists correctly
- No crashes in any mode
- Build succeeds without warnings

---

## Related Documents

- Feature planning context in user message
- TDD Red tests: `tests.md`
- Implementation spec: `spec.md`
- Test simulator: D9E26087-132A-44CB-9883-59073DD9CC54 (Timebox)

---

**Ready for approval!**
