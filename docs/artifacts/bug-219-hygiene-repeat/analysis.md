# Bug #219: Tasks werden zur Hygiene vorgeschlagen, obwohl bereits bearbeitet

## Symptom
User klickt "Behalten" im Hygiene-Dialog. Task wird sofort wieder als stale vorgeschlagen statt nach 30 Tagen Grace Period. "In 14 Tage wiederholen funktioniert nicht."

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- Feature in 3 Slices implementiert: #213 (Erkennung), #214 (Split), #215 (Nudges)
- Kein früherer Fix für dieses Problem — es wurde nie behoben
- `hygieneReviewedAt` wurde mit #215 eingeführt, aber nie im Produktionscode geschrieben

### Agent 2 (Datenfluss-Trace)
- `hygieneReviewedAt` definiert in LocalTask (Z.135) und PlanItem (Z.70)
- Gelesen in BacklogHealthService.findStaleTasks() (Z.33-38)
- **NIRGENDWO im Produktionscode auf Date() gesetzt** — nur in Tests (BacklogHygieneNudgeTests Z.140)

### Agent 3 (Alle Schreiber)
- Bestätigt: Kein einziger Produktions-Schreibzugriff auf `hygieneReviewedAt`
- `keepTask()` (Z.217-228): Nur UI-Logik, keine Persistierung
- `parkTask()` (Z.198-206): Setzt isParked + modifiedAt, nicht hygieneReviewedAt

### Agent 4 (Szenarien)
- 8 Szenarien identifiziert, alle auf denselben Root Cause zurückführbar
- Kritischste: "Behalten" → sofort wieder stale, Badge bleibt, Notification jede Woche

### Agent 5 (Blast Radius)
- 5 Call-Sites für findStaleTasks: MainTabView Badge, BacklogView, macOS ContentView, SidebarView, SmartNotificationEngine
- macOS Settings fehlen (MacSettingsView hat keine Hygiene-Optionen)

---

## Hypothesen

### Hypothese 1: `keepTask()` setzt `hygieneReviewedAt` nicht (HOCH)
- **Beweis dafür:** Code in Z.217-228 enthält keinen DB-Zugriff. `findLocalTask()` wird nicht aufgerufen. `hygieneReviewedAt` kommt nicht vor.
- **Beweis dagegen:** Keiner — alle 5 Agenten bestätigen dies unabhängig.
- **Wahrscheinlichkeit:** HOCH (99%)

### Hypothese 2: `hygieneReviewedAt` wird irgendwo anders gesetzt, aber überschrieben (NIEDRIG)
- **Beweis dafür:** Keiner gefunden. Grep nach `hygieneReviewedAt =` liefert nur Tests und Init-Zuweisungen (nil).
- **Beweis dagegen:** 3 Agenten haben unabhängig bestätigt, dass es keinen Produktions-Schreibzugriff gibt.
- **Wahrscheinlichkeit:** NIEDRIG (1%)

### Hypothese 3: BacklogHealthService Filter-Logik ist fehlerhaft (NIEDRIG)
- **Beweis dafür:** Keiner — Unit Tests bestätigen korrektes Verhalten (test_staleTasksExcludesRecentlyReviewed, test_staleTasksIncludesOldReview).
- **Beweis dagegen:** Filter-Logik ist korrekt, wird aber nie aktiviert weil hygieneReviewedAt immer nil ist.
- **Wahrscheinlichkeit:** NIEDRIG (0%)

---

## Root Cause

**`keepTask()` in BacklogHygieneView.swift (Z.217-228) persistiert NICHTS.**

Die Funktion fügt nur `.kept` zur lokalen `actions`-Liste hinzu und zeigt einen UI-Hint. Der zugehörige `LocalTask` wird nie modifiziert — `hygieneReviewedAt` bleibt `nil`. Dadurch greift die 30-Tage Grace Period in BacklogHealthService nie, und der Task wird sofort wieder als stale erkannt.

## Debugging-Plan
- Logging an `keepTask()`: Print ob findLocalTask aufgerufen wird → wird nicht, Code fehlt
- Logging an `findStaleTasks()`: Print hygieneReviewedAt-Wert → wird nil sein

## Blast Radius
- **TabBar Badge (iOS):** Zeigt weiterhin falsche stale-Counts
- **Sidebar Badge (macOS):** Zeigt stale-Count, aber macOS hat KEINEN Hygiene-Dialog — User kann Badge nur sehen, nicht handeln (separates Feature-Gap, nicht Bug #219)
- **Wöchentliche Notification:** Nervt User jede Woche mit denselben Tasks

## Adressierte Lücken aus Challenge Runde 1

### Lücke 1: UI-Hint-Mismatch (14 vs 30 Tage)
BacklogHygieneView Z.139 zeigt `backlogStaleAgeDays` (Default 14), aber BacklogHealthService.hygieneReviewGraceDays ist 30 Tage hardcoded. **Fix:** Hint zeigt `hygieneReviewGraceDays` (30) statt `backlogStaleAgeDays` (14).

### Lücke 2: splitCompleted() setzt auch kein hygieneReviewedAt
BacklogHygieneView Z.230-233: `splitCompleted()` fügt nur `.split` zur actions-Liste hinzu. **Fix:** In splitCompleted() ebenfalls `hygieneReviewedAt = Date()` setzen.

### Lücke 3: macOS Blast Radius korrigiert
macOS hat KEINEN Hygiene-Dialog. Der Sidebar-Badge zeigt stale-Counts, aber User kann nicht handeln. Das ist ein separates Feature-Gap, kein Bug #219.
