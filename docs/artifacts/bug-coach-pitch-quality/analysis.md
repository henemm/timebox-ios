# Bug-Analyse: Coach AI-Pitches sinnfrei + abgeschnitten

## Symptom

Screenshot zeigt Coach-Auswahl-Screen mit 4 Karten. Die AI-generierten Pitches:
1. **Generisch** — Coaches reden ueber sich selbst statt User-Tasks zu nennen ("Dann waehl mich als Troll - Der Aufraeumer")
2. **Abgeschnitten** — alle 4 Texte enden mit "..." mitten im Wort/Satz

## Agenten-Ergebnisse (5 parallele Investigate-Tasks)

### Agent 1: Wiederholungs-Check
- **Gleicher Bug existierte bereits** bei EveningReflectionTextService — generische AI-Texte ohne Task-Bezug
- Dort gefixt mit `sortedByRelevance()` + `coachGuidance()` (Commit 6951115)
- **CoachPitchService hat diesen Fix NICHT uebernommen**
- TaskTitleEngine hat als EINZIGER Service eine Output-Validierung (`shouldAcceptImprovedTitle()`)

### Agent 2: Datenfluss-Trace
- Prompt wird korrekt gebaut mit Task-Namen (buildPrompt(), Zeile 36-53)
- AI generiert Text → trimmed → prefix(400) → in `aiPitches[coach]` gespeichert
- `Text(displayText)` hat **kein .lineLimit()** und kein frame(height:)
- Parent (CoachMeinTagView) hat ScrollView — **keine View-Constraints gefunden**
- Trotzdem werden Texte visuell abgeschnitten → entweder AI generiert zu langen Text der am Kartenrand endet, oder Plattform-spezifisches Rendering

### Agent 3: Alle Schreiber
- Zwei-Tier-System: AI-Pitch (max 400 chars) → Fallback: preview.teaser (max 57 chars + "...")
- `@Guide` Annotation ist die EINZIGE Constraint auf AI-Output
- Keine Validierung zwischen AI-Antwort und Anzeige

### Agent 4: Szenarien
- **Szenario 3 (Haupt-Bug):** AI generiert generischen Text ohne Task-Bezug → KEINE Validierung → wird angezeigt
- **Szenario 4:** AI ueberschreitet 300-Zeichen-Limit → prefix(400) schneidet mitten im Satz ab
- Alle Fallback-Szenarien (AI nicht verfuegbar, disabled, Exception) sind korrekt behandelt

### Agent 5: Blast Radius
- **5 AI-Services** im Codebase, **CoachPitchService hat die SCHWAECHSTE Validierung**
- TaskTitleEngine: Volle Validierung (shouldAcceptImprovedTitle)
- EveningReflectionTextService: AUCH keine Output-Validierung (gleicher Bug moeglich)
- SmartTaskEnrichmentService/AITaskScoringService: Typ/Range-Validierung (partial)

## Hypothesen

### Hypothese 1: AI ignoriert Task-Namen-Anweisung (HOCH)
**Beschreibung:** Foundation Models folgt der @Guide-Anweisung "bezieht sich auf konkrete Task-Titel" nicht und generiert stattdessen generischen Selbstdarstellungs-Text.

**Beweis DAFUER:**
- Alle 4 Pitches im Screenshot sind generisch, keiner nennt konkrete Tasks
- Bekanntes Problem: EveningReflectionTextService hatte identisches Problem
- @Guide ist nur ein Hint, nicht erzwungen — AI kann ihn ignorieren

**Beweis DAGEGEN:**
- Der Prompt ENTHAELT die Task-Namen korrekt (buildPrompt() Test ist gruen)
- @Guide sagt explizit "bezieht sich auf konkrete Task-Titel"

**Wahrscheinlichkeit:** HOCH

### Hypothese 2: Keine Output-Validierung = Muell wird durchgelassen (HOCH)
**Beschreibung:** Selbst wenn die AI schlechten Output liefert, gibt es keinen Quality Gate. Der Text wird direkt angezeigt.

**Beweis DAFUER:**
- Code: `return String(generated.prefix(400))` — keine Pruefung ob Tasks erwaehnt werden
- TaskTitleEngine zeigt dass Validierung MOEGLICH und NOETIG ist
- EveningReflectionTextService: gleiche Luecke

**Beweis DAGEGEN:**
- Keiner — das ist ein Fakt, keine Hypothese

**Wahrscheinlichkeit:** SICHER (strukturelles Problem)

### Hypothese 3: Text-Truncation durch View-Constraints (MITTEL)
**Beschreibung:** Obwohl kein expliziter lineLimit gefunden wurde, werden die Texte visuell abgeschnitten.

**Beweis DAFUER:**
- Screenshot zeigt "Ich s...", "wozu ich in der...", "Rolle als Eule...", "Lebens und m..." — alle mitten im Wort/Satz abgeschnitten
- Konsistent bei allen 4 Karten

**Beweis DAGEGEN:**
- Kein lineLimit() im Code gefunden
- Kein frame(height:) auf den Karten
- Parent ist ScrollView (sollte unbegrenzt scrollen)

**Wahrscheinlichkeit:** MITTEL — moeglicherweise impliziter SwiftUI-Constraint durch Button-Container oder Plattform-Rendering

### Hypothese 4: AI generiert zu langen Text (MITTEL)
**Beschreibung:** AI ignoriert "Max 300 Zeichen" und generiert 400+ Zeichen, prefix(400) schneidet mitten im Satz ab.

**Beweis DAFUER:**
- prefix(400) wuerde bei Ueberlange mitten im Wort schneiden — passt zum Screenshot
- On-device AI haelt sich bekanntermassen schlecht an Zeichenlimits

**Beweis DAGEGEN:**
- prefix(400) fuegt kein "..." hinzu — das wuerde einfach abgeschnitten, ohne Ellipsis
- SwiftUI-Truncation fuegt "..." hinzu — deutet auf View-Constraint hin

**Wahrscheinlichkeit:** MITTEL

## Wahrscheinlichste Ursachenkombination

**Hauptproblem (Bug 1): AI-Pitches sind generisch**
- Root Cause: Keine Output-Validierung + schwacher @Guide
- AI bekommt Task-Namen im Prompt, ignoriert sie, generiert generischen Text
- Kein Quality Gate fängt das ab → Text wird direkt angezeigt
- **Bewiesenes Muster:** Identischer Bug bei EveningReflectionTextService, dort bereits gefixt

**Nebenproblem (Bug 2): Text wird abgeschnitten**
- Root Cause: Unklar — moeglicherweise SwiftUI-Button-Label-Truncation oder impliziter Container-Constraint
- Benoetigt Debugging auf echtem Geraet

## Debugging-Plan (falls gewuenscht)

### Fuer Bug 1 (generische Pitches):
- Log die AI-Antwort vor prefix(400): `print("[CoachPitch] Raw: \(generated)")`
- Log den Prompt: `print("[CoachPitch] Prompt: \(userPrompt)")`
- Pruefen ob Task-Namen im Prompt sind (sollten) und ob sie im Output fehlen (wahrscheinlich)

### Fuer Bug 2 (Truncation):
- Temporaer `.lineLimit(nil)` explizit auf Text(displayText) setzen
- Pruefen ob Button-Label den Text constrainted

## Fix-Empfehlung

### Fix 1: Output-Validierung (Hauptfix)
In `performGeneration()` nach AI-Antwort pruefen:
- Mindestens 1 Task-Name muss im generierten Text vorkommen (wenn Tasks vorhanden)
- Wenn nicht: AI-Antwort verwerfen, nil zurueckgeben → Fallback auf deterministischen Teaser
- Analog zu TaskTitleEngine.shouldAcceptImprovedTitle()

### Fix 2: Prompt verbessern
- @Guide staerker formulieren: "MUSS mindestens einen konkreten Task-Titel enthalten"
- System-Prompt expliziter: Task-Namen als PFLICHT, nicht "wenn vorhanden"

### Fix 3: Text-Truncation beheben
- `.lineLimit(nil)` explizit setzen auf Text(displayText)
- Alternativ: prefix(400) durch intelligentes Satz-Ende ersetzen

## Blast Radius
- **EveningReflectionTextService** hat potenziell gleichen Bug (keine Output-Validierung)
- Fix-Pattern (Output-Validierung) sollte auf BEIDE Services angewandt werden
- Andere AI-Services (SmartEnrichment, AIScoring) haben zumindest Typ-Validierung

## Challenge-Bereitschaft
Diese Analyse ist bereit fuer den Devil's Advocate Challenge.
