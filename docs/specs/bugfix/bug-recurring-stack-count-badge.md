# Spec: Gestackte wiederkehrende Tasks — Counter-Bar Visualisierung

**Bug:** bug-recurring-stack-count-badge
**Re-open of:** Issue #279, fünf vorangegangene Anläufe (`2767a92`, `d17c4bf`, `62e4dd0`, `5604f09`, `56dc58c`)
**Datum:** 2026-05-01

## User Story

> **Als** User mit wiederkehrenden Aufgaben (Wochenreview, Sport, Lesen, …)
> **moechte ich** sofort und prominent erkennen, wenn ich eine Aufgabe mehrfach verpasst habe — als EINEN Eintrag mit auffaelliger Counter-Bar oben,
> **damit** meine Liste nicht aufgeblaeht aussieht und ich auf den ersten Blick weiss "da ist Rueckstand aufgelaufen".

## Live-Befund (vor Fix)

`./scripts/sim.sh test BacklogStackingUITests` → 7 von 7 rot.
Mit frischer DB sind die Stapel-Eintraege technisch da (siehe `bug279.log`: Wochenreview count=3, Taeglich lesen count=2), aber:
- in der "Ueberfaellig"-Sektion versteckt
- mit zu dezentem `x3`-Mini-Badge in der Badge-Reihe
- Mock-Seed-Guard blockiert Re-Seeding bei alter DB → User sieht gar nichts

## Akzeptanzkriterien

### AK-1: Counter-Bar prominent (statt Mini-Badge)
Wenn 2+ offene Children der gleichen Serie existieren, zeigt die Card oben eine **Counter-Bar** mit:
- Roter/oranger Hintergrund
- Text-Format: `"⚠ N× AUFGELAUFEN — seit [Datum des aeltesten Childs]"`
- Identifier: `stackingCounterBar_<taskID>`
- Datum-Format: kurzer Wochentag + Tag.Monat (z.B. "Fri 17. Apr")

Beispiel:
```
┌────────────────────────────────────────┐
│ ⚠ 3× AUFGELAUFEN — seit Fri 17. Apr   │  ← Counter-Bar
├────────────────────────────────────────┤
│ Wochenreview                           │
│ [Wöchentlich] [planning] [30m] [62]    │
└────────────────────────────────────────┘
```

Der bisherige `StackingBadge`-Mini-Badge in der Badge-Reihe **entfaellt** zugunsten der prominenten Bar.

### AK-2: Sektion = juengstes Child bestimmt

Repraesentant fuer Sektions-Zuordnung = Child mit **juengstem** dueDate.

| Children-dueDates | Sektion |
|-------------------|---------|
| heute + gestern | Heute / Dringend (juengstes = heute) |
| heute + −7T + −14T | Heute / Dringend (juengstes = heute) |
| −1T + −7T + −14T | Dringend / Bald (juengstes = −1T → effektiver Tier nach Score) |

Aenderung: bisher war Repraesentant das **aelteste** Child (versteckt in "Ueberfaellig"). Neu: **juengstes** Child wird sichtbar in der Tier-Sektion, Counter-Bar zeigt den Rueckstand.

### AK-3: Untertitel "X Instanzen seit ..." entfaellt

Die Counter-Bar transportiert die gleiche Info kompakter. Untertitel-Text wird entfernt.

### AK-4: Negativfall
Bei nur 1 offenem Child der Serie → KEINE Counter-Bar.

### AK-5: Plattform-Paritaet
Identisches Verhalten auf iOS und macOS (`MacBacklogRow.swift`).

### AK-6: Mock-Daten-Sentinel haerten

Der Mock-Seed-Guard (`Sources/FocusBloxApp.swift:760-767`) prueft aktuell nur einen einzigen Sentinel-Task. Wenn eine alte DB den Sentinel hat aber die Recurring-Mocks fehlen, werden sie nie nachgeseedet.

**Fix:** Zusaetzlich pruefen, ob mindestens ein Recurring-Mock (`recurrenceGroupID == "uitest-recurring-group-2"`) existiert. Falls nicht → Recurring-Mocks nachseeden.

### AK-7: Visueller Beweis (PFLICHT)
Nach Implementierung: Screenshot der App zeigt Counter-Bar mit "3× AUFGELAUFEN" deutlich sichtbar — auf iOS UND macOS.

### Out-of-Scope (Folge-Issue)
Hennings UX-Idee: Beim Abhaken einer gestapelten Aufgabe Rueckfrage "nur oberster Task / alle faelligen / Abbrechen". → Eigenes Issue.

## Affected Files (max 5 Code-Files)

1. `Sources/Views/BacklogView.swift` — `applyRecurringStacking()` Repraesentant-Wahl (juengstes statt aeltestes Child)
2. `Sources/Views/Components/TaskBadges.swift` — neue `StackingCounterBar`-Komponente, alte `StackingBadge` entfernen
3. `Sources/Views/BacklogRow.swift` — Counter-Bar oben einbauen, alten Badge entfernen
4. `Sources/FocusBloxApp.swift` — Mock-Seed-Sentinel um Recurring-Mock-Check erweitern
5. `FocusBloxMac/MacBacklogHelpers.swift` + `FocusBloxMac/MacBacklogRow.swift` — Plattform-Paritaet (zaehlt als 1 File-Group, da macOS-Anteil)

## Tests (Phase 4)

### UI-Tests (Anti-Silent-Pass)

**iOS** (`FocusBloxUITests/BacklogStackingUITests.swift` — 7 bestehende Tests anpassen + neue):

- `test_seriesWithThreeInstances_showsCounterBarX3` — sucht `stackingCounterBar_*` mit Label enthaelt "3" UND "AUFGELAUFEN"
- `test_seriesWithTwoInstances_showsCounterBarX2` — analog mit "2"
- `test_stackedSeries_rendersAsSingleRow` — genau 1 Wochenreview-Row
- `test_singleInstanceSeries_hasNoCounterBar` — Negativtest mit Anker
- `test_stackedTask_inHeuteOrDringendSection` — neuer Test: Wochenreview-Row ist NICHT in "Ueberfaellig" sondern in Tier-Sektion (juengstes-Child-Logic)
- `test_counterBar_showsOldestDate` — Untertitel "seit Fri 17. Apr" sichtbar in der Bar

**macOS** (`FocusBloxMacUITests/MacParkdeckStackingUITests.swift`) — analog.

### Unit-Tests (`FocusBloxTests/RecurringStackingTests.swift`)

- `test_stacking_representativeIsYoungestChild` — Repraesentant hat juengstes dueDate
- `test_stacking_stackedOldestDueDateIsOldest` — `stackedOldestDueDate` weiterhin auf aeltestes
- `test_stacking_singleChild_noStacking` — Negativfall

## Definition of Done

- ✅ Alle UI-Tests GREEN (iOS + macOS)
- ✅ Unit-Tests GREEN
- ✅ Visueller Beweis: Screenshot iOS + macOS zeigt Counter-Bar prominent
- ✅ Mock-Sentinel-Fix: Alte DB triggert Re-Seed der Recurring-Mocks
- ✅ Adversary-Verdict: VERIFIED
- ✅ Henning gibt Commit-Freigabe nach Sicht der Screenshots
