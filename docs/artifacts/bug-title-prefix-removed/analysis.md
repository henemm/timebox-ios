# Bug-Analyse: Task-Titel Prefix wird entfernt

## Symptom
Task-Titel "Lohnsteuererklarung: Rechnungsuebersicht erstellen" wird nach Erstellung zu "Rechnungsuebersicht erstellen" — der Prefix "Lohnsteuererklaerung: " verschwindet.

**Plattform:** iOS, Backlog Plus-Button

## Agenten-Ergebnisse (5 parallele Investigationen)

### Agent 1: Wiederholungs-Check
- TaskTitleEngine hat Geschichte: CTC-1 (erste Version), CTC-1b (konservativ), Bug-Fix fuer "(dringend)" Keywords
- `stripKeywords()` entfernt NUR Urgency-Keywords (dringend, urgent, asap, sofort, eilig)
- `performImprovement()` nutzt Apple Intelligence (Foundation Models) fuer AI-basierte Titelbereinigung
- AI-Bereinigung wurde bewusst eingebaut um Floskeln, E-Mail-Artefakte etc. zu entfernen

### Agent 2: Datenfluss-Trace
- Kompletter Flow: TextField → TaskFormSheet.saveTask() → LocalTaskSource.createTask()
- Zeile 102: `stripKeywords()` — KEIN Match fuer "Lohnsteuererklaerung:" (nur Urgency-Keywords)
- Zeile 121: Erster save() — Titel noch korrekt im SwiftData
- Zeile 125: `enrichTask()` — aendert Titel NICHT (nur Attribute wie importance, urgency)
- **Zeile 128-130: `needsTitleImprovement = true` → `improveTitleIfNeeded()` → AI ueberschreibt Titel**
- Zeile 189: `task.title = String(improved.prefix(200))` — AI-Ergebnis ersetzt Original

### Agent 3: Alle Schreiber
- 13 Stellen im Code schreiben/transformieren den Titel
- NUR `TaskTitleEngine.performImprovement()` (Zeile 189) transformiert den Titel via AI
- `stripKeywords()` hat nur 1 Call-Site: `LocalTaskSource.createTask()` Zeile 102
- SmartTaskEnrichmentService liest Titel, schreibt ihn aber NICHT

### Agent 4: Szenarien
- 7 Szenarien untersucht, 5 ausgeschlossen (Input-Validierung, Category-Extraction, Clipboard, Model-didSet, CloudKit)
- `stripKeywords()` ausgeschlossen (regex matched nicht)
- **AI Title Improvement: 85-90% Wahrscheinlichkeit** — AI interpretiert "Lohnsteuererklaerung:" als Kategorie-Prefix (wie "Re:", "Fwd:")

### Agent 5: Blast Radius
- iOS Plus-Button: BETROFFEN (via LocalTaskSource.createTask)
- macOS Plus-Button: BETROFFEN (via LocalTaskSource.createTask)
- Share Extension, Watch, Siri, Import: NICHT betroffen (kein stripKeywords/createTask)
- Bestehende Titel: SICHER (kein Reprocessing)

## Hypothesen

### Hypothese 1: AI Title Improvement interpretiert Doppelpunkt als Prefix/Kategorie (HOCH — 90%)

**Mechanismus:**
1. `LocalTaskSource.createTask()` setzt `needsTitleImprovement = true` (Zeile 128)
2. `improveTitleIfNeeded()` wird sofort aufgerufen (Zeile 130)
3. AI bekommt Prompt: "Bereinige diesen Task-Titel: Lohnsteuererklaerung: Rechnungsuebersicht erstellen"
4. AI-Instruktionen sagen "Entferne E-Mail-Artefakte (Re:, Fwd:, AW:, WG:)" und "Titel soll die AKTION beschreiben"
5. AI generalisiert: "Lohnsteuererklaerung:" sieht aus wie ein Prefix/Label — wird entfernt
6. AI gibt nur "Rechnungsuebersicht erstellen" zurueck
7. Zeile 189: `task.title = String(improved.prefix(200))` — Original wird ueberschrieben

**Beweis DAFUER:**
- `@Guide` sagt: "Remove email artifacts (Re:, Fwd:, AW:, WG:)" — AI generalisiert auf alle "Prefix:" Patterns
- `@Guide` sagt: "The title should describe the ACTION" — AI sieht "Rechnungsuebersicht erstellen" als die Aktion
- `@Guide` sagt: "Start with verb in infinitive form" — "erstellen" ist Infinitiv, passt
- System-Prompt: "Nur kuerzen durch Weglassen" — AI laesst "Lohnsteuererklaerung:" weg
- Kein explizites Verbot fuer Doppelpunkt-Prefixe in den Instructions

**Beweis DAGEGEN:**
- `@Guide` sagt auch "Keep ALL original words" — aber "Lohnsteuererklaerung" ist ein Original-Wort
- AI sollte eigentlich konservativ sein — aber Apple Intelligence ist nicht deterministisch

**Wahrscheinlichkeit: HOCH (90%)**

### Hypothese 2: stripKeywords() hat eine Regex die zu breit matched (NIEDRIG — 5%)

**Mechanismus:** Regex `^(?:dringend|urgent|asap|sofort|eilig)\s*:\s*` koennte durch Encoding-Probleme oder Unicode-Normalisierung breiter matchen.

**Beweis DAGEGEN:**
- Regex ist explizit auf 5 Keywords beschraenkt
- "Lohnsteuererklaerung" ist keins davon
- Agent 4 hat Regex verifiziert: KEIN Match

**Wahrscheinlichkeit: NIEDRIG (5%)**

### Hypothese 3: SmartTaskEnrichmentService modifiziert den Titel doch (SEHR NIEDRIG — 3%)

**Mechanismus:** enrichTask() koennte doch den Titel schreiben, nicht nur Attribute.

**Beweis DAGEGEN:**
- Agent 3 hat ALLE Schreibstellen gefunden — SmartTaskEnrichmentService ist nicht dabei
- enrichTask() Output-Struct hat NUR: importance, urgency, taskType, energyLevel — KEIN title-Feld
- Code verifiziert: Kein `.title =` in SmartTaskEnrichmentService

**Wahrscheinlichkeit: SEHR NIEDRIG (3%)**

## Wahrscheinlichste Ursache

**Hypothese 1: AI Title Improvement** (`TaskTitleEngine.performImprovement()`, Zeile 160-202)

Apple Intelligence interpretiert "Lohnsteuererklaerung:" als entfernbares Prefix (aehnlich "Re:", "Fwd:") und gibt nur den Action-Teil zurueck. Der Code uebernimmt das AI-Ergebnis blind.

Die Instruktionen in `@Guide` und System-Prompt sind widerspruchlich:
- "Keep ALL original words" vs. "Title should describe the ACTION"
- "Remove email artifacts" impliziert Prefix-Entfernung, ohne Scope-Begrenzung
- Kein explizites "NEVER entferne Text vor Doppelpunkten ausser bekannte E-Mail-Artefakte"

## Debugging-Plan (Beweis)

### Bestaetigung:
- Logging in `performImprovement()` NACH Zeile 186: `print("[TaskTitleEngine] Input: '\(task.title)' → Output: '\(improved)'")`
- Wenn Output = "Rechnungsuebersicht erstellen" → Hypothese 1 bestaetigt

### Widerlegung:
- Wenn Output = "Lohnsteuererklaerung: Rechnungsuebersicht erstellen" → AI ist nicht schuld, weiter suchen
- Plattform: iOS (Henning hat auf iOS berichtet)

## Blast Radius

| Entry Point | Betroffen? | Grund |
|------------|-----------|-------|
| iOS Plus-Button | JA | LocalTaskSource.createTask() → AI |
| macOS Plus-Button | JA | Gleicher Code-Pfad |
| Share Extension | JA | needsTitleImprovement=true → AI |
| Watch Voice | JA | needsTitleImprovement=true → AI |
| Siri/Shortcuts | NEIN | Kein createTask() |
| Reminders Import | NEIN | Kein AI-Flag |

**JEDER Titel mit Doppelpunkt ist potenziell betroffen:** "Meeting: Vorbereitung", "Projekt: Aufgabe", "TODO: Einkaufen" etc.
