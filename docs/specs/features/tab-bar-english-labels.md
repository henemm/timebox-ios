# Tab Bar English Labels

## Summary
Consistent English labels for Tab Bar (iOS) and Navigation Sections (macOS) with "Blox" as brand term.

## Changes

### iOS Tab Labels (`MainTabView.swift`)

| Before | After |
|--------|-------|
| Backlog | Backlog |
| Blöcke | **Blox** |
| Fokus | **Focus** |
| Rückblick | **Review** |

### macOS Navigation Sections (`SidebarView.swift` MainSection enum)

| Before | After |
|--------|-------|
| Backlog | Backlog |
| Planen | **Blox** |
| Zuweisen | **Assign** |
| Focus | Focus |
| Review | Review |

### Navigation Titles (both platforms)

| File | Before | After |
|------|--------|-------|
| `DailyReviewView.swift` | "Rückblick" | **"Review"** |
| `MacPlanningView.swift` | "Planen" | **"Blox"** |
| `MacAssignView.swift` | "Zuweisen" | **"Assign"** |

Already correct: BlockPlanningView ("Blox"), FocusLiveView ("Focus"), TaskAssignmentView ("Assign"), MacFocusView ("Focus"), MacReviewView ("Review").

## Rationale
- Consistent English UI on BOTH platforms
- Identical naming across iOS and macOS
- "Blox" as unique brand term

## Files
- `Sources/Views/MainTabView.swift` - iOS tab labels
- `Sources/Views/DailyReviewView.swift` - Navigation title
- `FocusBloxMac/SidebarView.swift` - MainSection enum (macOS navigation labels)
- `FocusBloxMac/MacPlanningView.swift` - Navigation title
- `FocusBloxMac/MacAssignView.swift` - Navigation title

## Approved
2026-01-29 (original iOS-only)
2026-03-04 (updated: iOS + macOS)
