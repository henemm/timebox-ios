# Tests: Monster Coach Phase 3c — Abend-Spiegel

> Bezug: `openspec/changes/monster-coach-phase3c/proposal.md`

---

## Unit Tests: IntentionEvaluationService (evaluateFulfillment)

Erweiterung von `FocusBloxTests/IntentionEvaluationServiceTests.swift`.

### Survival-Tests

| Test | Input | Expected |
|------|-------|----------|
| `test_evaluateFulfillment_survival_fulfilled` | 1+ Tasks completed today | `.fulfilled` |
| `test_evaluateFulfillment_survival_notFulfilled` | 0 Tasks completed today | `.notFulfilled` |

### Fokus-Tests

| Test | Input | Expected |
|------|-------|----------|
| `test_evaluateFulfillment_fokus_fulfilled` | Blocks mit ≥70% completion | `.fulfilled` |
| `test_evaluateFulfillment_fokus_partial` | Blocks mit 50% completion (40-69%) | `.partial` |
| `test_evaluateFulfillment_fokus_notFulfilled_lowCompletion` | Blocks mit <40% completion | `.notFulfilled` |
| `test_evaluateFulfillment_fokus_notFulfilled_noBlocks` | 0 Blocks today | `.notFulfilled` |

### BHAG-Tests

| Test | Input | Expected |
|------|-------|----------|
| `test_evaluateFulfillment_bhag_fulfilled` | Task mit importance=3 completed | `.fulfilled` |
| `test_evaluateFulfillment_bhag_partial` | Tasks completed, none importance=3 | `.partial` |
| `test_evaluateFulfillment_bhag_notFulfilled` | 0 Tasks completed | `.notFulfilled` |

### Balance-Tests

| Test | Input | Expected |
|------|-------|----------|
| `test_evaluateFulfillment_balance_fulfilled` | Tasks in 3+ Kategorien | `.fulfilled` |
| `test_evaluateFulfillment_balance_partial` | Tasks in genau 2 Kategorien | `.partial` |
| `test_evaluateFulfillment_balance_notFulfilled` | Tasks in ≤1 Kategorie | `.notFulfilled` |

### Growth-Tests

| Test | Input | Expected |
|------|-------|----------|
| `test_evaluateFulfillment_growth_fulfilled` | "learning" Task completed | `.fulfilled` |
| `test_evaluateFulfillment_growth_notFulfilled` | Kein "learning" Task completed | `.notFulfilled` |

### Connection-Tests

| Test | Input | Expected |
|------|-------|----------|
| `test_evaluateFulfillment_connection_fulfilled` | "giving_back" Task completed | `.fulfilled` |
| `test_evaluateFulfillment_connection_notFulfilled` | Kein "giving_back" Task completed | `.notFulfilled` |

### Block-Completion-Tests

| Test | Input | Expected |
|------|-------|----------|
| `test_blockCompletionPercentage_allCompleted` | 3/3 Tasks completed in blocks | 1.0 (100%) |
| `test_blockCompletionPercentage_partial` | 2/4 Tasks completed | 0.5 (50%) |
| `test_blockCompletionPercentage_noBlocks` | 0 Blocks | 0.0 |
| `test_blockCompletionPercentage_emptyBlocks` | Blocks mit 0 Tasks | 0.0 |

**Gesamt: 20 Unit Tests**

---

## Unit Tests: Fallback-Templates

| Test | Input | Expected |
|------|-------|----------|
| `test_fallbackTemplate_allIntentions_fulfilled` | Jede Intention + .fulfilled | Non-empty String, kein Placeholder |
| `test_fallbackTemplate_allIntentions_notFulfilled` | Jede Intention + .notFulfilled | Non-empty String, kein Placeholder |
| `test_fallbackTemplate_partialIntentions` | Fokus/BHAG/Balance + .partial | Non-empty String |

**Gesamt: 3 Unit Tests**

---

## UI Tests: EveningReflectionCard

Neue Datei: `FocusBloxUITests/EveningReflectionCardUITests.swift`

### Sichtbarkeits-Tests

| Test | Setup | Expected |
|------|-------|----------|
| `test_eveningReflectionCard_visibleWhenCoachEnabled` | Coach ON + Intention gesetzt + nach 18 Uhr (oder Debug-Flag) | Card sichtbar mit ID `eveningReflectionCard` |
| `test_eveningReflectionCard_hiddenWhenCoachDisabled` | Coach OFF | Card nicht sichtbar |
| `test_eveningReflectionCard_hiddenWhenNoIntention` | Coach ON + keine Intention gesetzt | Card nicht sichtbar |

### Inhalts-Tests

| Test | Setup | Expected |
|------|-------|----------|
| `test_eveningReflectionCard_showsFulfillmentBadge` | Coach ON + Intention + Tasks | Badge `fulfillmentBadge_*` existiert |
| `test_eveningReflectionCard_showsReflectionText` | Coach ON + Intention + Tasks | Text `reflectionText_*` existiert und non-empty |

**Gesamt: 5 UI Tests**

---

## Test-Zusammenfassung

| Kategorie | Anzahl | Datei |
|-----------|--------|-------|
| evaluateFulfillment Unit Tests | 16 | IntentionEvaluationServiceTests.swift |
| blockCompletionPercentage Unit Tests | 4 | IntentionEvaluationServiceTests.swift |
| Fallback Template Tests | 3 | IntentionEvaluationServiceTests.swift |
| UI Tests | 5 | EveningReflectionCardUITests.swift |
| **Gesamt** | **28** | |

---

## Test-Hilfsfunktionen (bestehend, wiederverwendbar)

Aus den bestehenden IntentionEvaluationServiceTests:

```swift
// Bereits vorhanden (Phase 3b)
func makeTask(isCompleted: Bool, completedAt: Date?, taskType: String, importance: Int?, assignedFocusBlockID: String?) -> LocalTask
func makeBlock(startDate: Date, taskIDs: [String], completedTaskIDs: [String]) -> FocusBlock
```

Diese Helpers werden fuer die neuen Tests wiederverwendet.
