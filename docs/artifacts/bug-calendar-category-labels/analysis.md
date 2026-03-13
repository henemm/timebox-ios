# Bug Analysis: Calendar Category Labels + Cross-Device Sync

**Date:** 2026-03-09
**Reporter:** Henning
**Workflow:** bug-calendar-category-labels

## Bug Description

Two related issues:
1. Calendar event categories set on iOS are NOT visible on macOS
2. Category labels in Calendar View ("Pflege", "Energie", ...) don't match the selection UI labels ("Essentials", "Self Care", ...) — the English labels from the selection are correct per spec

## Agent Investigation Results

### Agent 1: History Check
- 17 category-related commits found (2026-01-14 to 2026-03-03)
- Bug 30 unified English names in `displayName`
- Bug 63 moved category storage from EventKit notes → UserDefaults (to handle read-only events with attendees)
- BACKLOG-008 centralized all category switches into TaskCategory enum

### Agent 2: Data Flow Trace
- **Key finding:** Two separate label properties exist on `TaskCategory`:
  - `displayName` → English: "Earn", "Essentials", "Self Care", "Learn", "Social"
  - `localizedName` → German: "Geld", "Pflege", "Energie", "Lernen", "Geben"
- Selection UI uses `displayName` (correct per spec)
- `CategoryIconBadge` uses `localizedName` (WRONG)
- Storage: `UserDefaults.standard["calendarEventCategories"]` — device-local only

### Agent 3: All Writers
- 13 task category write locations, 5 event category write locations
- All use rawValue strings consistently
- Event categories stored in `UserDefaults.standard` — no CloudKit sync mechanism

### Agent 4: All Scenarios
- Confirmed: UserDefaults does NOT sync to iCloud/CloudKit
- Each device has its own independent category mapping
- No Localizable.strings exist — all labels hardcoded in enum

### Agent 5: Blast Radius
- 49 files reference TaskCategory
- `CategoryIconBadge` is shared component used by BOTH iOS and macOS timeline views
- Fixing it affects both platforms simultaneously (good)
- Similar pattern issue: `RecurrencePattern.displayName` also uses German only

## Hypotheses

### Hypothesis 1: CategoryIconBadge uses wrong property (Label Mismatch)
- **Evidence FOR:** `CategoryIconBadge.swift:10` explicitly uses `category.localizedName` (German)
  while the selection sheet (`SharedSheets.swift:206`) uses `category.displayName` (English)
- **Evidence AGAINST:** None — this is a clear code-level mismatch
- **Probability:** HIGH (99%)
- **Affected files:** `Sources/Views/CategoryIconBadge.swift:10`

### Hypothesis 2: UserDefaults is device-local (Sync Issue)
- **Evidence FOR:** `CalendarEvent.swift:61-64` reads from `UserDefaults.standard`.
  `EventKitRepository.swift:266-275` writes to `UserDefaults.standard`.
  `UserDefaults.standard` does NOT sync between devices.
- **Evidence AGAINST:** None — this is how UserDefaults fundamentally works
- **Probability:** HIGH (99%)
- **Affected files:** `CalendarEvent.swift:61-64`, `EventKitRepository.swift:266-275`

### Hypothesis 3: CloudKit/SwiftData sync issue (rejected)
- **Evidence FOR:** None — categories are NOT stored in SwiftData
- **Evidence AGAINST:** Categories explicitly use UserDefaults, not SwiftData
- **Probability:** LOW (1%) — wrong layer entirely

## Root Causes (Confirmed)

### Root Cause A: Label Mismatch
`CategoryIconBadge.swift:10` uses `category.localizedName` (German: "Pflege", "Energie")
instead of `category.displayName` (English: "Essentials", "Self Care").

The `localizedName` property was apparently an older German translation that was never updated when Bug 30 unified labels to English.

### Root Cause B: No Cross-Device Sync
Event categories are stored in `UserDefaults.standard` which is device-local.
Bug 63 intentionally moved storage FROM iCloud KV Store TO UserDefaults because `eventIdentifier` was unstable across recurring occurrences. But the fix used `calendarItemIdentifier` (which IS stable) — so the reason to avoid iCloud KV Store no longer applies.

The solution is to use `NSUbiquitousKeyValueStore.default` (iCloud Key-Value Store) with `calendarItemIdentifier` as key.

## Debugging Plan

### For Root Cause A (Label Mismatch):
- **Confirm:** Read `CategoryIconBadge.swift:10` — does it say `localizedName`? YES (verified)
- **Disprove:** If it said `displayName`, labels would already be English

### For Root Cause B (Sync):
- **Confirm:** Set category on iOS → check macOS UserDefaults for same key → absent
- **Disprove:** If using iCloud KV Store, both devices would see same data

## Blast Radius

### Fix A (Label change):
- `CategoryIconBadge.swift` — 1 line change
- Affects: All calendar event badges on iOS AND macOS (both use same shared component)
- Tests: `CategoryIconBadgeTests.swift` needs update (references to `localizedName` → `displayName`)
- Risk: LOW — purely visual, no data change

### Fix B (Sync change):
- `CalendarEvent.swift` — change `UserDefaults.standard` to `NSUbiquitousKeyValueStore.default`
- `EventKitRepository.swift` — change `UserDefaults.standard` to `NSUbiquitousKeyValueStore.default`
- Tests: `CalendarCategoryMappingTests.swift`, `CalendarEventCategoryTests.swift` need update
- Risk: MEDIUM — need to handle iCloud KV Store 1MB limit, sync delays, initial migration from UserDefaults

### Other affected features:
- Review statistics (uses category for grouping) — not affected (reads from same source)
- BacklogView search (uses `localizedName`) — should also switch to `displayName`
