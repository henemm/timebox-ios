# Phase 2: Analyse

You are in **Phase 2 - Analysis** of the workflow.

## Prerequisites

- Context gathered (`/01-context` completed, or combined with analysis)
- Active workflow exists

Check current workflow:
```bash
python3 .claude/hooks/workflow.py status
```

## Your Tasks

### Step 1: Bug vs. Feature Routing

Bestimme aus dem Kontext:
- **Bug:** User meldet ein Problem, etwas funktioniert nicht wie erwartet
- **Feature:** User wuenscht neue Funktionalitaet oder Aenderung

### Step 2a: Feature-Analyse (3x Explore/Haiku parallel)

Bei Features dispatche **3 parallele Subagenten** fuer schnelle Kontextsammlung:

```
Task 1 (Explore/haiku): "Finde alle Dateien die von [Feature-Bereich] betroffen
  sind. Liste: Dateipfad, Typ (MODIFY/CREATE/DELETE), Begruendung."

Task 2 (Explore/haiku): "Suche nach bestehenden Specs in docs/specs/ die
  [Feature-Bereich] betreffen. Liste gefundene Specs mit Status."

Task 3 (Explore/haiku): "Identifiziere Dependencies und Imports fuer
  [Feature-Bereich]. Welche Module haengen davon ab? Welche werden importiert?"
```

### Step 2b: Bug-Analyse → DELEGIERE AN `/10-bug`

**⛔ KEIN vereinfachter Bug-Pfad hier!**

Bei Bugs MUSS der vollständige `/10-bug` Prozess durchlaufen werden:
- Schritt 0.2: Fresh-Eyes-Inspector (Screenshot + unabhängiger Agent)
- Schritt 2-4: 5 parallele Investigate-Tasks (ALLE PFLICHT)
- Schritt 5: Analyse-Dokument (`docs/artifacts/bug-[name]/analysis.md`)
- Schritt 5.5: Devil's Advocate (`analysis-challenger` Agent)
- Schritt 6: Analyse Henning präsentieren + Freigabe
- Schritt 7: Fix VORSCHLAGEN (nicht implementieren!) + Freigabe

**Workflow-Gates erzwingen dies technisch:**
- `visual_inspection_done` muss gesetzt sein
- `analysis_file` muss auf das Analyse-Dokument zeigen
- `analysis_findings` muss gesetzt sein
- `challenge_verdict` muss "SOLIDE" sein
- `fix_proposal_approved` muss true sein

→ Führe `/10-bug` aus. Dieser Skill setzt alle nötigen Workflow-Felder.

### Step 3: Strategische Bewertung (Plan/Sonnet)

Dispatche einen **Plan/Sonnet Subagenten** fuer die strategische Bewertung:

```
Task (Plan/sonnet): "Basierend auf folgenden Investigation-Ergebnissen:
  [Ergebnisse aus Step 2]

  Bewerte:
  1. Technischer Ansatz (wie implementieren?)
  2. Risiko-Bewertung (was koennte brechen?)
  3. Scope-Schaetzung (Dateien, LoC)
  4. Abhaengigkeiten und Reihenfolge
  5. Empfehlung (eine klare Empfehlung)"
```

### Step 4: Synthese praesentieren

Fasse die Ergebnisse zusammen und aktualisiere `docs/context/[workflow-name].md`:

```markdown
## Analysis

### Type
[Bug / Feature]

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Models/Auth.swift | MODIFY | Add OAuth provider |
| Sources/Config.swift | MODIFY | Add OAuth settings |
| Tests/AuthTests.swift | CREATE | New test file |

### Scope Assessment
- Files: [N]
- Estimated LoC: +[N]/-[N]
- Risk Level: LOW/MEDIUM/HIGH

### Technical Approach
[Empfehlung aus Plan/Sonnet Bewertung]

### Dependencies
[Aus Explore-Ergebnis]

### Open Questions
- [ ] Question 1?
```

### Step 5: Register Affected Files

Register ALL affected files from the analysis in the workflow state. This is **MANDATORY** — without it, the code gate will block implementation later.

```bash
# Register all files that will be modified/created
python3 .claude/hooks/workflow.py set-affected-files \
  "Sources/Models/Auth.swift" \
  "Sources/Config.swift" \
  "Tests/AuthTests.swift"
```

Use `--replace` to overwrite previous entries, or omit it to merge with existing.

### Step 6: Update Workflow State

```bash
python3 .claude/hooks/workflow.py phase phase3_spec
```

## Next Step

When analysis is complete:
> "Analysis complete. Type: [Bug/Feature]. Scope: [N] files, ~[N] LoC. Next: `/03-write-spec` to create the specification."

If you have open questions, ask the user before proceeding.

**IMPORTANT:** Do NOT start implementation. Analysis -> Spec -> Approve -> TDD RED -> Implement.
