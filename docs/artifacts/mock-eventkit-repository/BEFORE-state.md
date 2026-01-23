# BEFORE State Documentation - Phase 2

**Date:** 2026-01-16
**Feature:** Mock EventKit Repository Phase 2 - View Injection

## Problem: Cannot Capture BEFORE Screenshots

**Reason:** The app crashes in iOS Simulator when attempting to access EventKit without device permissions.

### Test Execution Log

```
Test Case '-[TimeBoxUITests.BeforeScreenshotTest testCaptureBeforeBlockPlanningView]' failed
- Wait for app to idle: 60+ seconds
- Error: "Application com.henning.timebox is not running"
- Error: "Element Target Application cannot request screenshot data because it does not exist"

Test Case '-[TimeBoxUITests.BeforeScreenshotTest testCaptureBeforeBacklogView]' failed
- Same behavior: App crashes after 60s wait
```

### Current State Analysis

**BlockPlanningView.swift:**
- Line ~4: `@State private var eventKitRepo = EventKitRepository()`
- Direct instantiation of real EventKitRepository
- Tries to access EventKit.framework → Permission denied → App hangs/crashes

**Impact:**
- 8 UI Tests failing (Timeline tests in SchedulingUITests)
- Cannot run app in Simulator for UI testing
- Blocks automated testing workflow

### This Is WHY We Need Phase 2

Phase 2 implements SwiftUI Environment injection so:
1. **Production mode:** Uses real EventKitRepository (with permissions)
2. **UI Test mode:** Uses MockEventKitRepository (no permissions needed)
3. **Result:** Tests can run in Simulator

### AFTER Screenshots

After Phase 2 implementation, BeforeScreenshotTest will be run with `-UITesting` flag to capture AFTER screenshots showing the working state.

---

**Status:** BEFORE state documented (actual screenshots impossible due to crash)
**Next:** Implement Phase 2 View Injection → Capture AFTER screenshots → Compare states
