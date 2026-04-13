# Bug #221: LiveUpdates werden nicht beendet — Analyse (v2, nach Challenge)

## Zusammenfassung der Agenten-Ergebnisse + Challenge

5 Investigate-Agenten + 1 Devil's Advocate. Challenge-Verdict: LÜCKEN.
Analyse wurde überarbeitet mit den gefundenen Lücken.

## Hypothesen (überarbeitet)

### Hypothese A: App-Kill/Neustart — Orphan Activity ohne Cleanup (SEHR HOCH)

**Der wahrscheinlichste Reproduktionsweg:**

1. User startet Sprint → Live Activity läuft auf Lock Screen
2. User schließt App (Force Kill) oder App wird vom System beendet
3. Sprint endet während App nicht läuft
4. User öffnet App erneut
5. **Neuer `LiveActivityManager` wird erstellt** → `currentActivity = nil` (FocusLiveView:69)
6. `.task { await loadData() }` läuft → findet past Block → setzt `showSprintReview = true` (Zeile 581)
7. Timer startet → `checkBlockEnd()` → Guard `!showSprintReview` ist FALSE → `endActivity()` wird **NIE aufgerufen**
8. Selbst WENN endActivity() aufgerufen würde: `currentActivity` ist nil → Guard returnt sofort (LiveActivityManager:102)
9. **Orphan-Cleanup existiert nur in `startActivity()` (Zeile 25-27)** — wird nie aufgerufen bis User neuen Sprint startet
10. → **Live Activity bleibt auf Lock Screen** bis iOS sie nach 4+ Stunden entfernt

**Beweis:**
- LiveActivityManager:102: `guard let activity = currentActivity else { return }` — bei nil: sofortige Rückkehr
- LiveActivityManager:113-115: Orphan-Cleanup ist INNERHALB des Tasks der vom Guard geschützt wird → bei nil currentActivity unerreichbar
- FocusLiveView:581: `if activeBlock?.isPast == true && !reviewDismissed { showSprintReview = true }` — OHNE endActivity()
- FocusLiveView:712: `if block.isPast && !showSprintReview && !reviewDismissed` — Guard blockiert nach loadData

**Wahrscheinlichkeit: SEHR HOCH** — häufigster Pfad (App im Hintergrund, Sprint läuft aus)

### Hypothese B: onChange-Totewinkel — activeBlock.id ändert sich nicht (HOCH)

`onChange(of: activeBlock?.id)` (Zeile 185) ist ein Backup das endActivity() aufruft. ABER:

- Wenn Sprint endet, bleibt `activeBlock` derselbe Block (gleiche ID), nur `isPast` wird true
- `loadData()` Zeile 579-580: `activeBlock = first { $0.isActive } ?? filter { $0.isPast }.last`
- Block wechselt von "isActive=true" zu "isPast=true", aber **ID bleibt gleich**
- → `onChange(of: activeBlock?.id)` feuert **NICHT**
- → Dieser "Backup-Endpunkt" ist de facto toter Code für den Sprint-End-Case

**Wahrscheinlichkeit: HOCH** — macht onChange als Safety Net wirkungslos

### Hypothese C: scenePhase-Handler hat keinen Live-Activity-Cleanup (HOCH)

- FocusBloxApp.swift:410-451: `onChange(of: scenePhase)` behandelt `.active` und `.background`
- `.active` Handler: Quick Actions, Badge-Update, Widget-Publish — **kein endActivity()**
- `.background` Handler: Notification-Reconcile, Widget-Publish — **kein endActivity()**
- Wenn App aus Background zurückkommt, wird **kein Live-Activity-Check** gemacht

**Wahrscheinlichkeit: HOCH** — verstärkt Hypothese A

### Hypothese D: loadData setzt showSprintReview VOR checkBlockEnd (MITTEL)

Auch OHNE App-Kill: Wenn `.task { await loadData() }` schneller als der erste Timer-Tick (1 Sekunde) ist:
- loadData() setzt showSprintReview=true
- checkBlockEnd() Guard blockiert

Aber: Im normalen Fall (User sitzt auf Focus-Tab, Sprint läuft ab) feuert der Timer jede Sekunde. checkBlockEnd() erkennt `block.isPast` sofort und ruft endActivity() auf. Dieser Pfad funktioniert.

**Wahrscheinlichkeit: MITTEL** — nur relevant bei App-Neustart, dort durch Hypothese A abgedeckt

## Wahrscheinlichste Ursache

**Hypothese A (App-Kill/Neustart) ist die primäre Ursache**, verstärkt durch B (onChange unwirksam) und C (kein scenePhase-Cleanup).

Der Kern: **Es gibt keinen Orphan-Cleanup bei App-/View-Initialisierung.** Die einzige Orphan-Cleanup-Stelle ist `startActivity()` — die erst beim NÄCHSTEN Sprint aufgerufen wird.

## Debugging-Plan

### Bestätigung Hypothese A:
- **Logging in LiveActivityManager.init():** `print("🆕 [LA] init: Orphans=\(Activity<FocusBlockActivityAttributes>.activities.count)")`
- **Bestätigt wenn:** App-Start nach abgelaufenem Sprint zeigt Orphans > 0
- **Widerlegt wenn:** Orphan-Count ist 0

### Bestätigung Hypothese B:
- **Logging in onChange:** Prüfen ob onChange nach Sprint-Ende feuert
- **Bestätigt wenn:** onChange NIE feuert nach Sprint-Ende (gleiche Block-ID)

### Plattform: NUR iOS

## Blast Radius

- **Nur FocusLiveView betroffen** — einziger Nutzer von LiveActivityManager
- **iOS-only** — macOS hat kein ActivityKit
- **Kein Datenverlust** — rein visuelles Problem (Lock Screen / Dynamic Island)
- **User-Impact:** Live Activity bleibt sichtbar bis iOS sie nach staleDate + 4h automatisch entfernt

## Fix-Ansatz (Vorschlag)

**Zentraler Fix:** Orphan-Cleanup bei View-Initialisierung + loadData-Past-Block-Detection

1. **LiveActivityManager: `cleanupOrphans()` Methode** — kann OHNE currentActivity aufgerufen werden
2. **FocusLiveView: Orphan-Cleanup in `.task`** — beim View-Appear alle System-Activities beenden wenn kein aktiver Sprint läuft
3. **loadData(): endActivity() aufrufen** wenn past Block gefunden wird und Live Activity noch läuft
