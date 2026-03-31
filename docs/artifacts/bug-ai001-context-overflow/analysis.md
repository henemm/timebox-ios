# AI_001: Context-Window-Overflow — Analyse (v2, nach Challenge)

## Zusammenfassung

**Kern-Finding:** Der Context-Window-Overflow tritt auf wenn EINE `LanguageModelSession` fuer viele Multi-Turn-Aufrufe wiederverwendet wird. Die Session akkumuliert History (Prompt + Response pro Turn) bis das ~4.096-Token-Limit erreicht ist.

**Verifiziert:** Overflow nach exakt 29 erfolgreichen Aufrufen mit realistischen deutschen Task-Titeln + Guided Generation (`@generable` mit 2 Feldern).

**Betroffener Code:** Python Eval-Script + Swift Tests. Production-Code ist sicher.

## Agenten-Ergebnisse: Swift Production-Code

Alle 5 Agenten haben unabhaengig dasselbe gefunden:

**Der Swift-Production-Code erstellt bereits eine FRISCHE Session pro Task.**

| Service | Methode | Session-Pattern | Overflow-Risiko |
|---------|---------|-----------------|-----------------|
| SmartTaskEnrichmentService | `performEnrichment()` Z.250 | NEU pro Task | Kein Risiko |
| SmartTaskEnrichmentService | `enrichCategoryAndDuration()` Z.217 | NEU pro Task | Kein Risiko |
| TaskTitleEngine | `enrichWithSuggestions()` Z.412 | NEU pro Task | Kein Risiko |
| AITaskScoringService | `performScoring()` Z.109 | NEU pro Task | Kein Risiko |
| SuccessStoryService | `generateWithAI()` Z.61 | Einmal pro Tag | Kein Risiko |

## Laufzeit-Verifikation (nicht nur Code lesen!)

### Test 1: EINE Session, 30 kurze Prompts ("Test task N")
- Ergebnis: Alle 30 OK — kurze Prompts + kurze Responses passen ins Fenster

### Test 2: EINE Session, 30 realistische deutsche Prompts
- Ergebnis: **Overflow nach 29 erfolgreichen Aufrufen**
- Bestaetigt: Laengere Prompts + Guided Generation Responses fuellen Context schneller

### Test 3: FRISCHE Session pro Aufruf, 30 Prompts
- Ergebnis: Alle 30 OK — keine History-Akkumulation

## Wahrscheinlichste Ursache

**Multi-Turn-History-Akkumulation in wiederverwendeten Sessions.**

Jeder `session.respond()` Aufruf fuegt zur Session-History hinzu:
- User-Prompt (~20-40 Tokens pro realistischem Task)
- Model-Response (~50-80 Tokens fuer Guided Generation mit 2 Feldern)
- Pro Turn: ~60-120 Tokens

Bei ~4.096 Token Context Window und ~200 Tokens System Instructions:
- Verfuegbar fuer History: ~3.896 Tokens
- Pro Turn: ~90 Tokens (Durchschnitt)
- **Max Turns: ~43 (kurze Prompts) bzw. ~29 (realistische Prompts)**

## Blast Radius (korrigiert nach Challenge)

| Betroffener Code | Pattern | Status |
|------------------|---------|--------|
| `scripts/eval_prompts.py` — `eval_categorization()` | 1 Session fuer 30 Aufrufe | BETROFFEN |
| `scripts/eval_prompts.py` — `eval_duration()` | 1 Session fuer 16 Aufrufe | Potenziell betroffen (knapp unter Limit) |
| `scripts/eval_prompts.py` — `eval_enrichment()` | 1 Session fuer 8 Aufrufe | Sicher |
| `AITitleQualityTests.swift` — `test_categorization()` Z.382 | 1 Session fuer 30 Aufrufe | BETROFFEN |
| `AITitleQualityTests.swift` — `test_durationEstimation()` Z.490 | 1 Session fuer 20 Aufrufe | Potenziell betroffen |
| **Production-Code (alle 5 Services)** | Frische Session pro Task | SICHER |

## Empfohlene Massnahmen

1. **Python Eval-Script fixen:** Frische Session pro Task (oder Session nach 15 Aufrufen rotieren)
2. **Swift Tests fixen:** `test_categorization()` und `test_durationEstimation()` — Session pro Aufruf oder Session-Rotation
3. **Defense-in-Depth fuer Production:** `fetchRecentTaskContext()` Limit von 30 auf 10 reduzieren (spart ~400 Tokens pro Prompt, Risiko-Minimierung)
4. **Kein Production-Fix noetig:** Swift-Code ist bereits korrekt (frische Sessions)

## Offene Frage (vom Challenger)

> Teilen sich Python-Sessions State ueber das SystemLanguageModel? Koennten dur_session und enr_session zusammen akkumulieren?

Antwort: Nein — jede `LanguageModelSession` hat eigene History. Das haben wir in Test 3 verifiziert (30 frische Sessions = alle OK). Die Sessions teilen sich das Modell, nicht den State.
