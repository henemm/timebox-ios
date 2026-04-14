# Bug #216: Sprint-Ende — Analyse

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- Bug #42 (Review-Dauerloop): `reviewDismissed` Flag eingeführt — hält
- Bug #211 (Abort-Flow): LiveActivity + Timer-Reset bei Abort — hält
- Bug #218 (Notification): Cleanup nach Review — hält
- Alle bisherigen Fixes stabil, kein Revert

### Agent 2: Datenfluss-Trace
- `showSprintReview` wird an 4 Stellen true gesetzt (iOS), 3 Stellen (macOS)
- `reviewDismissed` wird in ALLEN Dismiss-Pfaden korrekt auf true gesetzt
- `isAbortingBlock` existiert NUR auf iOS, nicht macOS
- Kein Dismiss-Pfad-Leck gefunden — reviewDismissed funktioniert

### Agent 3: Alle Schreiber
- 18 State-Zuweisungen identifiziert (12 iOS, 6 macOS)
- Kritisch: macOS hat kein `isAbortingBlock` — simpler, aber auch kein Abort-Button

### Agent 4: Alle Szenarien
- 6 Szenarien identifiziert: natürliches Ende, Abort, Early Review, 3 Dismiss-Wege, App-Neustart, Re-Open
- Nach Dismiss: Block bleibt in UI sichtbar (activeBlock), aber Review kann nicht erneut geöffnet werden (reviewDismissed)
- Edge Case Early Review: Block läuft noch weiter → checkBlockEnd() könnte noch feuern

### Agent 5: Blast Radius
- SprintReviewSheet nur von FocusLiveView genutzt
- MacSprintReviewSheet nur von MacFocusView genutzt
- macOS hat KEINEN Abort-Button (robuster)
- Keine spezifischen SprintReviewSheet-Unit-Tests vorhanden

---

## Hypothesen

### Hypothese 1: "Abbrechen" ist IMMER sichtbar — kein isPast-Guard (HOCH)

**Beschreibung:** Der Abort-Button in `progressHeader` (FocusLiveView.swift:367-382) wird IMMER gerendert, unabhängig davon ob `block.isPast` true ist. Nach Sprint-Ende sieht der User weiterhin "Abbrechen" — obwohl Abbrechen bei einem bereits beendeten Sprint keinen Sinn macht.

**Beweis DAFÜR:**
- FocusLiveView.swift:367-382: Button hat KEINE Bedingung `if !block.isPast`
- `progressHeader` wird für jeden `activeBlock` gerendert (Zeile 277)
- Screenshots in Issue #216 zeigen "Abbrechen" nach Sprint-Ende

**Beweis DAGEGEN:**
- Keiner — der Code hat definitiv keinen Guard

**Wahrscheinlichkeit: HOCH**

---

### Hypothese 2: Doppelter Dismiss in SprintReviewSheet — UX-Verwirrung (HOCH)

**Beschreibung:** SprintReviewSheet hat zwei Dismiss-Wege die identisch aussehen:
1. Toolbar "Fertig" (Zeile 85-89): `dismiss()` + `onDismiss()`
2. Action-Button "Sprint Review beenden" (Zeile 314-328): `dismiss()` + `onDismiss()`

Beide tun exakt dasselbe. Henning fragt: "Was ist der Unterschied?"

**Beweis DAFÜR:**
- SprintReviewSheet.swift:85-89 vs. 314-328: Identische Logik
- Issue #216: "Was ist der Unterschied zwischen 'Fertig' und 'Sprint Review beenden'?"

**Beweis DAGEGEN:**
- Keiner — beide Buttons sind funktional identisch

**Wahrscheinlichkeit: HOCH**

---

### Hypothese 3: Swipe-Down-Dismiss-Leck — reviewDismissed wird NICHT gesetzt (HOCH)

**Beschreibung:** Der `.sheet(isPresented:onDismiss:)` Handler (Zeile 146-156) setzt `reviewDismissed = true` NUR wenn `isAbortingBlock == true`. Bei normalem Sprint-Ende (kein Abort) und Swipe-Down-Dismiss wird `reviewDismissed` NICHT gesetzt. Der SprintReviewSheet-eigene `onDismiss`-Callback (Zeile 164-178) wird bei Swipe-Down NICHT aufgerufen — nur die Sheet-eigene onDismiss-Closure. Danach kann `checkBlockEnd()` oder `loadData()` erneut `showSprintReview = true` setzen → **echter Loop**.

**Beweis DAFÜR:**
- FocusLiveView.swift:152-155: `if isAbortingBlock` Guard — bei normalem Ende ist isAbortingBlock false → reviewDismissed bleibt false
- Issue #216: "Egal was man drückt, man kommt wieder in den vorherigen Dialog"
- checkBlockEnd() (Zeile 734) prüft `!reviewDismissed` — wenn false geblieben, re-öffnet sich Review

**Beweis DAGEGEN:**
- Keiner — der Code ist eindeutig

**Wahrscheinlichkeit: HOCH** — erklärt Hennings Loop-Beobachtung direkt

---

### Hypothese 4: Nach Review bleibt Block sichtbar mit verwirrenden Buttons (MITTEL)

**Beschreibung:** Nach dem Schließen des Sprint Reviews bleibt der abgelaufene Block als `activeBlock` in der UI. Der User sieht weiterhin `activeFocusContent` mit dem "Abbrechen"-Button (Hypothese 1). Falls alle Tasks erledigt sind, sieht er auch `allTasksCompletedView` mit "Sprint Review starten" — obwohl das Review gerade beendet wurde.

**Beweis DAFÜR:**
- Agent 4: "Block bleibt in UI sichtbar (activeBlock), aber Review kann nicht erneut geöffnet werden"
- `loadData()` lädt den Block erneut (er ist ja noch im Kalender)
- `reviewDismissed` verhindert nur das automatische Review-Popup, nicht den manuellen "Sprint Review starten"-Button

**Beweis DAGEGEN:**
- Müsste verifiziert werden ob "Sprint Review starten" den `reviewDismissed`-Check umgeht

**Wahrscheinlichkeit: MITTEL — braucht Verifikation**

---

## Wahrscheinlichste Ursachen

1. **Hypothese 1** (Abort-Button ohne isPast-Guard) — SICHER, Code-Beweis
2. **Hypothese 2** (Doppelter Dismiss in iOS SprintReviewSheet) — SICHER, Code-Beweis. macOS hat nur 1 Button — KEIN Doppel-Dismiss dort.
3. **Hypothese 3** (Swipe-Down-Dismiss-Leck) — SICHER, Code-Beweis: reviewDismissed wird bei normalem Swipe-Down NICHT gesetzt → Loop
4. **Hypothese 4** ("Sprint Review starten" ohne reviewDismissed-Check) — SICHER, Code-Beweis: Zeile 515 hat keinen Guard. macOS identisch betroffen (MacFocusView:320-328).

## Debugging-Plan

Um Hypothese 4 zu beweisen/widerlegen:
- **Logging in `allTasksCompletedView`:** Prüfen ob "Sprint Review starten" nach dem Review noch sichtbar ist
- **Logging in "Sprint Review starten" Button:** Prüfen ob `reviewDismissed` dort gecheckt wird (Zeile 512-515 — KEIN Check!)
- **Plattform:** iOS primär, macOS sekundär (kein Abort-Button dort)

**BESTÄTIGT durch Code-Lesen:** FocusLiveView.swift:512-515 prüft `reviewDismissed` NICHT — der Button ist immer aktiv!

## Blast Radius
- iOS: FocusLiveView.swift + SprintReviewSheet.swift
- macOS: MacFocusView.swift (weniger betroffen — kein Abort-Button, aber auch doppelter Dismiss in MacSprintReviewSheet)
- Keine anderen Features betroffen
