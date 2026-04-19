# Phase 5: Implementation (Workflow v6 — Developer-Agent)

You are in **Phase 5 - Implementation**.

## v6 Orchestrator-Pattern

**Du schreibst KEINEN Code selbst.** Du spawnst den Developer-Agent im Worktree.

### Voraussetzungen pruefen

```bash
python3 .claude/hooks/workflow.py status
```

Checkpoint 2 muss approved sein, RED-Artifacts muessen existieren.

### Developer-Agent spawnen

```
Agent(subagent_type: "developer", isolation: "worktree")
```

**Input fuer den Developer-Agent:**
- Spec-Pfad: [spec_file aus Workflow-State]
- RED-Tests: [test_artifacts — Dateipfade der fehlschlagenden Tests]
- Affected Files: [affected_files]
- Konventionen: `./scripts/sim.sh` nutzen, max 4-5 Dateien, max 250 LoC

### Nach Developer-Report

1. Pruefe: Alle Tests gruen? Scope eingehalten? Von Spec abgewichen?
2. Bei Fehlern: Developer-Agent erneut spawnen mit Feedback (max 3 Versuche)
3. Nach 3 Fehlschlaegen: Eskalation an Henning

### GREEN Artifacts erfassen

```bash
python3 .claude/hooks/workflow.py mark-green "[test-output-summary]"
python3 .claude/hooks/workflow.py mark-ui-green "[UI test summary]"
```

### Weiter zur Adversary-Phase

```bash
python3 .claude/hooks/workflow.py phase phase6_adversary
```

Dann den Implementation-Validator spawnen (siehe `/11-feature` oder `/10-bug` Phase 6).

## Fallback: Direktes Implementieren

Wenn der Developer-Agent aus technischen Gruenden nicht funktioniert (z.B. Worktree-Probleme mit Xcode), darf der Orchestrator ausnahmsweise selbst implementieren. Dies sollte aber die Ausnahme sein, nicht die Regel.
