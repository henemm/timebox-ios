# Bug-Analyse: AI-Enrichment greift nicht bei neuen Tasks

**Bug:** Wenn ein neuer Task angelegt wird ohne die erweiterten Attribute zu fuellen, soll die AI greifen und die Attribute automatisch fuellen. Das funktioniert weder auf iOS noch auf macOS. Der Switch ist an.

**Datum:** 2026-02-21

---

## Agenten-Ergebnisse (Zusammenfassung)

### Agent 1 (Wiederholungs-Check)
- 3 vorherige Commits gefunden die Enrichment betreffen (7990fb6, 6f87ef8, 7d02b75)
- Enrichment wurde in Commit 7990fb6 eingefuehrt, aber nur in 2 von 6+ Creation-Paths eingebaut
- Vorheriger Bug-Artifact (2026-02-19) existiert, hat aber keine Call-Site-Analyse gemacht

### Agent 2 (Datenfluss-Trace)
- Kompletter Datenfluss verifiziert: SmartTaskEnrichmentService ist korrekt implementiert
- Gates (isAvailable + aiScoringEnabled) funktionieren
- Foundation Models API-Aufruf ist korrekt (LanguageModelSession + @Generable)
- Ergebnisse werden korrekt zurueckgeschrieben (nur nil/leere Felder)

### Agent 3 (Alle Schreiber)
- SmartTaskEnrichmentService schreibt: importance, urgency, taskType, aiEnergyLevel
- AITaskScoringService existiert, wird aber NIRGENDS in Production aufgerufen (Dead Code)
- LocalTaskSource.createTask() hat keine Auto-Enrichment-Logik

### Agent 4 (Alle Szenarien)
- 3 iOS-Creation-Paths, 3 macOS-Creation-Paths identifiziert
- Nur je 1 Path pro Plattform ruft enrichTask() auf
- Keine Race Conditions, Service-Logik ist korrekt

### Agent 5 (Blast Radius)
- 6+ Task-Creation-Paths gefunden, nur 2 haben Enrichment
- Auch Siri Intent (SaveQuickCaptureIntent) und RecurrenceService fehlt Enrichment
- Risiko: MODERAT (kosmetisch, kein Datenverlust)

---

## Ueberlappung der Ergebnisse

**Alle 5 Agenten kommen zum gleichen Schluss:**
Der SmartTaskEnrichmentService ist korrekt implementiert, wird aber in den meisten Task-Creation-Paths nicht aufgerufen.

---

## Hypothesen

### Hypothese 1: Fehlende enrichTask()-Aufrufe in Task-Creation-Paths (HOCH)

**Beschreibung:** `SmartTaskEnrichmentService.enrichTask()` wird nur in 2 von 6+ Task-Creation-Paths aufgerufen:

| Path | Plattform | enrichTask()? |
|------|-----------|---------------|
| CreateTaskView.saveTask() | iOS | JA (Zeile 276-277) |
| ContentView.addTask() | macOS | JA (Zeile 717-718) |
| **TaskFormSheet.saveTask()** | **iOS** | **NEIN** |
| **QuickCaptureView.saveTask()** | **iOS** | **NEIN** |
| **MenuBarView.addTask()** | **macOS** | **NEIN** |
| **QuickCapturePanel.addTask()** | **macOS** | **NEIN** |

**Beweis DAFUER:** Grep nach `enrichTask` zeigt exakt 2 Call-Sites in Production-Code (CreateTaskView:276, ContentView:717). Alle anderen createTask()-Aufrufe haben KEINEN nachfolgenden enrichTask()-Aufruf.

**Beweis DAGEGEN:** Wenn der User ausschliesslich CreateTaskView (iOS) oder ContentView Quick-Add (macOS) nutzt, SOLLTE Enrichment funktionieren. Aber Henning sagt es funktioniert auf KEINER Plattform.

**Wahrscheinlichkeit:** HOCH - erklaert das Problem fuer die meisten Flows, aber nicht komplett fuer alle.

### Hypothese 2: Enrichment funktioniert auch in den 2 vorhandenen Paths nicht (MITTEL)

**Beschreibung:** Selbst dort wo enrichTask() aufgerufen wird, koennte es still fehlschlagen:
- Foundation Models nicht verfuegbar (Device/Simulator)
- Fehler wird nur per `print()` geloggt (Zeile 151-153)
- Kein UI-Feedback ob Enrichment lief oder fehlschlug

**Beweis DAFUER:**
- Error-Handling ist `print()` only - User sieht nichts
- `isAvailable` prueft `SystemLanguageModel.default.availability` - koennte auf bestimmten Geraeten false sein
- Kein visuelles Feedback nach Enrichment

**Beweis DAGEGEN:**
- Setting-Default ist `true` (Commit 7d02b75)
- isAvailable sollte auf Apple Silicon Devices true sein
- Henning sagt Switch ist an

**Wahrscheinlichkeit:** MITTEL - koennte zusaetzlich zum fehlenden Aufruf eine Rolle spielen.

### Hypothese 3: TaskFormSheet ist der primaere Creation-Flow (HOCH)

**Beschreibung:** Henning nutzt vermutlich TaskFormSheet als Haupt-Flow fuer Task-Erstellung, nicht CreateTaskView. TaskFormSheet hat KEINEN enrichTask()-Aufruf.

**Beweis DAFUER:**
- TaskFormSheet wird in BacklogView als Sheet praesentiert (der Haupt-Screen)
- CreateTaskView ist ein separater Full-Screen-Flow
- QuickCaptureView ist fuer schnelle Erfassung

**Beweis DAGEGEN:** Ohne Henning zu fragen, wissen wir nicht welchen Flow er nutzt.

**Wahrscheinlichkeit:** HOCH - TaskFormSheet als primaerer Flow erklaert warum "es nie funktioniert".

### Hypothese 4: UI zeigt enriched Werte nicht an (NIEDRIG)

**Beschreibung:** Enrichment laeuft eventuell, aber die UI aktualisiert sich nicht nach dem async enrichTask()-Aufruf.

**Beweis DAFUER:**
- enrichTask() ist async und lauft nach Task-Erstellung
- SwiftData @Query sollte auto-updaten, aber modelContext.save() Timing koennte ein Problem sein

**Beweis DAGEGEN:**
- SmartTaskEnrichmentService ruft modelContext.save() auf (Zeile 150)
- @Query-basierte Views sollten sich bei save() aktualisieren
- Batch-Enrichment aus Settings zeigt Ergebnis-Count an

**Wahrscheinlichkeit:** NIEDRIG

---

## Wahrscheinlichste Ursache

**Hypothese 1 + 3 zusammen:** TaskFormSheet (der vermutlich primaere iOS-Flow) und die macOS Quick-Capture-Paths rufen enrichTask() nicht auf. Das erklaert warum Henning sagt "funktioniert auf keiner Plattform".

Die weniger wahrscheinlichen Hypothesen (2, 4) wuerden nur dann relevant wenn sich herausstellt, dass Henning tatsaechlich CreateTaskView oder ContentView Quick-Add nutzt und es dort auch nicht funktioniert.

---

## Debugging-Plan

**Wenn meine Top-Hypothese RICHTIG ist:**
- enrichTask() wird in TaskFormSheet/QuickCaptureView/MenuBarView/QuickCapturePanel nie aufgerufen
- Fix: enrichTask()-Aufruf in alle fehlenden Paths einbauen
- Erwartetes Ergebnis: Tasks bekommen nach Erstellung automatisch Attribute

**Wenn meine Top-Hypothese FALSCH ist (Enrichment funktioniert auch in CreateTaskView nicht):**
- Logging in SmartTaskEnrichmentService einbauen (vor/nach Gates, vor/nach API-Call)
- Auf Geraet testen: Task ueber CreateTaskView anlegen, Konsole pruefen
- Wenn "isAvailable = false" → Device-Problem (nicht unser Code)
- Wenn "aiScoringEnabled = false" → Setting-Problem
- Wenn API-Fehler → Foundation Models Problem

---

## Blast Radius

### Direkt betroffen:
- Alle Task-Creation-Flows ohne enrichTask()-Aufruf (4 von 6)
- User sehen "TBD" statt auto-gefuellter Werte

### Indirekt betroffen:
- TaskPriorityScoringService (berechnet Score on-the-fly, funktioniert aber auch ohne enriched Attributes)
- Eisenhower-Matrix Sortierung (braucht importance + urgency, zeigt TBD-Tasks als unsortiert)

### Nicht betroffen:
- Task-Completion, Deletion, Editing
- Recurring Tasks, Sync, Focus Blocks
- Settings-Batch-Enrichment (funktioniert unabhaengig)

---

## Fix-Empfehlung (Vorschlag)

**Architektonisch bessere Loesung:** Enrichment in `LocalTaskSource.createTask()` einbauen statt in jeder View einzeln. Dann ist JEDER Creation-Path automatisch abgedeckt.

**Alternative:** enrichTask()-Aufruf in alle 4 fehlenden Views einzeln einbauen (schneller, aber fragiler).

**Plattform-Check:** Fix muss auf BEIDEN Plattformen wirken (iOS + macOS).
