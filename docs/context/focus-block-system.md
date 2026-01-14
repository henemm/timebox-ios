# Context: Focus Block System

## Request Summary
Implement a 3-view Focus Block system for morning routine planning: Block-Planung (when do I have time?), Task-Zuordnung (what tasks for which blocks?), Live-Modus (active focus, sprint review).

## Related Files
| File | Relevance |
|------|-----------|
| Sources/Models/CalendarEvent.swift | Needs isFocusBlock, taskIDs properties |
| Sources/Models/FocusBlock.swift | NEW: Focus Block model |
| Sources/Services/EventKitRepository.swift | Needs createFocusBlock(), updateFocusBlock() |
| Sources/Views/MainTabView.swift | 4 tabs instead of 2 |
| Sources/Views/BlockPlanningView.swift | NEW: Tab 2 - Block creation |
| Sources/Views/TaskAssignmentView.swift | NEW: Tab 3 - Task assignment |
| Sources/Views/FocusLiveView.swift | NEW: Tab 4 - Live mode |
| Sources/Views/SprintReviewSheet.swift | NEW: Sprint review dialog |

## Existing Patterns
- Event storage in CalendarEvent with notes for metadata
- Timeline-based views using hourHeight and startHour/endHour
- Drop zones with visual feedback (QuarterHourDropZone)
- Drag & Drop with Transferable protocol

## Dependencies
- Upstream: EventKit, SwiftData
- Downstream: All views use EventKitRepository

## Existing Specs
- Plan approved at: `/Users/hem/.claude/plans/frolicking-gliding-ladybug.md`

## Risks & Considerations
- Focus Block data stored in event.notes (limited space)
- Need to handle sprint review when block ends
- Tab navigation between 4 views
