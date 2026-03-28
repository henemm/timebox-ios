# Context: MAC_027 — Focus Sprint Workflow Parität

## Request Summary
macOS soll Feature-Parität mit iOS für den Focus Sprint Workflow erhalten. Bündelt drei Sub-Features: Sidebar-Switch bei Sprint-Start, Follow-up in SprintReview, Emotional Nudge Dialog. ~90 LoC gesamt.

## Related Files

| File | Relevance |
|------|-----------|
| `FocusBloxMac/MacFocusView.swift` | **Hauptdatei** — MacSprintReviewSheet (Z.654-905) braucht Follow-up + Nudge Dialog |
| `FocusBloxMac/ContentView.swift` | Sidebar-Navigation, `selectedSection` Binding — Switch-Logik |
| `FocusBloxMac/FocusBloxMacApp.swift` | `@State selectedSection` (Z.204) — Binding-Quelle |
| `Sources/Views/FocusLiveView.swift` | iOS-Referenz: Nudge Dialog (Z.169-180), extendNudgeBlock (Z.731-758) |
| `Sources/Views/SprintReviewSheet.swift` | iOS-Referenz: Follow-up UI (Z.216-265) |
| `Sources/Services/FocusBlockActionService.swift` | Shared: `abortWithFollowUp()`, `startImmediate()` |
| `Sources/Services/EmotionalNudgeService.swift` | Nudge-Text-Rotation + Daily Limits |

## Sub-Features

### 1. Sidebar-Switch bei Sprint-Start (~10 LoC)
- **Problem:** Wenn Sprint startet, bleibt macOS auf Backlog statt zu Focus zu wechseln
- **iOS:** Tab-basiert → automatisch
- **macOS:** `selectedSection` Binding muss von `.backlog` auf `.focus` wechseln
- **Wo:** ContentView.swift oder FocusBloxMacApp.swift — nach `startImmediate()` Erfolg

### 2. Follow-up in SprintReview (~50 LoC)
- **Problem:** MacSprintReviewSheet zeigt incomplete Tasks, aber ohne Follow-up-Option
- **iOS:** SprintReviewSheet hat progressNotes TextField + "Follow-up erstellen" Button
- **macOS fehlt:** `progressNotes`, `followUpCreated`, `createFollowUp()`, UI-Elemente
- **Wo:** MacFocusView.swift, MacSprintReviewSheet (nach Z.813)

### 3. Emotional Nudge Dialog (~30 LoC)
- **Problem:** Wenn 2-Min-Block endet, geht macOS direkt in Review statt Nudge zu zeigen
- **iOS:** confirmationDialog "Weitermachen?" bei Block ≤2min
- **macOS fehlt:** `showNudgeContinueDialog`, Dialog, `extendNudgeBlock()`
- **Wo:** MacFocusView.swift, `checkBlockEnd()` (Z.544-575)

## Existing Patterns
- macOS SprintReviewSheet folgt gleicher Struktur wie iOS (Sections, Task-Rows)
- FocusBlockActionService ist shared — kein neuer Service nötig
- EmotionalNudgeService existiert bereits shared

## Dependencies
- **Upstream:** FocusBlockActionService, EmotionalNudgeService, EventKitRepository
- **Downstream:** MacSprintReviewSheet braucht `@Environment(\.modelContext)` für Follow-up

## Existing Specs
- `docs/specs/rework/3.2-focus-sprint.md` — Sprint-System
- `docs/specs/rework/3.4-emotional-nudge.md` — Nudge-System
- `docs/context/RW_3.3-follow-up-logic.md` — Follow-up Context
- `docs/context/RW_3.4-emotional-nudge.md` — Nudge Context

## Risks & Considerations
- MacSprintReviewSheet braucht `modelContext` Environment — aktuell nicht injiziert
- Sidebar-Switch-Mechanismus: Binding-Propagation von App-Level bis ContentView prüfen
- Nudge-Threshold (2 Min) ist in iOS hardcoded — übernehmen
- MacPlanningView.startFocusSprintOnMac() hat keinen Zugriff auf selectedSection Binding
- `isAborted`-Flag existiert auf macOS nicht — Follow-up wird bei ALLEN incomplete Tasks angezeigt (nicht nur Abort)

## Analysis

### Type
Feature (macOS-Parität mit iOS)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| FocusBloxMac/ContentView.swift | MODIFY | Sidebar-Switch nach startImmediate() Erfolg (~8 LoC) |
| FocusBloxMac/MacFocusView.swift | MODIFY | Follow-up UI in MacSprintReviewSheet + Nudge Dialog in checkBlockEnd() (~90 LoC) |
| FocusBloxMac/MacPlanningView.swift | MODIFY | Sidebar-Switch Binding durchreichen (~10 LoC) |

### Scope Assessment
- Files: 3 (Production) + 1 (Tests)
- Estimated LoC: ~110 Production + ~120 Tests
- Risk Level: LOW-MEDIUM

### Technical Approach
1. **Sidebar-Switch:** In ContentView.startFocusSprint() und startNudgeSprint() nach `.started` Case `selectedSection = .focus` setzen. MacPlanningView braucht Binding-Argument.
2. **Emotional Nudge:** In MacFocusView.checkBlockEnd() Block-Dauer prüfen (≤2min → Nudge Dialog, sonst Review). confirmationDialog + extendNudgeBlock() hinzufügen.
3. **Follow-up:** MacSprintReviewSheet bekommt `@Environment(\.modelContext)`. Incomplete Tasks Section erweitert um progressNotes TextField + "Follow-up erstellen" Button. Follow-up wird bei ALLEN incomplete Tasks angeboten (kein isAborted-Gate auf macOS).

### Reihenfolge
1. Sidebar-Switch (kleinste Änderung, am schnellsten verifizierbar)
2. Emotional Nudge Dialog (nur MacFocusView, kein Environment-Problem)
3. Follow-up in MacSprintReviewSheet (modelContext-Verifikation nötig)

### Dependencies
- **Upstream:** FocusBlockActionService (shared), EmotionalNudgeService (shared), EventKitRepository
- **Downstream:** Keine — rein additive Änderungen
