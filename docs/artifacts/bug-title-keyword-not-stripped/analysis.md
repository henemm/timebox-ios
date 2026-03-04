# Bug: Titel-Keyword wird nicht entfernt

## Symptom
Task angelegt mit "Flüge für Retreat buchen (dringend)":
- Priorität auf "Dringend" gesetzt: **JA** (korrekt)
- "(dringend)" aus Titel entfernt: **NEIN** (Bug)

Plattform: Beide (iOS + macOS)

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- **Kein vorheriger Bug** zu diesem Thema gefunden
- CTC-1b (TaskTitleEngine) wurde implementiert mit expliziter Anweisung "Entferne Dringlichkeits-Hinweise"
- CTC-6 erweiterte Floskel-Erkennung
- Alle 16 Unit Tests waren GREEN

### Agent 2: Datenfluss-Trace
**Kritischer Fund:** Der Datenfluss hat eine Architektur-Lücke:
1. User gibt Titel ein → `LocalTaskSource.createTask()` speichert **sofort** mit RAW Titel
2. `SmartTaskEnrichmentService.enrichTask()` → setzt `urgency = "urgent"` (synchron, sofort)
3. `needsTitleImprovement = true` wird gesetzt
4. **TaskTitleEngine läuft NUR bei App-Start** (`FocusBloxApp.swift` Zeile 241-242)
5. Titel-Bereinigung passiert NICHT nach Task-Erstellung, sondern erst beim NÄCHSTEN App-Start

### Agent 3: Alle Schreiber
- 8 Entry Points erstellen Tasks mit RAW Titel (keine Bereinigung)
- Einzige Bereinigung: `TaskTitleEngine.performImprovement()` (Zeile 165) — asynchron, AI-abhängig
- Kein deterministisches Keyword-Stripping existiert

### Agent 4: Alle Szenarien
- ALLE 8 Entry Points betroffen (CreateTaskView, QuickCapture, MenuBar, Watch, Siri, Share Extension, Reminders Import)
- Share Extension und Reminders Import setzen teilweise nicht mal `needsTitleImprovement`

### Agent 5: Blast Radius
- ALLE Keyword-Typen betroffen (nicht nur Urgency): Floskeln, E-Mail-Artefakte, Zeitangaben
- Gesamte Titel-Bereinigung hängt an AI (TaskTitleEngine), kein Fallback

## Hypothesen

### Hypothese 1: TaskTitleEngine wird nie nach Task-Erstellung aufgerufen (HÖCHSTE Wahrscheinlichkeit)
**Beschreibung:** `TaskTitleEngine.improveAllPendingTitles()` wird nur in `FocusBloxApp.swift` beim App-Start aufgerufen. Nach `createTask()` wird `improveTitleIfNeeded()` NICHT aufgerufen. Der Titel bleibt also unbereinigt bis zum nächsten App-Start.

**Beweis DAFÜR:**
- `LocalTaskSource.createTask()` (Zeile 87-137): Kein Aufruf von TaskTitleEngine
- `FocusBloxApp.swift` (Zeile 241-242): Einziger Aufruf von `improveAllPendingTitles()`
- Grep nach `improveTitleIfNeeded` zeigt nur internen Aufruf in `improveAllPendingTitles()`

**Beweis DAGEGEN:**
- Keiner. Der Code ist eindeutig.

**Wahrscheinlichkeit:** HOCH (95%)

### Hypothese 2: AI (Apple Intelligence) entfernt Klammer-Keywords nicht zuverlässig
**Beschreibung:** Selbst wenn TaskTitleEngine läuft, könnte die AI das Format "(dringend)" mit Klammern nicht als Urgency-Keyword erkennen und im Titel belassen.

**Beweis DAFÜR:**
- AI-Prompt sagt "Entferne Dringlichkeits-Hinweise (dringend, ASAP, sofort)" — aber kein explizites Beispiel mit Klammern
- @Guide Description erwähnt Klammer-Format nicht
- AI-Verhalten ist nicht deterministisch

**Beweis DAGEGEN:**
- Das Wort "dringend" steht explizit in der Entfernungsliste
- AI sollte Klammern als syntaktische Wrapper erkennen

**Wahrscheinlichkeit:** MITTEL (40% — könnte zusätzlich zur Hauptursache bestehen)

### Hypothese 3: SmartTaskEnrichmentService setzt urgency, aber TaskTitleEngine prüft `urgency == nil`
**Beschreibung:** `TaskTitleEngine` (Zeile 170) setzt urgency nur wenn `task.urgency == nil`. Da `SmartTaskEnrichmentService` urgency bereits gesetzt hat, überspringt TaskTitleEngine die Urgency-Zuweisung. Das Titel-Stripping ist davon aber NICHT betroffen (Zeile 164-166 setzt den Titel unabhängig von urgency).

**Beweis DAGEGEN:**
- Die Titel-Bereinigung (Zeile 162-166) ist unabhängig von der urgency-Zuweisung
- Beide sind separate Code-Blöcke

**Wahrscheinlichkeit:** NIEDRIG (5%)

## Wahrscheinlichste Ursache

**Hypothese 1 ist die Hauptursache:** TaskTitleEngine wird nach Task-Erstellung nicht aufgerufen. Der Titel bleibt unbereinigt.

**Hypothese 2 könnte zusätzlich zutreffen:** Selbst wenn TaskTitleEngine läuft, ist die AI-basierte Bereinigung nicht deterministisch und könnte Klammer-Keywords verpassen.

## Debugging-Plan

### Bestätigung Hypothese 1:
- `print("[TaskTitleEngine] improveAllPendingTitles called")` in `improveAllPendingTitles()` — sollte nur beim App-Start erscheinen, NICHT nach Task-Erstellung

### Widerlegung Hypothese 1:
- Wenn der Log auch nach Task-Erstellung erscheint, ist Hypothese 1 falsch

### Bestätigung Hypothese 2:
- Task mit `needsTitleImprovement = true` manuell erstellen, App neu starten, prüfen ob Titel bereinigt wird

## Fix-Empfehlung

**Deterministisches Keyword-Stripping in `LocalTaskSource.createTask()`:**

Statt sich ausschließlich auf die asynchrone AI-Bereinigung zu verlassen, ein einfaches, synchrones Regex-basiertes Stripping einbauen:
- Urgency-Keywords: `(dringend)`, `(urgent)`, `(ASAP)`, `(sofort)`, `dringend:`, etc.
- Direkt in `createTask()` VOR dem Save
- Deterministisch, sofort, kein AI nötig
- TaskTitleEngine bleibt für komplexere Bereinigung (Floskeln, E-Mail-Artefakte)

**Zusätzlich:** `improveTitleIfNeeded()` direkt nach `createTask()` aufrufen (für die erweiterte AI-Bereinigung).

## Blast Radius

- **Direkt betroffen:** Alle 8 Task-Erstellungs-Entry-Points (iOS + macOS)
- **Indirekt:** Floskeln und Zeitangaben werden ebenfalls nicht sofort bereinigt
- **Risiko des Fixes:** Gering — deterministisches Stripping für klar definierte Keywords ist sicher
- **Gleicher Code:** `LocalTaskSource.createTask()` ist der zentrale Entry Point für ALLE Plattformen
