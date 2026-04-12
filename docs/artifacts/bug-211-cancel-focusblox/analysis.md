# Bug #211: FocusBlox abbrechen — Analyse

## Symptome
- LivePreview läuft nach Abbrechen weiter
- Verbleibende Zeit im App-Dialog läuft weiter
- Abbrechen-Button bleibt aktiv

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
7 verwandte Bugs gefunden (#41, #39, #15, #55, #42, #40, #69). Bekannte Muster:
- LiveActivity-Orphans (Bug #55E)
- Timer zählt über Block-Ende hinaus (Bug #41)
- Sprint Review Dauerloop (Bug #42)
- Kein expliziter Cancel-Bug bisher — **Bug #211 ist NEU**

### Agent 2: Datenfluss-Trace
Abort-Flow: Button (Zeile 362-364) → `isAbortingBlock=true` + `showSprintReview=true` → SprintReviewSheet → onDismiss (Zeile 153-163) → `loadData()`.
**Kritisch:** `liveActivityManager.endActivity()` wird im Abort-Flow NIRGENDS aufgerufen.

### Agent 3: Alle Schreiber
- `endActivity()` wird nur in 2 Stellen aufgerufen: `onChange(activeBlock?.id)` (Zeile 198) und `checkBlockEnd()` (Zeile 738)
- Beim Abort ändert sich `activeBlock?.id` NICHT (gleicher Block) → onChange feuert nicht
- `checkBlockEnd()` feuert nur bei `block.isPast` → Block ist beim Abort noch aktiv

### Agent 4: Szenarien
5 Fehlszenarien identifiziert. **Szenario 5 ist der Haupttreffer:** `loadData()` findet den Block noch als `isActive` → `activeBlock` bleibt gleich → `onChange` feuert nicht → LiveActivity wird nicht beendet → Timer läuft weiter → UI zeigt weiterhin aktiven Block.

### Agent 5: Blast Radius
- macOS hat gleichen Code-Pfad (kein LiveActivity, aber Timer/State)
- `returnIncompleteTasksToNextUp()` wird nur bei `block.isPast` aufgerufen (Zeile 158) — beim Abort ist Block noch aktiv

---

## Hypothesen

### Hypothese A: Fehlende LiveActivity-Beendigung beim Abort (HOCH)
**Beweis dafür:**
- `endActivity()` wird NUR aufgerufen in `checkBlockEnd()` (Zeile 738) und `onChange(activeBlock?.id)` (Zeile 198)
- Beim Abort: Block ist noch `isActive` → `checkBlockEnd()` Bedingung `block.isPast` ist false → kein `endActivity()`
- Beim Abort: `activeBlock?.id` ändert sich nicht (gleicher Block) → `onChange` feuert nicht → kein `endActivity()`
- **Ergebnis: LiveActivity wird NIEMALS beendet beim Abort**

**Beweis dagegen:** Keiner. Der Code-Pfad ist eindeutig — es gibt keinen dritten Ort wo `endActivity()` beim Abort aufgerufen wird.

### Hypothese B: `loadData()` setzt `activeBlock` auf denselben Block zurück (HOCH)
**Beweis dafür:**
- `loadData()` Zeile 577: `activeBlock = blocks.first { $0.isActive }` → Block hat noch Zeit → wird wieder gefunden
- `activeBlock?.id` ändert sich nicht → View zeigt weiterhin den aktiven Block mit Timer
- Abbrechen-Button bleibt sichtbar, weil `activeBlock != nil`

**Beweis dagegen:** Keiner. EventKit-Block wird beim Abort nicht gelöscht oder als beendet markiert.

### Hypothese C: `returnIncompleteTasksToNextUp()` wird beim Abort nicht aufgerufen (MITTEL)
**Beweis dafür:**
- Zeile 158: `if block.isPast { returnIncompleteTasksToNextUp(block: block) }`
- Beim Abort ist Block noch `isActive` → Bedingung false → Tasks bleiben im Block

**Beweis dagegen:** Dieses Problem verursacht nicht die gemeldeten Symptome (Timer/LiveActivity), sondern ein Folge-Problem (Tasks nicht zurückgesetzt).

### Hypothese D: Swipe-Down Dismiss umgeht onDismiss (MITTEL)
**Beweis dafür:** SprintReviewSheet Zeile 85-88: `onDismiss()` wird NUR im "Fertig"-Button aufgerufen. `.sheet(isPresented:)` in FocusLiveView Zeile 146 hat KEINEN `onDismiss`-Parameter. Bei Swipe-Down wird `showSprintReview = false` via Binding, aber `onDismiss()` wird NICHT aufgerufen → `isAbortingBlock` bleibt `true`, `reviewDismissed` bleibt `false`, `loadData()` wird nicht aufgerufen.
**Beweis dagegen:** Kein Gegenbeweis. Dies ist ein eigenständiger Bug-Pfad, der zusätzlich zu A+B existiert.

---

## Wahrscheinlichste Ursache

**Kombination aus Hypothese A + B:**

1. User drückt "Abbrechen" → `showSprintReview = true`
2. SprintReviewSheet öffnet, Timer läuft weiter im Hintergrund
3. User schließt Review → `onDismiss` → `loadData()`
4. `loadData()` findet Block noch als `isActive` (er hat noch Zeit!)
5. `activeBlock` = gleicher Block → `onChange(activeBlock?.id)` feuert NICHT
6. **LiveActivity wird NICHT beendet** (kein Code-Pfad führt zu `endActivity()`)
7. **Timer läuft weiter** (Block ist noch aktiv)
8. **Abbrechen-Button bleibt** (activeBlock != nil)

**Der Block wird beim Abbrechen nicht als "beendet" markiert und die LiveActivity wird nicht explizit gestoppt.**

---

## Debugging-Plan

### Bestätigung der Hypothese:
1. Logging in Abort-Button-Handler: `print("ABORT: activeBlock.id=\(block.id), isActive=\(block.isActive), isPast=\(block.isPast)")`
2. Logging in `onDismiss`: `print("DISMISS: activeBlock.id=\(activeBlock?.id), isActive=\(activeBlock?.isActive)")`
3. Logging in `loadData()` nach activeBlock-Zuweisung: `print("RELOAD: activeBlock.id=\(activeBlock?.id), changed=\(oldId != newId)")`
4. Prüfen ob `endActivity()` aufgerufen wird: bereits Logging vorhanden ("END called")

### Widerlegung:
- Wenn `endActivity()` Log ERSCHEINT nach Abort → Hypothese A falsch
- Wenn `activeBlock` nach loadData() `nil` ist → Hypothese B falsch

---

## Blast Radius
- **macOS:** NICHT betroffen — MacFocusView hat keinen Abbrechen-Button. macOS-User können aktive Blöcke gar nicht abbrechen (Feature-Gap, separates Backlog-Item)
- **SprintReviewSheet:** Follow-up Tasks bekommen falsche elapsed time (taskStartTime nicht reset)
- **Unerledigte Tasks:** Werden beim Abort nicht zu Next Up zurückgesetzt (nur bei `isPast`)
- **Swipe-Down Dismiss:** Zweiter Bug-Pfad — onDismiss wird nicht aufgerufen bei Swipe-Down

## Fix-Ansatz (Vorschlag)

Im Abort-Button-Handler (Zeile 362-364) **zusätzlich**:
1. `liveActivityManager.endActivity()` aufrufen
2. `liveActivityStarted = false` setzen
3. `taskStartTime` auf nil setzen (für korrekte elapsed time)
4. In `onDismiss`: `block.isPast`-Check durch `isAbortingBlock || block.isPast` ersetzen (damit Tasks auch bei aktivem Block zurückgesetzt werden)

5. `.sheet(isPresented:)` mit `onDismiss`-Parameter versehen, damit auch Swipe-Down den State korrekt zurücksetzt

**Betroffene Dateien:** 1 (FocusLiveView.swift), ca. 8-12 LoC Änderung
