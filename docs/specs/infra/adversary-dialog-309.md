---
entity_id: adversary-dialog-309
type: infrastructure
created: 2026-05-10
updated: 2026-05-10
status: draft
version: "1.0"
tags: [hooks, adversary, qa, dialog, fresh-eyes]
---

# Feature #309: Adversary-Dialog strukturieren + Fresh-Eyes-Agent

## Approval

- [ ] Approved

## Purpose

Gibt dem Adversary-Prozess eine klare, reproduzierbare Struktur: ein Python-Helfer-Skript extrahiert pruefbare Punkte aus der Spec und validiert das Dialog-Artifact anschliessend; ein neuer Agent-Prompt bewertet Screenshots ohne jeglichen Feature-Kontext. Ohne diese Struktur hing die Pruefqualitaet allein am jeweiligen Prompttext — Verdicts konnten fehlen oder Runden konnten uebersprungen werden.

## Source

| Datei | Typ | Beschreibung |
|-------|-----|-------------|
| `.claude/hooks/adversary_dialog.py` | CREATE | Python-Helfer: Spec-Parser, Checklisten-Generator, Artifact-Validator (~120 LoC) |
| `.claude/commands/adversary.md` | MODIFY | Strukturierter Adversary-Prompt: Checklisten-Pflicht, Rundenformat, Tri-State-Verdict |
| `.claude/agents/fresh-eyes-inspector.md` | CREATE | Agent-Prompt fuer unabhaengigen Screenshot-Beobachter (~30 LoC Markdown) |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `docs/specs/_template.md` | template | Definiert den `## Expected Behavior`-Abschnitt den adversary_dialog.py parst |
| `.claude/agents/implementation-validator.md` | agent | Orchestriert weiterhin den eigentlichen Adversary-Dialog; adversary_dialog.py ist nur Helfer |
| `.claude/commands/adversary.md` (aktuell) | command | Wird ueberarbeitet, nicht ersetzt — Basis bleibt erhalten |

## Implementation Details

### adversary_dialog.py — drei Modi

**Modus A: `generate-checklist <spec-pfad>`**

```
python3 .claude/hooks/adversary_dialog.py generate-checklist <spec-pfad>
```

1. Datei lesen; wenn Datei fehlt → stderr "Spec nicht gefunden: <pfad>", Exit 1
2. Abschnitt `## Expected Behavior` suchen; wenn nicht vorhanden → stderr "Kein Expected-Behavior-Abschnitt gefunden", Exit 1
3. Alle Zeilen extrahieren die mit `-` beginnen (innerhalb dieses Abschnitts, bis zum naechsten `##`)
4. Wenn keine Punkte gefunden → stderr "Keine Bullet-Punkte im Expected-Behavior-Abschnitt", Exit 1
5. Ausgabe auf stdout:
   ```
   ## Adversary-Checkliste
   - [ ] Punkt 1: <Text>
   - [ ] Punkt 2: <Text>
   ```
6. Exit 0 bei Erfolg

**Modus B: `validate-artifact <artifact-pfad> <spec-pfad>`**

```
python3 .claude/hooks/adversary_dialog.py validate-artifact <artifact-pfad> <spec-pfad>
```

1. Spec lesen und Expected-Behavior-Punkte extrahieren (wie Modus A)
2. Artifact-Datei lesen; wenn fehlt → stderr + Exit 1
3. Pruefen: enthaelt das Artifact `### Runde 1` UND `### Runde 2`?
   - Nein → Bericht: "FEHLER: Weniger als 2 Runden dokumentiert", Exit 1
4. Pruefen: enthaelt das Artifact eines von `**VERIFIED**`, `**BROKEN**`, `**AMBIGUOUS**`?
   - Nein → Bericht: "FEHLER: Kein Verdict gefunden (erwartet: **VERIFIED** / **BROKEN** / **AMBIGUOUS**)", Exit 1
5. Validierungsbericht auf stdout, Exit 0 wenn alle Pruefungen bestanden

**Modus C: `--help`**

Gibt Nutzungshinweise aus (alle Modi + Beispiel-Aufrufe), Exit 0.

### adversary.md — Aenderungen

- Schritt 2 (Checkliste erstellen) ruft explizit auf:
  ```
  python3 .claude/hooks/adversary_dialog.py generate-checklist <spec-pfad>
  ```
- Dialog-Format wird vorgeschrieben: mindestens `### Runde 1` und `### Runde 2`
- Verdict-Format wird vorgeschrieben: `**VERDICT: VERIFIED**` / `**VERDICT: BROKEN**` / `**VERDICT: AMBIGUOUS**`
- Artifact-Validierung am Ende der Pruefung:
  ```
  python3 .claude/hooks/adversary_dialog.py validate-artifact <artifact-pfad> <spec-pfad>
  ```

### fresh-eyes-inspector.md — Agent-Prompt

- Agent bekommt ausschliesslich Screenshots — keine Spec, keine Feature-Beschreibung, kein Workflow-Kontext
- Drei feste Bewertungsfragen:
  1. Wirkt die UI konsistent (Abstände, Schriftgroessen, Farben)?
  2. Gibt es sichtbare Fehler oder Anomalien (abgeschnittener Text, fehlende Elemente)?
  3. Entspricht das dem Standard einer professionellen iOS-App?
- Ausgabe: 3-5 Saetze in Hennings Sprache (kein Fachjargon), keine Spec-Referenzen

## Expected Behavior

- `generate-checklist` mit gueltigem Spec-Pfad gibt eine Markdown-Checkliste aus (eine Zeile pro Bullet-Punkt aus `## Expected Behavior`)
- `generate-checklist` mit fehlendem `## Expected Behavior`-Abschnitt schlaegt fehl (Exit 1) statt eine leere Checkliste auszugeben
- `generate-checklist` mit nicht existierender Datei schlaegt fehl (Exit 1) mit erklaerungsreichem Fehlertext
- `validate-artifact` mit einem Artifact das 2+ Runden und ein Verdict enthaelt gibt Exit 0 zurueck
- `validate-artifact` mit einem Artifact das kein Verdict enthaelt gibt Exit 1 zurueck mit Fehlermeldung "Kein Verdict gefunden"
- `validate-artifact` mit einem Artifact das nur 1 Runde enthaelt gibt Exit 1 zurueck mit Fehlermeldung "Weniger als 2 Runden"
- `fresh-eyes-inspector.md` bewertet ausschliesslich das Visuelle — der Agent fragt nicht nach Spec oder Kontext
- `adversary.md` schreibt nach der Validierung `python3 .claude/hooks/adversary_dialog.py validate-artifact` vor; schlaegt das Skript fehl, darf kein Verdict gesetzt werden

## Acceptance Criteria

**AC-1** — generate-checklist Erfolgsfall
Given eine Spec-Datei mit einem `## Expected Behavior`-Abschnitt der mindestens einen Bullet-Punkt enthaelt,
When `adversary_dialog.py generate-checklist <pfad>` ausgefuehrt wird,
Then gibt das Skript eine Markdown-Checkliste mit `- [ ] Punkt N: <Text>` fuer jeden Bullet-Punkt aus und beendet mit Exit 0.

**AC-2** — fehlender Expected-Behavior-Abschnitt
Given eine Spec-Datei die keinen `## Expected Behavior`-Abschnitt enthaelt,
When `adversary_dialog.py generate-checklist <pfad>` ausgefuehrt wird,
Then gibt das Skript einen erklaerenden Fehlertext auf stderr aus und beendet mit Exit 1 (keine leere Checkliste).

**AC-3** — validate-artifact: valide Runden
Given ein Dialog-Artifact mit `### Runde 1`, `### Runde 2` und `**VERIFIED**`,
When `adversary_dialog.py validate-artifact <artifact> <spec>` ausgefuehrt wird,
Then gibt das Skript einen Validierungsbericht aus und beendet mit Exit 0.

**AC-4** — validate-artifact: fehlendes Verdict
Given ein Dialog-Artifact das `### Runde 1` und `### Runde 2` enthaelt, aber keines von `**VERIFIED**`, `**BROKEN**`, `**AMBIGUOUS**`,
When `adversary_dialog.py validate-artifact <artifact> <spec>` ausgefuehrt wird,
Then gibt das Skript "Kein Verdict gefunden" auf stderr aus und beendet mit Exit 1.

**AC-5** — validate-artifact: zu wenige Runden
Given ein Dialog-Artifact das nur `### Runde 1` enthaelt (kein `### Runde 2`),
When `adversary_dialog.py validate-artifact <artifact> <spec>` ausgefuehrt wird,
Then gibt das Skript "Weniger als 2 Runden" auf stderr aus und beendet mit Exit 1.

**AC-6** — fresh-eyes-inspector Unabhängigkeit
Given der fresh-eyes-inspector Agent-Prompt,
When der Agent aufgerufen wird und nur Screenshots (keine Spec, kein Workflow-Kontext) uebergeben werden,
Then bewertet der Agent ausschliesslich visuelle Qualitaet und fragt nicht nach Feature-Beschreibung oder Spec-Referenzen — seine Ausgabe enthaelt keine technischen Begriffe aus dem Workflow.

**AC-7** — adversary.md Checklisten-Pflicht
Given der ueberarbeitete adversary.md Prompt,
When Claude den Adversary-Prozess durchlaeuft,
Then ruft Claude in Schritt 2 explizit `adversary_dialog.py generate-checklist` auf (der Prompt macht diesen Aufruf als Pflichtschritt sichtbar, nicht als optionalen Hinweis).

## Known Limitations

- Dialog-Qualitaet haengt von der Spec-Qualitaet ab: unspezifische Expected-Behavior-Punkte fuehren zu einer mechanisch abgehakten Checkliste
- `validate-artifact` prueft nur Struktur (Rundenzahl, Verdict-Keyword) — nicht ob die Beweise inhaltlich ausreichend sind
- `adversary_dialog.py` kann keine Sub-Agenten spawnen; Claude orchestriert die Runden selbst
- Fresh-Eyes-Inspector liefert nur eine Momentaufnahme — dynamisches Verhalten (Animationen, Loading-States) ist nicht pruefbar

## Changelog

- 2026-05-10: Initial spec created
