# Bug-Analyse: QuickCaptureView "Speichern" schließt Dialog nicht

**Bug-Report:** Schnellspeichern Dialog schließt nicht wenn man auf Speichern klickt (iOS)
**Plattform:** iOS
**Screen:** QuickCaptureView (Schnellerfassung)
**Datum:** 2026-03-09

---

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- **Bug 74** (commit `ee161df`, 2026-03-09): EXAKT dasselbe Problem in TaskFormSheet Create-Mode
- Root Cause damals: `dismiss()` wurde ASYNCHRON innerhalb `Task { await MainActor.run { dismiss() } }` aufgerufen
- Fix damals: `dismiss()` SYNCHRON VOR dem `Task {}` Block aufrufen
- **QuickCaptureView wurde beim Bug 74 Fix NICHT mitgefixt**

### Agent 2: Datenfluss-Trace
- QuickCaptureView.swift Zeile 353-389: Gesamter Save-Flow läuft in `Task {}`
- `dismiss()` wird in Zeile 383 aufgerufen — INNERHALB des async Task, NACH 600ms Sleep
- TaskFormSheet (bereits gefixt) ruft `dismiss()` in Zeile 428 SYNCHRON auf

### Agent 3: Alle Schreiber
- Nur QuickCaptureView nutzt `Task.sleep()` vor `dismiss()`
- Alle anderen Sheets nutzen synchrones `dismiss()`
- Kommentar in TaskFormSheet Zeile 426: "async dismiss inside Task{} breaks on iOS 26"

### Agent 4: Szenarien
- KRITISCH: `@Environment(\.dismiss)` Referenz wird ungültig wenn View re-rendert während Task läuft
- `showSuccess = true` (Zeile 376) löst View-Neuzeichnung aus → dismiss-Referenz kann veralten
- 600ms Fenster erhöht Wahrscheinlichkeit einer View-Invalidierung

### Agent 5: Blast Radius
- 27 dismiss()-Aufrufe sind SAFE (synchron)
- 2 weitere BROKEN: SprintReviewSheet:324 und MacFocusView:895 (dismiss inside Task)
- 1 RISKY: VoiceInputSheet:55 (dismiss inside delayed DispatchWorkItem)

---

## Hypothesen

### Hypothese 1: Async dismiss Pattern (HÖCHSTE Wahrscheinlichkeit)

**Beschreibung:** `dismiss()` wird in QuickCaptureView Zeile 383 innerhalb eines `Task {}` Blocks aufgerufen, nach einem 600ms `Task.sleep()`. Auf iOS 26 wird die `@Environment(\.dismiss)` Referenz ungültig wenn die View zwischen Task-Start und dismiss-Aufruf re-rendert.

**Beweis DAFÜR:**
- Exakt dasselbe Pattern verursachte Bug 74 in TaskFormSheet
- Kommentar im Code (Zeile 426 TaskFormSheet) bestätigt: "async dismiss inside Task{} breaks on iOS 26"
- `showSuccess = true` (Zeile 376) löst View-Update aus → dismiss-Referenz wird vor Zeile 383 ungültig
- Alle anderen Sheets mit synchronem dismiss funktionieren korrekt

**Beweis DAGEGEN:**
- Das Pattern hat möglicherweise früher funktioniert (bevor iOS 26.2)
- Keine 100%-Reproduktion — manchmal könnte es funktionieren wenn kein Re-Render passiert

**Wahrscheinlichkeit: HOCH (95%)**

### Hypothese 2: DeferredSortController interferiert (Hennings Vermutung)

**Beschreibung:** Der 3-Sekunden Delay im DeferredSortController könnte BacklogView re-rendern lassen, was die Sheet-Dismiss-Animation unterbricht.

**Beweis DAFÜR:**
- DeferredSortController nutzt `withAnimation()` Blöcke die mit Dismiss-Animation konkurrieren könnten
- Wenn QuickCapture aus BacklogView geöffnet wird, könnte ein laufender Deferred Sort den Parent neu zeichnen

**Beweis DAGEGEN:**
- QuickCaptureView wird aus FocusBloxApp.swift präsentiert (Zeile 319), NICHT aus BacklogView
- DeferredSortController betrifft nur BacklogView-interne State-Updates
- Der Delay verhindert Sortierung, er blockiert nicht Sheet-Dismiss

**Wahrscheinlichkeit: NIEDRIG (5%)**

### Hypothese 3: CloudKit Sync während Dismiss

**Beschreibung:** CloudKit Remote Change triggert `refreshLocalTasks()` in BacklogView während QuickCaptureView dismiss läuft.

**Beweis DAFÜR:**
- CloudKit Monitor hat 200ms Delay + refreshLocalTasks() (BacklogView Zeile 332)
- Theoretisch könnte ein Background-Sync den View-Tree destabilisieren

**Beweis DAGEGEN:**
- QuickCaptureView wird von FocusBloxApp.swift präsentiert, nicht von BacklogView
- CloudKit Updates betreffen den BacklogView ModelContext, nicht die Sheet-Präsentation

**Wahrscheinlichkeit: SEHR NIEDRIG (< 1%)**

---

## Wahrscheinlichste Ursache

**Hypothese 1: Async dismiss Pattern** — mit 95% Sicherheit.

Identisches Pattern wie Bug 74. Der Fix wurde bei Bug 74 nur auf TaskFormSheet angewendet, QuickCaptureView wurde übersehen.

**Code-Stelle:** `Sources/Views/QuickCaptureView.swift` Zeilen 353-389

**Warum die anderen weniger wahrscheinlich sind:**
- Hypothese 2 (DeferredSort): QuickCaptureView wird von FocusBloxApp präsentiert, nicht von BacklogView
- Hypothese 3 (CloudKit): Kein direkter Zusammenhang zwischen CloudKit Monitor und Sheet-Präsentation

---

## Blast Radius

Gleiche broken Pattern an 3 weiteren Stellen:
1. **SprintReviewSheet.swift:324** — `dismiss()` inside `Task {}` nach async Operation
2. **MacFocusView.swift:895** — `dismiss()` inside `Task {}` (macOS SprintReview)
3. **VoiceInputSheet.swift:55** — `dismiss()` inside delayed `DispatchWorkItem`

---

## Fix-Vorschlag

QuickCaptureView `saveTask()` umbauen: dismiss() SYNCHRON aufrufen, dann async Task für Hintergrund-Arbeit.

**Herausforderung:** Die 600ms Success-Animation muss erhalten bleiben. Lösung: Animation über State-Change + onChange statt Task.sleep.

Betroffene Dateien: 1 (QuickCaptureView.swift), ~20 LoC Änderung.
