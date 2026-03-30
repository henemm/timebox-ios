# BUG_124 — Datums-Keywords bleiben im Task-Titel stehen

## Symptom

Wenn ein Task via Quick Capture mit Datums-Keywords erstellt wird (z.B. "Heute dringend Klingel demontieren"), wird das Datum korrekt erkannt und als Fälligkeitsdatum gesetzt, aber das Keyword bleibt im Titel stehen. Erwartet: "Dringend Klingel demontieren" (oder besser: "Klingel demontieren" wenn auch "dringend" als Urgency erkannt wird).

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- **Bug 97** (Commit cbe4c4f): Shortcut erkannte Datum-Keywords nicht → Fix: `extractDeterministicDueDate()` hinzugefügt. Keywords werden aber NICHT aus Titel entfernt.
- **Commit 747748f**: Urgency-Keywords ("dringend", "urgent") werden aus Titeln entfernt → `stripKeywords()` eingeführt. Nur Urgency, KEINE Datums-Keywords.
- **Commit bc622de**: CTC-1b TaskTitleEngine Grundlagen. `titleContainsDateKeyword()` und `relativeDateFrom()` eingeführt. Kein Keyword-Stripping für Datums-Keywords.
- **Fazit:** Datums-Keywords wurden NIE aus Titeln entfernt — das Feature fehlt komplett in `stripKeywords()`.

### Agent 2: Datenfluss-Trace
- QuickCaptureView → `LocalTaskSource.createTask(title:)` → `TaskTitleEngine.stripKeywords(title)` (Zeile 104) → `LocalTask(title: cleanedTitle)` (Zeile 107)
- `stripKeywords()` entfernt nur Urgency-Keywords, nicht Datums-Keywords
- Danach: `improveTitleIfNeeded()` → `cleanTitle()` → `stripKeywords()` nochmals — immer noch ohne Datums-Keywords
- **Kernproblem:** Der bereinigte Titel enthält weiterhin "Heute" weil `stripKeywords()` keine Datums-Regex hat

### Agent 3: Alle Schreiber
- **Mit stripKeywords:** `LocalTaskSource.createTask()` (Zeile 104), `TaskTitleEngine.cleanTitle()` (Zeile 81)
- **Ohne stripKeywords:** `CreateTaskIntent.perform()` (Zeile 18), macOS Share Extension (Zeile 159), Watch VoiceInputSheet (Zeile 45), `LocalTaskSource.updateTask()` (Zeile 166)

### Agent 4: Alle Szenarien
- Datums-Keywords (heute, morgen, übermorgen, Wochentage, nächste woche) werden ERKANNT (`titleContainsDateKeyword`) aber NIE ENTFERNT
- Substring-Problem: `lower.contains("morgen")` matcht auch "Morgengymnastik"
- Alle Positionen (Anfang, Mitte, Ende), Klammern, Prefix-Format — nirgends werden Datums-Keywords entfernt

### Agent 5: Blast Radius
- **Primär betroffen:** iOS Quick Capture, macOS Task Create Sheet, Siri/Shortcuts, Share Extensions
- **Sekundär:** Update-Pfade umgehen stripKeywords komplett
- Urgency-Keywords funktionieren korrekt — nur Datums-Keywords fehlen
- SmartTaskEnrichmentService nutzt `task.title` als AI-Input — Keywords dort beeinflussen AI-Vorschläge

## Hypothesen

### Hypothese 1: `stripKeywords()` fehlt Datums-Keyword-Regex (HOCH)
- **Beschreibung:** `stripKeywords()` hat nur Regex für Urgency-Keywords (dringend, urgent, asap, sofort, eilig), aber KEINE für Datums-Keywords (heute, morgen, übermorgen, Wochentage)
- **Beweis DAFÜR:** Code in TaskTitleEngine.swift:30-48 zeigt nur Urgency-Regex. `titleContainsDateKeyword()` (Zeile 97-107) erkennt Datums-Keywords, aber `stripKeywords()` nutzt diese Liste nicht.
- **Beweis DAGEGEN:** Keiner. Der Code ist eindeutig.
- **Wahrscheinlichkeit:** HOCH (95%)

### Hypothese 2: `extractDeterministicDueDate()` extrahiert Datum, entfernt aber nicht aus Titel (HOCH)
- **Beschreibung:** Die Funktion gibt nur ein `Date?` zurück, modifiziert aber nicht den Titel. Es gibt keine "strip and return cleaned title" Variante.
- **Beweis DAFÜR:** Signatur `nonisolated static func extractDeterministicDueDate(from title: String) -> Date?` — nur Date-Rückgabe.
- **Beweis DAGEGEN:** Keiner.
- **Wahrscheinlichkeit:** HOCH (95%) — ergänzt Hypothese 1

### Hypothese 3: AI-basierte Titel-Verbesserung sollte Keywords entfernen, tut es aber nicht zuverlässig (MITTEL)
- **Beschreibung:** `improveTitleIfNeeded()` nutzt AI (FoundationModels) für Titel-Verbesserung. Möglicherweise war der Plan, dass die AI die Keywords entfernt.
- **Beweis DAFÜR:** `task.needsTitleImprovement = true` wird gesetzt, AI-Prompt könnte Keywords entfernen
- **Beweis DAGEGEN:** AI ist nicht auf allen Geräten verfügbar (`isAvailable` check), deterministisches Stripping wäre zuverlässiger
- **Wahrscheinlichkeit:** MITTEL — erklärt warum das Feature nie deterministisch implementiert wurde

### Hypothese 4: Substring-Match verursacht False Positives bei Keyword-Erkennung (NIEDRIG)
- **Beschreibung:** `lower.contains("morgen")` matcht auch "Morgengymnastik", "Morgenstund"
- **Beweis DAFÜR:** Kein Word-Boundary-Check in `titleContainsDateKeyword()` und `extractDeterministicDueDate()`
- **Beweis DAGEGEN:** Betrifft nur Edge Cases, nicht das Hauptproblem
- **Wahrscheinlichkeit:** NIEDRIG für BUG_124, aber relevant für die Lösung

## Wahrscheinlichste Ursache

**Hypothese 1 + 2 zusammen:** `stripKeywords()` wurde nur für Urgency-Keywords implementiert. Als Datums-Erkennung hinzugefügt wurde (Bug 95/97), wurde nur die Extraktion (`extractDeterministicDueDate`) implementiert, aber das Entfernen aus dem Titel vergessen.

Die anderen Hypothesen sind weniger wahrscheinlich weil:
- H3: AI-Verbesserung ist optional und nicht auf allen Geräten verfügbar
- H4: Betrifft Edge Cases, nicht das Hauptsymptom

## Debugging-Plan

**Logging das die Hypothese BESTÄTIGT:**
- Logger in `stripKeywords()` vor und nach Regex-Anwendung → Output zeigt dass Datums-Keywords nicht matchen
- Logger in `LocalTaskSource.createTask()` nach Zeile 104 → `cleanedTitle` enthält weiterhin "Heute"

**Logging das die Hypothese WIDERLEGT:**
- Wenn `cleanedTitle` nach `stripKeywords()` kein "Heute" mehr enthält → Problem liegt woanders (z.B. Title wird später überschrieben)

**Plattform:** Beide (iOS + macOS) — selber Code-Pfad über `LocalTaskSource`

## Challenge-Ergebnisse (Devil's Advocate)

**Verdict: LÜCKEN** — Root Cause korrekt, aber offene Design-Fragen:

### Eingearbeitete Lücken:

1. **Reihenfolge in createTask():** `enrichTask()` läuft ZUERST (Zeile 129), `improveTitleIfNeeded()` DANACH (Zeile 137). AI-Enrichment sieht Titel MIT Keyword — beeinflusst Vorschläge, aber kein funktionaler Bug.

2. **Word-Boundary-Problem:** `lower.contains("morgen")` matcht "Morgengymnastik". Fix MUSS Word-Boundary-Regex (`\b`) nutzen statt `contains()`, sonst werden Wortteile fälschlich entfernt.

3. **Semantischer Informationsverlust:** "Freitag Meeting buchen" → nach Strip: "Meeting buchen". Das Keyword ist hier semantisch relevant. **Entscheidung:** Akzeptabler Trade-off — das Datum wird als Badge angezeigt, der Kontext bleibt erhalten. Urgency-Keywords haben dasselbe Verhalten.

4. **taskDescription persistiert Original:** `improveTitleIfNeeded()` sichert den Titel in `taskDescription` BEVOR er bereinigt wird. Keywords bleiben dort sichtbar — das ist erwünscht als Backup/Original.

5. **Deferred Pfade (Intent, Share, Watch):** Alle setzen `needsTitleImprovement = true` → werden beim nächsten App-Start via `improveTitleIfNeeded()` bereinigt. Nicht sofort, aber korrekt im Pfad. Fix in `stripKeywords()` deckt ALLE Pfade ab.

## Blast Radius

### Direkt betroffen:
1. iOS Quick Capture — Datums-Keywords im Titel (sofort sichtbar)
2. macOS Task Create — Datums-Keywords im Titel (sofort sichtbar)
3. Siri/Shortcuts (CreateTaskIntent) — Keywords im Titel (verzögert bereinigt via needsTitleImprovement)
4. Share Extensions (iOS + macOS) — Keywords im Titel (verzögert bereinigt via needsTitleImprovement)
5. Watch VoiceInputSheet — Keywords im Titel (verzögert bereinigt via needsTitleImprovement)

### Indirekt betroffen:
6. SmartTaskEnrichmentService — AI sieht Keywords im Titel (enrichTask läuft VOR improveTitleIfNeeded)
7. Spotlight-Index — Keywords im indexierten Titel

### Ähnliche Patterns:
- Urgency-Keywords: KORREKT entfernt (Commit 747748f)
- Category/Duration-Keywords: Nicht implementiert (kein Bug, nie geplant)

### Design-Entscheidung für Fix:
- Word-Boundary-Regex statt `contains()` → verhindert False Positives ("Morgengymnastik")
- Nur standalone Keywords entfernen, nicht als Wortteile
- `extractDeterministicDueDate()` MUSS dieselbe Keyword-Liste nutzen wie `stripKeywords()` → DRY
