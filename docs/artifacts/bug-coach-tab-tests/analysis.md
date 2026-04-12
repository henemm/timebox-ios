# Analyse: Bug #212 — CoachTabLayoutUITests veraltet

## Agenten-Ergebnisse Zusammenfassung

### Test-Ergebnis (tatsächlich ausgeführt)
- **5 Failures** (nicht 4 wie im Issue angegeben), 3 Passes
- Passed: `testCoachLayoutShowsFourTabs`, `testCoachTabShowsMorningDrawer`, `testCoachLayoutNavigationWorks`
- Failed: `testDefaultLayoutShowsFiveTabs`, `testCoachTabShowsAllThreeSections`, `testDaytimeShowsCompactCount`, `testEveningShowsReflection`, `testCoachRefreshesAfterBacklogCompletion`

### Wiederholungs-Check
- Tests wurden 2026-04-02 erstellt, 3x repariert (Commits 352f851, bf56664, 5fb477b)
- Letzte Reparatur: 2026-04-04 (Accordion-Redesign)
- Seitdem keine Anpassungen mehr — Tests sind seit 8 Tagen veraltet

### Feature-Flag Status
- `useCoachTabLayoutSetting` Default = `false` (5-Tab ist NOCH Default)
- `--coach-tab-layout` Launch-Argument existiert und funktioniert
- Coach-Tests nutzen korrekt `--coach-tab-layout`

---

## Hypothesen (Root Causes)

### Hypothese 1: AppStorage-Pollution bei Test 1 (HOCH)
**testDefaultLayoutShowsFiveTabs** — sucht "Blox"-Tab, findet ihn nicht.

- Der Test startet OHNE `--coach-tab-layout`
- ABER: AppStorage `useCoachTabLayout` könnte von vorherigen Test-Runs persistent sein
- Wenn ein früherer Test den Settings-Toggle aktiviert hat, zeigt die App 4 Tabs statt 5
- **Beweis dafür:** Tab "Backlog" existiert (Zeile 30 passed), aber "Blox" nicht (Zeile 31 failed) → App zeigt Coach-Layout
- **Beweis dagegen:** Keiner der Tests setzt den AppStorage-Wert explizit
- **Wahrscheinlichkeit: HOCH**

### Hypothese 2: Accordion-Timing bei Test 2 (HOCH)
**testCoachTabShowsAllThreeSections** — erwartet alle 3 Sections gleichzeitig sichtbar.

- Die Drawer-Sections (`coachMorningSection` etc.) existieren als VStack-Identifier (Zeile 206-207 CoachView.swift) — sie sind IMMER im View-Tree, auch wenn geschlossen
- Der Test sucht `app.otherElements["coachMorningSection"]` mit 5s Timeout
- **Tatsächlicher Fehler:** "Morning section should exist" (Zeile 74)
- **Mögliche Ursache:** Die Section-Identifier sind auf der äußeren VStack, sollten also immer da sein — ABER die App könnte noch laden (`isLoading` State, `loadAllData()` async)
- **Beweis dafür:** Coach-View braucht async Data-Loading bevor Drawers gerendert werden
- **Wahrscheinlichkeit: HOCH** — Timing zwischen Tab-Wechsel und View-Rendering

### Hypothese 3: Veraltete Text-Patterns bei Test 4+5 (SICHER)
**testDaytimeShowsCompactCount** und **testCoachRefreshesAfterBacklogCompletion** — suchen "Dinge geschafft".

- String "Dinge geschafft" kommt **NIRGENDS** im `SuccessStoryService` vor
- Aktuelle Texte: "Tasks erledigt", "Tasks für heute geplant", "Der Anfang ist gemacht" etc.
- Tests erwarten ein altes Text-Pattern das nicht mehr existiert
- **Beweis:** `grep "Dinge geschafft" Sources/` → 0 Treffer
- **Wahrscheinlichkeit: SICHER (100%)**

### Hypothese 4: Scroll/Drawer-Problem bei Test 3 (HOCH)
**testEveningShowsReflection** — Evening-Section nach Scroll nicht gefunden.

- Test scrollt 2x nach oben und sucht `coachEveningSection`
- Aber: In Accordion-Layout hat Scrollen keinen Effekt auf Drawer-Sichtbarkeit
- Der Evening-Drawer-Header ist sichtbar, aber sein `coachEveningSection` VStack-Identifier existiert → SOLLTE findbar sein
- **Tatsächlicher Fehler:** "Evening section should be visible after scrolling" (Zeile 129)
- **Mögliche Ursache:** Evening-Drawer ist geschlossen, die VStack hat `frame(maxHeight: nil)` wenn nicht offen → möglicherweise zu klein für XCTest
- **Wahrscheinlichkeit: HOCH**

---

## Wahrscheinlichste Ursachen (gewählt)

| Test | Root Cause | Sicherheit |
|------|-----------|------------|
| Test 1 (`testDefaultLayoutShowsFiveTabs`) | AppStorage-Pollution ODER Test ist konzeptionell veraltet — 5-Tab-Layout wird perspektivisch entfernt | Hoch |
| Test 2 (`testCoachTabShowsAllThreeSections`) | Async Loading + Drawer-Rendering Timing | Hoch |
| Test 3 (`testEveningShowsReflection`) | Scroll-Logik passt nicht zu Accordion + Drawer muss geöffnet werden | Hoch |
| Test 4 (`testDaytimeShowsCompactCount`) | "Dinge geschafft" existiert nicht mehr | Sicher |
| Test 5 (`testCoachRefreshesAfterBacklogCompletion`) | "Dinge geschafft" existiert nicht mehr + Drawer-Navigation | Sicher |

---

## Blast Radius

### Direkt betroffen
- `FocusBloxUITests/CoachTabLayoutUITests.swift` — 5 von 8 Tests

### Potenziell betroffen (gleiche Patterns)
- `FocusBloxMacUITests/MacCoachTabLayoutUITests.swift` — macOS-Pendant, ähnliche Probleme wahrscheinlich
- `FocusBloxUITests/CoachIntentionUITests.swift` — nutzt auch "Dinge geschafft" Pattern (Zeile 195), aber mit OR-Bedingung ("Dinge geschafft OR schon erledigt")
- `FocusBloxUITests/CoachPeekUITests.swift` — nutzt gleiche Section-Identifier

### Nicht betroffen
- Tests die `--coach-tab-layout` nicht nutzen
- macOS ContentView-Tests (anderes Navigationspattern)

---

## Fix-Vorschlag Richtung

1. **Test 1 entfernen** — 5-Tab-Layout Test ist obsolet wenn Coach-Layout der Zielzustand ist
2. **Test 2-4 an Accordion anpassen** — Drawer öffnen bevor Content geprüft wird
3. **Test 4+5 Text-Patterns aktualisieren** — "Dinge geschafft" → tatsächliche SuccessStoryService-Texte
