# Adversary Dialog: Bug #221 — LiveUpdates werden nicht beendet

Geprueft: 2026-04-13
Adversary-Model: claude-sonnet-4-6
Workflow: bug-live-updates-not-stopped (Phase: TDD GREEN)

---

## Spec-Checkliste

Aus `docs/artifacts/bug-live-updates-not-stopped/analysis.md`:

| # | Spec-Punkt | Beweis-Typ | Beweis-Methode |
|---|-----------|------------|----------------|
| 1 | Orphan-Cleanup bei App-Start/View-Appear wenn kein aktiver Sprint laeuft | Business-Logik | Unit Test + Code-Analyse Call-Site |
| 2 | loadData() muss endActivity() + cleanupOrphans() aufrufen BEVOR showSprintReview gesetzt wird | Business-Logik | Code-Analyse Reihenfolge + Unit Test |
| 3 | cleanupOrphans() muss OHNE currentActivity funktionieren | Unit Test | test_cleanupOrphans_existsAndDoesNotCrash |
| 4 | Keine Regression in bestehenden Tests | Unit Test | Alle 7 LiveActivityManagerTests gruen |

---

### Runde 1: Code Review

### Kriterium 1: Orphan-Cleanup bei View-Appear

**Gepruefte Stelle:** `FocusLiveView.swift` Zeilen 177-183

```swift
.task {
    await loadData()
    // Bug #221: Clean up orphaned Live Activities after app restart
    if activeBlock == nil || activeBlock?.isPast == true {
        liveActivityManager.cleanupOrphans()
    }
}
```

- [x] Call-Site 1 vorhanden: `.task` Block ruft `cleanupOrphans()` nach `loadData()` auf
- [x] Bedingung korrekt: `activeBlock == nil || activeBlock?.isPast == true` — deckt App-Neustart-Szenario ab
- [x] `cleanupOrphans()` existiert in `LiveActivityManager.swift` (Zeile 102-113)
- [x] Die Methode iteriert ueber `Activity<FocusBlockActivityAttributes>.activities` direkt — unabhaengig von `currentActivity`

**Verdict fuer Kriterium 1:** x HAELT — Call-Site korrekt implementiert

### Kriterium 2: loadData() Reihenfolge (endActivity BEVOR showSprintReview)

**Gepruefte Stelle:** `FocusLiveView.swift` Zeilen 585-590

```swift
if activeBlock?.isPast == true && !reviewDismissed {
    // Bug #221: End Live Activity BEFORE showing Sprint Review
    liveActivityManager.endActivity()
    liveActivityManager.cleanupOrphans()
    liveActivityStarted = false
    showSprintReview = true  // LETZTER Schritt — korrekt
}
```

- [x] `endActivity()` wird BEVOR `showSprintReview = true` aufgerufen
- [x] `cleanupOrphans()` wird BEVOR `showSprintReview = true` aufgerufen
- [x] `liveActivityStarted = false` wird vor `showSprintReview = true` gesetzt

**Kritische Analyse der Reihenfolge:** Die Spec fordert endActivity() BEVOR showSprintReview. Die Implementierung haelt diese Reihenfolge ein.

**Aber:** `endActivity()` enthaelt einen Guard `guard let activity = currentActivity else { return }`. Nach App-Kill ist `currentActivity = nil`. Damit ist `endActivity()` hier wirkungslos. Die entscheidende Arbeit macht `cleanupOrphans()` — das direkt die System-Activities beendet, unabhaengig von `currentActivity`.

- [x] Fix loest den App-Kill-Pfad korrekt: `endActivity()` scheitert sicher, `cleanupOrphans()` greift durch

**Verdict fuer Kriterium 2:** x HAELT — Reihenfolge korrekt, Kombination aus endActivity+cleanupOrphans deckt beide Szenarien ab

### Kriterium 3: cleanupOrphans() ohne currentActivity

**Gepruefte Stelle:** `LiveActivityManager.swift` Zeilen 102-113

```swift
func cleanupOrphans() {
    let orphans = Activity<FocusBlockActivityAttributes>.activities
    guard !orphans.isEmpty else { return }
    for orphan in orphans {
        nonisolated(unsafe) let captured = orphan
        Task { @MainActor in
            await captured.end(nil, dismissalPolicy: .immediate)
        }
    }
}
```

- [x] Kein Zugriff auf `currentActivity` — arbeitet direkt mit `Activity.activities` (System-Level)
- [x] Guard nur auf leerem orphans-Array — korrekt
- [x] Unit Test `test_cleanupOrphans_existsAndDoesNotCrash` bestaetigt: 0.014s, PASSED

**Verdict fuer Kriterium 3:** x HAELT — Unit Test gruen, Code korrekt

### Kriterium 4: Keine Regression

**Ergebnis:** `LiveActivityManagerTests`: 7/7 PASSED (0 failures)

- [x] `testInitialStateHasNoActivity` — PASSED
- [x] `testIsSupportedReturnsBoolean` — PASSED
- [x] `testUpdateActivityWhenNoActivityDoesNotCrash` — PASSED
- [x] `testEndActivityWhenNoActivityDoesNotCrash` — PASSED
- [x] `testStartActivityHandlesUnsupportedDevice` — PASSED
- [x] `test_cleanupOrphans_existsAndDoesNotCrash` — PASSED (NEU)
- [x] `test_cleanupOrphans_worksIndependentlyOfEndActivity` — PASSED (NEU)

**Verdict fuer Kriterium 4:** x HAELT — keine Regression

---

### Runde 2: Edge Cases

### Edge Case 1: App-Kill → Neustart → Past Block (Haupt-Reproduktionsweg)

**Analyse des Datenflusses:**

1. App wird gekillt waehrend Sprint laeuft
2. Neuer `LiveActivityManager()` wird erstellt → `currentActivity = nil` (korrekt)
3. `.task { await loadData() }` laeuft
4. `loadData()` findet vergangenen Block → `activeBlock?.isPast == true`
5. Zweig: `endActivity()` → Guard returnt (currentActivity nil) → sicher
6. Zweig: `cleanupOrphans()` → iteriert `Activity.activities` direkt → beendet Orphan

**Ergebnis:** Hauptpfad korrekt abgedeckt.

- [x] App-Kill-Szenario: HAELT

### Edge Case 2: checkBlockEnd() nach loadData() (Race Condition)

**Analyse:** `loadData()` setzt `showSprintReview = true`. Danach prueft `checkBlockEnd()` (Zeile 720): `if block.isPast && !showSprintReview && !reviewDismissed`. Nach `loadData()` ist `showSprintReview = true` → Guard blockiert → `endActivity()` in `checkBlockEnd()` wird nicht mehr aufgerufen.

Das ist in Ordnung, weil `loadData()` bereits `endActivity()` + `cleanupOrphans()` aufgerufen hat.

- [x] Race Condition korrekt aufgeloest: HAELT

### Edge Case 3: Mehrfacher View-Appear (onAppear vs .task)

**Analyse:** `.task` wird bei jedem View-Appear neu ausgefuehrt. Wenn `activeBlock == nil` (normal nach Sprint-Ende), wird `cleanupOrphans()` bei jedem Appear aufgerufen. Das ist harmlos — `guard !orphans.isEmpty else { return }` macht es idempotent.

- [x] Mehrfacher Aufruf sicher: HAELT

### Edge Case 4: Testabdeckung der UI-Tests (KRITISCHER FUND)

**LiveActivityUITests:** 4/4 FAILED

**Fehlerursache:** Tests suchen nach `app.navigationBars["Fokus"]` (deutsch), aber `FocusLiveView` hat `navigationTitle("Focus")` (englisch). Der Mismatch existiert seit Commit `ca57637` (Korrekte Umlaute) — lange vor Bug #221.

**Beweis pre-existing:** Commit `8469c1a` (Live Activity Feature): `navigationTitle("Fokus")`. Alle aktuelleren Commits: `navigationTitle("Focus")`. Die Tests wurden nicht angepasst.

**Relevanz fuer Bug #221:** Die UI-Tests testen NICHT den Orphan-Cleanup — sie testen nur ob die Fokus-View navigiert werden kann. Fuer die eigentliche Bug-Fix-Validierung sind sie irrelevant.

**ABER:** Als Adversary muss ich darauf hinweisen: Der Developer hat behauptet "ui_test_green_done: true" im Workflow. Das ist falsch — die UI-Tests waren nie gruen (pre-existing failure auf anderem Problem).

- [✗] UI-Test Gruen-Status: FALSCH BEHAUPTET (aber pre-existing, nicht durch Fix verursacht)

### Edge Case 5: Kein Test fuer den kritischen App-Kill-Pfad

**Analyse:** Die neuen Unit-Tests (`test_cleanupOrphans_existsAndDoesNotCrash`, `test_cleanupOrphans_worksIndependentlyOfEndActivity`) pruefen nur ob die Methode existiert und nicht crasht — auf dem Simulator wo es keine echten Live Activities gibt.

Sie pruefen NICHT:
- Ob bei `Activity.activities.count > 0` wirklich alle beendet werden
- Ob der `.task`-Aufruf von `cleanupOrphans()` wirklich feuert wenn `activeBlock?.isPast == true`
- Den vollstaendigen App-Kill-Neustart-Pfad End-to-End

**Bewertung:** Die Tests sind strukturell korrekt fuer was auf dem Simulator testbar ist (ActivityKit liefert keine echten Activities im Simulator). Das ist eine fundamentale Limitation, nicht ein Fehler des Fixes.

- [~] Test-Tiefe: Bedingt — auf Simulator nicht tiefer testbar (ActivityKit-Einschraenkung)

---

## Spec-Check Tabelle

| # | Spec-Punkt | Beweis | Verdict |
|---|-----------|--------|---------|
| 1 | Orphan-Cleanup bei App-Start/View-Appear wenn kein aktiver Sprint | Call-Site FocusLiveView:181 verifiziert, Bedingung korrekt | x HAELT |
| 2 | loadData() ruft endActivity() + cleanupOrphans() BEVOR showSprintReview | Code FocusLiveView:587-590: Reihenfolge exakt wie spezifiziert | x HAELT |
| 3 | cleanupOrphans() ohne currentActivity | Unit Test 0.014s PASSED, Code iteriert Activity.activities direkt | x HAELT |
| 4 | Keine Regression in bestehenden Tests | 7/7 Unit Tests PASSED | x HAELT |

### Edge Cases

| Edge Case | Beweis | Verdict |
|-----------|--------|---------|
| App-Kill Hauptpfad | Code-Analyse: endActivity sicher, cleanupOrphans greift durch | x HAELT |
| Race Condition loadData/checkBlockEnd | showSprintReview gesetzt nach Cleanup — Guard in checkBlockEnd greift | x HAELT |
| Mehrfacher View-Appear | cleanupOrphans() idempotent durch Guard | x HAELT |
| UI-Tests Gruen | 4/4 FAILED — aber pre-existing (navigationTitle-Mismatch seit ca57637) | ✗ BROKEN (pre-existing) |
| Test-Tiefe fuer App-Kill-Pfad | ActivityKit nicht testbar im Simulator — fundamentale Limitation | ~ EINGESCHRAENKT |

---

## Verdict
**VERIFIED — Alle 4 Acceptance Criteria erfuellt. Fix ist strukturell korrekt, defensiv und idempotent. Pre-existing UI-Test-Failures (NavigationTitle-Mismatch) sind nicht durch den Fix verursacht. Test-Tiefe auf Simulator limitiert (ActivityKit-Einschraenkung).**

