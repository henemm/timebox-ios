# Context: RW_3.3 Follow-up Logic

## Request Summary
Beim Abbruch eines Focus Blocks soll der Fortschritt festgehalten und automatisch eine Anschlussaufgabe erstellt werden ("Weiter: [Titel]"), die Kategorie, Importance, Tags und Restdauer erbt.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | + `parentTaskID`, + `progressNote` Properties |
| `Sources/Services/FocusBlockActionService.swift` | + `abortWithFollowUp()` — hat bereits `followUpTask()` als Vorlage |
| `Sources/Views/SprintReviewSheet.swift` | + Abbruch-Flow mit Freitext-Eingabe |
| `Sources/Views/FocusLiveView.swift` | Ruft SprintReviewSheet auf, hat bereits Follow-up-Flow |
| `Sources/Models/FocusBlock.swift` | FocusBlock-Modell (taskIDs, completedTaskIDs, taskTimes) |

## Existing Patterns
- **Follow-up (bestehend):** `FocusBlockActionService.followUpTask()` — markiert Original als erledigt, erstellt Kopie mit Metadaten. Wird waehrend aktivem Block per Button getriggert. **Aber:** hat kein `parentTaskID`, keine `progressNote`, keine Restdauer-Berechnung.
- **Sprint Review:** Wird angezeigt wenn Block `isPast` ist oder alle Tasks erledigt. Zeigt erledigte/unerledigte Tasks, erlaubt Status-Toggle. **Kein Abbrechen-Button vorhanden.**
- **Task-Completion:** `completeTask()` setzt `isCompleted=true`, `completedAt`, `assignedFocusBlockID=nil`, befreit Dependents, generiert naechste Recurring-Instance.

## Dependencies
- **Upstream:** `FocusBlock`, `LocalTask`, `EventKitRepository`, `PlanItem`
- **Downstream:** `FocusLiveView` (nutzt SprintReviewSheet + FocusBlockActionService)

## Key Observations
1. **Kein Abbrechen-Button:** Aktuell gibt es KEINE Moeglichkeit einen Focus Block vorzeitig abzubrechen. Sprint Review kommt nur wenn Block abgelaufen ist.
2. **Follow-up existiert schon:** `followUpTask()` ist eine gute Basis, aber die Spec will etwas Anderes — Abbruch (nicht Completion) mit Fortschritts-Notiz und Restdauer.
3. **Flache Kette:** Spec fordert `parentTaskID` verweist immer auf ORIGINAL-Task (nicht Eltern-Task), also keine verschachtelte Baumstruktur.
4. **Restdauer-Berechnung:** Original-Duration minus abgelaufene Zeit, Minimum 15 Min.

## Risks & Considerations
- **CloudKit-Migration:** Neue Properties auf `@Model` brauchen Default-Werte fuer CloudKit-Kompatibilitaet
- **Bestehender followUpTask():** Bleibt unangetastet — neue `abortWithFollowUp()` daneben
- **SprintReviewSheet Scope:** Bekommt `isAborted: Bool = false` Parameter — nicht-breaking, Default false

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/LocalTask.swift` | MODIFY | + `parentTaskID: String?`, + `progressNote: String?` |
| `Sources/Services/FocusBlockActionService.swift` | MODIFY | + `abortWithFollowUp()` Methode, + `.abortedWithFollowUp` case |
| `Sources/Views/SprintReviewSheet.swift` | MODIFY | + `isAborted` Param, + Freitext-TextField, + Follow-up-Button pro unerledigtem Task |
| `Sources/Views/FocusLiveView.swift` | MODIFY | + "Block abbrechen"-Button, + isAborted-Flag an SprintReviewSheet |

### Scope Assessment
- Files: 4 (Produktion) + Tests
- Estimated LoC: +138
- Risk Level: LOW (nur additive Aenderungen, CloudKit-kompatibel)

### Technical Approach
1. **LocalTask:** Zwei optionale Properties (`parentTaskID`, `progressNote`) — post-init gesetzt wie `blockerTaskID`
2. **FocusBlockActionService:** Neue `abortWithFollowUp(task:note:elapsedMinutes:modelContext:)` — markiert Original NICHT als completed, schreibt progressNote, berechnet Restdauer (Original - elapsed, min 15), erstellt Follow-up mit korrektem parentTaskID (immer Root = flache Kette)
3. **SprintReviewSheet:** `isAborted: Bool = false` Parameter. Bei `isAborted == true`: pro unerledigtem Task optionaler Freitext + "Follow-up erstellen"-Button inline
4. **FocusLiveView:** Diskreter "Abbrechen"-Button in progressHeader(), setzt showSprintReview + isAborted-Flag

### Restdauer-Berechnung
```
elapsedSeconds = block.taskTimes[task.id] ?? 0
elapsedMinutes = elapsedSeconds / 60
remaining = max(15, (original.estimatedDuration ?? 60) - elapsedMinutes)
```

### Flache Kette (parentTaskID)
Wenn `original.parentTaskID != nil` → neuer Task erbt `original.parentTaskID` (das echte Original).
Wenn `original.parentTaskID == nil` → neuer Task bekommt `original.id` als parentTaskID.

### Dependencies
- **Upstream:** FocusBlock, LocalTask, EventKitRepository, PlanItem
- **Downstream:** FocusLiveView (nutzt SprintReviewSheet + FocusBlockActionService)

### Open Questions
Keine — Spec ist klar, Ansatz steht.
