# Context: RW_3.2 — Focus Sprint ("Los"-Button)

## Request Summary
Direkter Start eines Focus Blocks aus Backlog/Next-Up heraus mit einem "Los"-Button. Ein Tap erstellt einen Focus Block (Start=jetzt, Dauer=estimatedDuration oder 60 Min Default), wechselt in FocusLiveView, aktiviert Live Activity + Dynamic Island.

## Abhaengigkeit: Story 3.1 (Calendar Task Drop)
**3.1 ist NICHT implementiert.** Die Spec sagt "Abhaengigkeiten: Story 3.1", aber der einzige tatsaechliche Beruehrungspunkt ist:
- Akzeptanzkriterium: "Wenn Task `scheduledDate` hat: wird beim Start geloescht"
- `scheduledDate` existiert noch nicht auf `LocalTask`

**Empfehlung:** 3.2 kann ohne 3.1 umgesetzt werden. Das Kriterium "scheduledDate loeschen" wird als TODO fuer spaeter markiert, da das Feld noch nicht existiert.

## Related Files

| Datei | Relevanz |
|-------|----------|
| `Sources/Views/BacklogRow.swift` | Braucht "Los"-Button |
| `Sources/Views/NextUpSection.swift` | Braucht "Los"-Button auf NextUpRow |
| `Sources/Services/FocusBlockActionService.swift` | Neue Methode `startImmediate(task:duration:)` |
| `Sources/Views/MainTabView.swift` | Auto-Switch zu Focus-Tab nach Sprint-Start |
| `Sources/Views/FocusLiveView.swift` | Zeigt aktiven Focus Block, startet Live Activity |
| `Sources/Services/EventKitRepository.swift` | `createFocusBlock(startDate:endDate:)` — existierender Code-Pfad |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | Protokoll fuer createFocusBlock/updateFocusBlock |
| `Sources/Models/FocusBlock.swift` | Struct-Model (EKEvent-backed), `isActive` computed property |
| `Sources/Models/LocalTask.swift` | `estimatedDuration: Int?`, `assignedFocusBlockID: String?` |
| `Sources/Services/LiveActivityManager.swift` | `startActivity(for:currentTask:knownTaskIDs:)` |
| `Sources/Views/BlockPlanningView.swift` | Referenz: existierender Block-Erstellungs-Flow (L556-582) |
| `FocusBloxMac/MacBacklogRow.swift` | "Los" im Context Menu |
| `FocusBloxMac/MacFocusView.swift` | macOS Pendant zu FocusLiveView |

## Existing Patterns

### Focus Block Erstellung (BlockPlanningView, L556-582)
1. `eventKitRepo.createFocusBlock(startDate:, endDate:)` → returns `eventID: String`
2. `eventKitRepo.updateFocusBlock(eventID:, taskIDs:, completedTaskIDs:, taskTimes:)` → assigns Tasks
3. Notifications schedulen (Start + End)
4. UI reload

### FocusBlockActionService Pattern
- Enum-Namespace mit statischen Methoden
- Nimmt `modelContext`, `eventKitRepo` als Parameter
- Arbeitet mit Task-IDs (String), nicht LocalTask-Objekten direkt

### Tab-Navigation
- `MainTabView` hat `@Binding var selectedTab: AppTab`
- Switch zu Focus: `selectedTab = .focus`
- FocusLiveView laedt Daten automatisch bei Appear

## Dependencies (Upstream)
- `EventKitRepositoryProtocol` — Block-Erstellung und -Update
- `LiveActivityManager` — Live Activity starten
- `FocusBlock` Model — Block-Struct
- `LocalTask` Model — Task mit `estimatedDuration`, `assignedFocusBlockID`

## Dependencies (Downstream)
- `FocusLiveView` — zeigt den erstellten Block automatisch an
- `SprintReviewSheet` — wird bei Abschluss getriggert (existiert bereits)
- Notifications — muessen bei Block-Start reconciled werden

## MorningCoachingSection
Die Spec referenziert `MorningCoachingSection.swift` — diese Datei existiert NICHT. Gehoert zu Story 2.1 (Day View), die noch nicht implementiert ist. Fuer 3.2 irrelevant.

## Risks & Considerations

1. **Kein zweiter paralleler Block:** Muss geprüft werden, ob bereits ein aktiver Block existiert → Warnung anzeigen
2. **DRY-Constraint:** `startImmediate` muss denselben Code-Pfad wie BlockPlanningView nutzen
3. **Tab-Switch-Timing:** Nach Block-Erstellung muss der Tab-Switch so erfolgen, dass FocusLiveView den neuen Block sicher laden kann
4. **Scoping:** MorningCoachingSection (Spec) existiert nicht — wird uebersprungen
5. **scheduledDate:** Feld existiert noch nicht (3.1 nicht implementiert) — Kriterium wird als TODO markiert
6. **macOS:** MacBacklogRow braucht "Los" im Context Menu, aber MacFocusView muss den Block ebenfalls laden koennen

---

## Analysis

### Type
Feature (neue Funktionalitaet)

### Affected Files (with changes)

| Datei | Change Type | Beschreibung |
|-------|-------------|--------------|
| `Sources/Services/FocusBlockActionService.swift` | MODIFY | `startImmediate(taskID:eventKitRepo:modelContext:durationMinutes:)` — erstellt Block, weist Task zu, prueft auf aktiven Block |
| `Sources/Views/BacklogRow.swift` | MODIFY | `onStartFocusSprint` Callback + "Los"-Button (folgt `onAddToNextUp`-Pattern) |
| `Sources/Views/BacklogView.swift` | MODIFY | Callback verdrahten, NotificationCenter posten, Conflict-Alert anzeigen |
| `Sources/Views/NextUpSection.swift` | MODIFY | "Los"-Button auf NextUpRow (gleicher Callback-Pattern) |
| `Sources/FocusBloxApp.swift` | MODIFY | `.onReceive` Observer fuer Tab-Switch zu `.focus` |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | "Los" im Context Menu |

### Scope Assessment
- **Files (Production):** 6
- **Files (Tests):** 2 (Unit + UI)
- **Estimated LoC:** +180–220 (Production), +100–150 (Tests)
- **Risk Level:** MEDIUM
- **Innerhalb ±250 LoC Limit:** Ja, wenn Inline-Duration-Picker ausgenommen wird

### Technical Approach

**1. Service-Methode (FocusBlockActionService)**
- Neue statische Methode `startImmediate()` im bestehenden Enum-Namespace
- Gleicher explicit-DI Pattern (Parameter, keine Environment-Injection)
- Nutzt existierenden `createFocusBlock()` + `updateFocusBlock()` Code-Pfad (DRY)
- Active-Block-Conflict-Check: `fetchFocusBlocks(for: Date())`, filter `isActive`, throw bei Konflikt

**2. Tab-Switch via NotificationCenter**
- BacklogView postet `Notification.Name.focusSprintStarted` nach erfolgreicher Block-Erstellung
- FocusBloxApp observiert via `.onReceive` und setzt `selectedTab = .focus`
- Kein Binding-Threading durch 4 View-Ebenen noetig
- Lose Kopplung — Views bleiben reine Presentation-Components

**3. "Los"-Button Pattern**
- Folgt exakt dem bestehenden Callback-Pattern (`onComplete`, `onAddToNextUp`, etc.)
- BacklogRow/NextUpRow: `var onStartFocusSprint: (() -> Void)?`
- MacBacklogRow: Context Menu Item

**4. Scoping-Entscheidung: Inline-Duration-Picker AUSGESCHLOSSEN**
- Spec sagt "Optional: Dauer vor Start anpassen"
- Wuerde LoC-Limit sprengen und UI-Komplexitaet deutlich erhoehen
- Empfehlung: Default-Dauer (estimatedDuration oder 60 Min), Picker als Follow-up

### Implementation Order (Risk-Minimizing)
1. Service: `startImmediate()` + Unit Tests (isoliert, kein UI)
2. TDD RED: UI Tests schreiben (Accessibility IDs die noch nicht existieren)
3. BacklogRow: Button + Callback
4. BacklogView: Wiring + Conflict-Alert + NotificationCenter
5. FocusBloxApp: Tab-Switch Observer
6. NextUpSection: Button auf NextUpRow
7. MacBacklogRow: Context Menu
8. TDD GREEN: Alle Tests ausfuehren

### Open Questions
- Keine — alle technischen Fragen sind geklaert
