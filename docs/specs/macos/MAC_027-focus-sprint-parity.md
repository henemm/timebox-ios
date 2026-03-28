---
entity_id: mac_027_focus_sprint_parity
type: feature
created: 2026-03-28
updated: 2026-03-28
status: draft
version: "1.0"
tags: [macos, focus-sprint, parity, emotional-nudge, follow-up]
---

# MAC-027: Focus Sprint Workflow Paritat (macOS)

## Approval

- [ ] Approved

## Purpose

macOS erhaelt Feature-Paritat mit iOS fuer den vollstaendigen Focus Sprint Workflow. Aktuell fehlen auf macOS drei zentrale Verhaltensweisen: automatischer Sidebar-Wechsel bei Sprint-Start, der Emotional Nudge Dialog bei sehr kurzen Blocks, und die Follow-up-Erstellung im Sprint Review Sheet.

## Ist-Zustand

### Feature-Gap: macOS vs iOS Focus Sprint

| Verhalten | iOS | macOS |
|-----------|-----|-------|
| Sidebar/Tab wechselt bei Sprint-Start zu Focus | Ja (MainTabView) | Nein |
| Emotional Nudge Dialog bei Block ≤2min | Ja (SprintReviewSheet) | Nein |
| Follow-up erstellen fuer incomplete Tasks im Review | Ja (SprintReviewSheet) | Nein |

## Scope: Was diese Spec abdeckt

### Sub-Feature 1: Sidebar-Switch bei Sprint-Start (~18 LoC)

**Problem:** Beim Start eines Focus Sprints auf macOS bleibt die Sidebar auf der aktuellen Section stehen. iOS wechselt automatisch zur Focus-Ansicht.

**Loesung:**
- In `ContentView.startFocusSprint()` und `startNudgeSprint()`: nach `.started` Case → `selectedSection = .focus` setzen
- `MacPlanningView.startFocusSprintOnMac()`: das `selectedSection` Binding durchreichen, sodass der Aufruf aus der Planning View heraus ebenfalls die Sidebar schaltet
- `selectedSection` ist `@Binding var` in ContentView, der `@State` liegt in `FocusBloxMacApp`

**Betroffene Dateien:**

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/ContentView.swift` | `selectedSection = .focus` nach Sprint-Start (~8 LoC) |
| `FocusBloxMac/MacPlanningView.swift` | `selectedSection` Binding durchreichen (~10 LoC) |

### Sub-Feature 2: Emotional Nudge Dialog (~35 LoC)

**Problem:** Wenn ein Focus Block sehr kurz endet (≤2 Minuten), soll auf macOS — genau wie auf iOS — ein Dialog erscheinen, der fragt ob der Block verlaengert werden soll, bevor das Review Sheet gezeigt wird.

**Loesung:**
- In `MacFocusView.checkBlockEnd()`: Block-Dauer pruefen
  - Wenn Dauer ≤2min → `showNudgeContinueDialog = true` (statt direkt `showSprintReview`)
  - Wenn Dauer >2min → wie bisher `showSprintReview = true`
- `.confirmationDialog("Weitermachen?")` mit zwei Aktionen:
  - "Ja, weitermachen" → `extendNudgeBlock()` aufrufen
  - "Nein, beenden" → `showSprintReview = true`
- `extendNudgeBlock()`: Block-Endzeit um naechste Task-Duration verlaengern via `eventKitRepo.updateFocusBlockTime()`

**Betroffene Dateien:**

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/MacFocusView.swift` | `checkBlockEnd()` anpassen, Dialog + `extendNudgeBlock()` hinzufuegen (~35 LoC) |

### Sub-Feature 3: Follow-up im MacSprintReviewSheet (~55 LoC)

**Problem:** Das macOS Sprint Review Sheet zeigt incomplete Tasks, bietet aber keine Moeglichkeit, daraus Follow-up Tasks zu erstellen. Auf iOS ist das bereits moeglich.

**Loesung:**
- `MacSprintReviewSheet` bekommt `@Environment(\.modelContext)`
- Neuer State: `progressNotes: [String: String]` (TaskID → Notiz-Text), `followUpCreated: Set<String>` (TaskIDs wo Follow-up bereits erstellt wurde)
- UI pro incomplete Task:
  - `TextField` fuer Progress-Notiz
  - "Follow-up erstellen" Button
  - Bestaetigung "Follow-up erstellt" nach Erfolg (Button disabled, Haekchen-Icon)
- `createFollowUp(task:)` ruft `FocusBlockActionService.abortWithFollowUp(taskID:, block:, progressNote:, modelContext:)` auf
- **Kein `isAborted`-Gate:** Follow-up wird bei ALLEN incomplete Tasks angeboten (abweichend von iOS-Implementierung)

**Betroffene Dateien:**

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/MacFocusView.swift` | `MacSprintReviewSheet` erweitern: `modelContext`, States, Follow-up UI + Action (~55 LoC) |

## Gesamt-Scope

**3 Dateien, ~110 LoC Production — innerhalb Scoping-Limits.**

| Datei | Change Type | Geschaetzte LoC |
|-------|-------------|-----------------|
| `FocusBloxMac/ContentView.swift` | MODIFY | ~8 |
| `FocusBloxMac/MacPlanningView.swift` | MODIFY | ~10 |
| `FocusBloxMac/MacFocusView.swift` | MODIFY | ~90 |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Sources/Services/FocusBlockActionService.swift` | Service | `startImmediate()`, `abortWithFollowUp()` — werden aufgerufen, nicht geaendert |
| `Sources/Services/EmotionalNudgeService.swift` | Service | `canShowNudge()`, `nudgeText()`, `recordNudge()` — Referenz-Logik fuer Dialog-Trigger |
| `Sources/Repositories/EventKitRepository.swift` | Repository | `updateFocusBlockTime()` fuer Block-Verlaengerung in `extendNudgeBlock()` |
| `FocusBloxMac/ContentView.swift` | Target | Sidebar-Switch-Logik |
| `FocusBloxMac/MacPlanningView.swift` | Target | Binding-Durchreichung |
| `FocusBloxMac/MacFocusView.swift` | Target | Nudge-Dialog + Follow-up Sheet |
| `docs/specs/rework/3.2-focus-sprint.md` | Reference | Urspruengliche Feature-Spec des Focus Sprint |
| `docs/specs/rework/3.2-focus-sprint-impl.md` | Reference | iOS-Implementierungsdetails |
| `docs/specs/rework/3.3-follow-up-logic-impl.md` | Reference | Follow-up Logik auf iOS |
| `docs/specs/rework/3.4-emotional-nudge-impl.md` | Reference | Emotional Nudge auf iOS |

## Expected Behavior

### Sub-Feature 1: Sidebar-Switch

- **Trigger:** User startet Focus Sprint (aus Planning View oder direkt)
- **Output:** Sidebar wechselt unmittelbar nach `.started` zu `.focus` Section
- **Side effects:** Keine weiteren UI-Aenderungen

### Sub-Feature 2: Emotional Nudge Dialog

- **Trigger:** `checkBlockEnd()` wird aufgerufen, Block-Dauer ist ≤2 Minuten
- **Output:** `.confirmationDialog` erscheint BEVOR `showSprintReview`
- "Ja, weitermachen": Block-Endzeit wird verlaengert, kein Review Sheet
- "Nein, beenden": Review Sheet wird geoeffnet
- **Trigger (normal, >2min):** Review Sheet wird direkt geoeffnet (kein Dialog)

### Sub-Feature 3: Follow-up im Review Sheet

- **Input:** Sprint Review Sheet mit mindestens einer incomplete Task
- **Output:** Jede incomplete Task zeigt `TextField` + "Follow-up erstellen" Button
- Nach Tap: `abortWithFollowUp()` wird aufgerufen, Button wird deaktiviert, Bestaetigung erscheint
- **Unterschied zu iOS:** Kein `isAborted`-Gate — alle incomplete Tasks erhalten das Follow-up Angebot

## Akzeptanzkriterien

1. Sprint-Start (aus Planning View und aus ContentView) schaltet Sidebar zu `.focus`
2. Bei Block-Dauer ≤2min erscheint Confirmation Dialog vor dem Review Sheet
3. "Ja, weitermachen" verlaengert den Block korrekt via `updateFocusBlockTime()`
4. "Nein, beenden" oeffnet Review Sheet normal
5. Review Sheet zeigt TextField + Follow-up Button fuer jede incomplete Task
6. `abortWithFollowUp()` wird mit korrekter `progressNote` aufgerufen
7. Nach erfolgter Follow-up-Erstellung: Button disabled, Bestaetigung sichtbar
8. Build compiliert fehlerfrei (iOS + macOS)

## Ausdruecklich NICHT im Scope

| Feature | Warum nicht |
|---------|-------------|
| Live Activity auf macOS | Separates Feature |
| Emotional Nudge in iOS anpassen | iOS ist bereits fertig, kein Scope |
| Follow-up `isAborted`-Gate auf macOS nachruesten | Bewusste UX-Abweichung, kein Fehler |
| Neue Services oder Modelle | Nur bestehende shared Services werden genutzt |

## Risiken

| Risiko | Mitigation |
|--------|-----------|
| `selectedSection` Binding nicht korrekt durch alle Views durchgereicht | Vor Sub-Feature 1 Binding-Kette in ContentView vollstaendig tracen |
| `checkBlockEnd()` wird an mehreren Stellen aufgerufen | Alle Call-Sites in MacFocusView vor Aenderung identifizieren |
| `MacSprintReviewSheet` hat moeglicherweise kein `modelContext` Environment | `@Environment(\.modelContext)` explizit pruefen, ob Sheet im richtigen View-Tree haengt |

## Changelog

- 2026-03-28: Initial spec created
