# Tests: Kalender-App Deep Link

## Unit Tests (CalendarDeepLinkTests.swift)

### Test 1: calendarAppURL returns correct calshow URL
- Input: CalendarEvent with startDate = 2026-03-09 14:00:00
- Expected: URL string starts with "calshow:" and contains Unix timestamp of startDate
- Bricht Zeile: `CalendarEvent.calendarAppURL` computed property

### Test 2: calendarAppURL works for all-day events
- Input: CalendarEvent with isAllDay = true, startDate = 2026-03-09
- Expected: URL starts with "calshow:" (uses start of day timestamp)
- Bricht Zeile: `CalendarEvent.calendarAppURL` — muss auch fuer ganztaegige Events funktionieren

### Test 3: FocusBlock events should NOT show deep link
- Input: CalendarEvent with notes containing "focusBlock:true"
- Expected: `isFocusBlock == true` (already exists, verify prerequisite)
- Bricht Zeile: bestehende `isFocusBlock` Property — Voraussetzung fuer UI-Filter

## UI Tests (CalendarDeepLinkUITests.swift)

### Test 4: "In Kalender oeffnen" button visible for external events
- Tap on external calendar event in timeline → EventCategorySheet opens
- Verify: Button "In Kalender oeffnen" is visible
- Bricht Zeile: Button in EventCategorySheet (SharedSheets.swift)

### Test 5: "In Kalender oeffnen" button NOT visible for FocusBlocks
- Tap on FocusBlock in timeline → FocusBlockTasksSheet opens (not EventCategorySheet)
- FocusBlocks open a different sheet entirely, so the button naturally doesn't appear
- Bricht Zeile: BlockPlanningView's onTapBlock handler (already separate from onTapEvent)
