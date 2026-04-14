# Workflow Management

Manage workflows with the 3-Checkpoint system.

## Commands

### List All Workflows
```bash
python3 .claude/hooks/workflow.py list
```

### Check Current Status
```bash
python3 .claude/hooks/workflow.py status
```

### Start New Workflow
```bash
python3 .claude/hooks/workflow.py start "feature-name"
```

### Switch Active Workflow
```bash
python3 .claude/hooks/workflow.py switch "other-feature"
```

### Set Specific Phase
```bash
python3 .claude/hooks/workflow.py phase phase3_spec
```

## Workflow Phases (v5)

| Phase | Name | Gate to enter | Gate to leave |
|-------|------|---------------|---------------|
| `phase0_idle` | Idle | — | /01-context |
| `phase1_context` | Context | — | context_file exists |
| `phase2_analyse` | Analysis | context_file | **Checkpoint 1** ("stimmt") |
| `phase3_spec` | Spec & Approval | checkpoint1 | spec_file + "approved" |
| `phase4_tdd_red` | TDD RED | spec_approved | RED artifacts + **Checkpoint 2** ("go") |
| `phase5_implement` | Implementation | checkpoint2 | Tests GREEN + **Checkpoint 3** ("commit") |
| `phase6_done` | Done | checkpoint3 | git commit erlaubt |

## 3 Human Checkpoints

| # | Keyword | Phase | Was Henning sieht |
|---|---------|-------|-------------------|
| 1 | "stimmt" | phase2_analyse | Root Cause + betroffene Stellen + Ansatz |
| 2 | "go" | phase4_tdd_red | Testname + was er prueft + FAILED Output |
| 3 | "commit" | phase5_implement | ALL GREEN Output + Screenshot |

**Nur Henning kann Checkpoints freischalten.** Claude kann `mark-checkpoint1/2/3` nicht direkt aufrufen — nur `phase_listener.py` (ausgeloest durch Hennings Eingabe) hat diese Berechtigung.

## Code Modification Rules

- **phase4_tdd_red:** Nur Test-Dateien editierbar
- **phase5_implement:** Nur Source-Dateien editierbar (Tests gesperrt!)
- **Alle anderen Phasen:** Keine Code-Edits

## Entry Points

| Command | Zweck |
|---------|-------|
| `/10-bug [description]` | Bug analysieren und fixen |
| `/11-feature [description]` | Feature planen und implementieren |
| `/01-context` | Manuell Kontext generieren |

## Parallel Workflows

Mehrere Workflows koennen gleichzeitig existieren. Jeder trackt eigene Phase, Spec, Artifacts und Checkpoints.

## State File Location

`.claude/workflows/<name>.json` — pro Workflow eine Datei.
`.claude/workflows/.sessions.json` — Session-Mapping.
