# Context: RW_3.4 — Emotional Nudge (Micro-Tasks)

## Request Summary
Bei chronisch verschobenen Tasks (rescheduleCount >= 3) einen visuellen Blockade-Marker zeigen und "Nur 2 Minuten anfangen" Micro-Sprint anbieten. Ziel: Prokrastinations-Überwindung durch niedrige Einstiegshürde.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | `rescheduleCount` Property (L102), Threshold >= 3 |
| `Sources/Views/BacklogRow.swift` | iOS-Row: Blockade-Marker hinzufügen (L30-70 HStack, L72-84 overlay Pattern) |
| `Sources/Views/TaskDetailSheet.swift` | Inline-Nudge Section hinzufügen (nach L70) |
| `Sources/Services/FocusBlockActionService.swift` | `startImmediate()` (L153-197) für 2-Min-Sprint |
| `Sources/Models/AppSettings.swift` | UserDefaults Pattern für Nudge-Tracking |
| `FocusBloxMac/MacBacklogRow.swift` | macOS: Blockade-Marker + Context Menu (L30-108) |
| `Sources/Services/BehavioralProfileService.swift` | `computeProcrastinationPatterns()` (L253-288) — gleicher Threshold >= 3 |
| `Sources/Models/Discipline.swift` | Farbschema: `.konsequenz` = rot, rescheduleCount >= 2 |
| `Sources/Services/SmartNotificationEngine.swift` | `budgetNudges: 10` (L44) — Budget-Pattern |

## Existing Patterns
- **Overlay-Pattern (BacklogRow):** `isPendingResort` zeigt pulsierenden Border via `.overlay` — gleiche Technik für Blockade-Marker
- **Context Menu (MacBacklogRow):** Bestehende Menu-Items als Pattern für "Nur 2 Minuten"-Eintrag
- **startImmediate():** Bereits mit `durationMinutes`-Parameter — kann direkt 2 übergeben
- **AppSettings @AppStorage:** Singleton mit `@MainActor`, einfache Key-Value Speicherung
- **Discipline Classification:** `rescheduleCount >= 2` → konsequenz (rot/orange) — Blockade-Marker nutzt ähnliche Farbe

## Dependencies
- **Upstream (was RW_3.4 nutzt):**
  - `LocalTask.rescheduleCount` (seit Beginn vorhanden)
  - `FocusBlockActionService.startImmediate()` (RW_3.2 — erledigt)
  - `BehavioralProfileService.computeProcrastinationPatterns()` (RW_0.2 — erledigt)
  - `AppSettings` für Daily-Limit-Tracking
- **Downstream (was RW_3.4 nutzt):**
  - FocusLiveView zeigt den 2-Min-Sprint + "Weitermachen?" Dialog (bereits vorhanden)

## Existing Specs
- `docs/specs/rework/3.4-emotional-nudge.md` — Story-Spec (Akzeptanzkriterien)
- `docs/specs/rework/3.3-follow-up-logic-impl.md` — Vorheriges Feature (ähnliches Pattern)
- `docs/specs/rework/3.2-focus-sprint-impl.md` — startImmediate Dependency

## Neue Dateien (laut Spec)
| Datei | Beschreibung |
|-------|-------------|
| `Sources/Services/EmotionalNudgeService.swift` | rescheduleCount prüfen, Text generieren, Daily-Limit tracken |

## Betroffene Dateien (laut Spec)
| Datei | Änderung |
|-------|----------|
| `Sources/Views/BacklogRow.swift` | + Blockade-Marker (Overlay/Icon bei rescheduleCount >= 3) |
| `Sources/Views/TaskDetailSheet.swift` | + Inline-Nudge Section ("Nur 2 Min anfangen") |
| `FocusBloxMac/MacBacklogRow.swift` | + Blockade-Marker + Context Menu Item |
| `Sources/Models/AppSettings.swift` | + Nudge-Tracking Keys (dailyCount, lastDate, perTaskCount) |

## Data Flow
```
BacklogRow (rescheduleCount >= 3) → Blockade-Marker sichtbar
    ↓
User tippt Row → TaskDetailSheet öffnet
    ↓
Nudge Section (wenn Daily-Limit nicht erreicht)
    ↓
User tippt "Nur 2 Min anfangen"
    ↓
FocusBlockActionService.startImmediate(taskID, durationMinutes: 2)
    ↓
2-Min Focus Sprint startet → FocusLiveView
    ↓
Nach 2 Min: "Weitermachen?" (bestehende Logik)
```

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description | LoC |
|------|-------------|-------------|-----|
| `Sources/Services/EmotionalNudgeService.swift` | CREATE | Text-Rotation, Daily-Limits, rescheduleCount-Check | +60 |
| `Sources/Views/BacklogRow.swift` | MODIFY | Blockade-Marker Overlay bei rescheduleCount >= 3 | +25 |
| `Sources/Views/TaskDetailSheet.swift` | MODIFY | Inline-Nudge Section "Nur 2 Min anfangen" | +30 |
| `Sources/Models/AppSettings.swift` | MODIFY | Nudge-Tracking Keys (dailyCount, lastDate) | +10 |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | Blockade-Marker + Context Menu "Nur 2 Min" | +25 |
| `Sources/Views/FocusLiveView.swift` | MODIFY | "Weitermachen?"-Dialog bei Nudge-Sprint-Ende | +55 |
| `Sources/Views/BacklogView.swift` | MODIFY | isStuck-Prop an BacklogRow weitergeben + Nudge-Callback | +15 |

### Scope Assessment
- Files: 7 (1 new, 6 modified)
- Estimated LoC: +220
- Risk Level: MEDIUM (FocusLiveView checkBlockEnd() ist kritischer Pfad)

### Critical Finding
"Weitermachen?"-Dialog existiert NICHT. Timer-Ablauf zeigt immer SprintReviewSheet.
FocusLiveView.checkBlockEnd() muss Nudge-Sprints erkennen und verzweigen.

### Technical Approach
1. EmotionalNudgeService als stateless struct — Text-Array + Daily-Limit über AppSettings
2. BacklogRow: `isStuck: Bool` Prop (Pattern wie `isPendingResort`), Overlay mit orange Icon
3. TaskDetailSheet: Neue Section wenn rescheduleCount >= 3 + Daily-Limit nicht erreicht
4. FocusLiveView: `isNudgeSprint` Flag (via AppStorage oder Notification userInfo), checkBlockEnd() verzweigt in confirmationDialog statt SprintReview
5. "Ja" verlängert Block um estimatedDuration, "Nein" → normales SprintReview

### Dependencies
- Upstream: LocalTask.rescheduleCount, FocusBlockActionService.startImmediate(), AppSettings
- Downstream: FocusLiveView timer completion, SprintReviewSheet

### Risks
1. FocusLiveView checkBlockEnd() — kritischer Pfad, muss sauber in State-Automat integriert werden
2. BacklogView als versteckte 7. Datei (muss isStuck + Callback an Row weitergeben)
3. Daily-Limit Reset bei Mitternacht — Datums-Vergleich nötig
4. LoC-Budget knapp (~220) aber machbar wenn Dialog als .confirmationDialog statt Custom Sheet
