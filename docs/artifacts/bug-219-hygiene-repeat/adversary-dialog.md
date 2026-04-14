# Adversary Dialog: Bug #219 — Hygiene Repeat

### Runde 1: Fix-Korrektheit

**Adversary:** Beweist keepTask() tatsächlich, dass hygieneReviewedAt persistiert wird? Vielleicht wird modelContext.save() nicht ausgeführt.

**Implementer:**
- [x] `keepTask()` ruft `findLocalTask(id:)` auf (Z.218) — Funktion existiert und ist identisch mit parkTask/deleteTask
- [x] `localTask.hygieneReviewedAt = Date()` wird gesetzt (Z.219)
- [x] `modelContext.save()` wird aufgerufen (Z.221)
- [x] **Unit Test Beweis:** `test_gracePeriodMatchesStaleAgeDays` war RED (0 statt 1), jetzt GREEN — Grace Period nutzt staleAgeDays statt hardcoded 30
- [x] **UI Test Beweis:** `test_hygieneView_keepAction_taskNotSuggested_afterReview` war RED (Banner kam zurück), jetzt GREEN — Banner verschwindet nach Behalten

**Verdict Runde 1:** Bestanden

### Runde 2: Edge Cases und Blast Radius

**Adversary:** Was passiert bei splitCompleted()? Und auf macOS? Und sind bestehende Tests gebrochen?

**Implementer:**
- [x] `splitCompleted()` bewusst NICHT geändert: Product-Entscheidung (Henning) — Abbruch = nicht reviewed, erfolgreicher Split = isCompleted=true → bereits rausgefiltert
- [x] `parkTask()` braucht kein hygieneReviewedAt: isParked=true → Guard `!task.isParked` in findStaleTasks() filtert bereits
- [x] `deleteTask()` braucht kein hygieneReviewedAt: Task wird gelöscht
- [x] UI-Hint zeigt `backlogStaleAgeDays` (14) — jetzt identisch mit Grace Period, kein Mismatch mehr
- [x] macOS Build erfolgreich — shared Code in Sources/, korrekt falls macOS Hygiene-Dialog später bekommt
- [x] Alle 11 bestehenden Unit Tests GRÜN, keine Regressionen
- [x] Scope: 2 Source-Dateien, ~10 LoC — innerhalb Limits

**Verdict Runde 2:** Bestanden

## Verdict
**VERIFIED — Fix ist korrekt, minimal, und durch Tests belegt.**
