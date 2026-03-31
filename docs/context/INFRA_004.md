# Context: INFRA_004 — GitHub-Standards Integration

## Request Summary
Custom-Tooling (~40%) durch GitHub-native Features ersetzen: Issues als Backlog, CI/CD via Actions, Workflow-Integration. Lokaler Hook-Enforcement bleibt.

## Analysis

### Type
Feature (Infrastructure Migration)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `.github/ISSUE_TEMPLATE/bug-report.yml` | CREATE | Strukturiertes Bug-Template (YAML Forms) |
| `.github/ISSUE_TEMPLATE/feature-request.yml` | CREATE | Strukturiertes Feature-Template |
| `.github/ISSUE_TEMPLATE/config.yml` | CREATE | Template-Konfiguration |
| `.github/PULL_REQUEST_TEMPLATE.md` | CREATE | PR-Template mit Summary/Test Plan |
| `.github/workflows/ci.yml` | CREATE | CI: Build + Unit Tests bei Push/PR |
| `.github/CODEOWNERS` | CREATE | Reviewer-Zuweisung |
| `.claude/hooks/bash_gate.py` | MODIFY | Zeile 259-276: ACTIVE-todos Gate → Issue-Link Gate |
| `.claude/commands/06-validate.md` | MODIFY | Zeile 153, 161: ACTIVE-todos Update → gh issue close |
| `.claude/commands/10-bug.md` | MODIFY | Zeile 102, 131, 284: Backlog-Referenzen → Issue-Referenzen |
| `CLAUDE.md` | MODIFY | Zeile 115: Single Source of Truth → GitHub Issues |
| `docs/ACTIVE-todos.md` | MODIFY | Wird Archiv-Dokument (read-only) |

### Scope Assessment
- **Files:** 11 (6 CREATE, 5 MODIFY)
- **Estimated LoC:** +215 / -20
- **Risk Level:** MEDIUM (Hook-Verhaltensänderung in bash_gate.py)

### 3-Phasen-Aufteilung (je Commit scope-konform)

**Phase 2 zuerst (rein additiv, kein Breaking Change):**

| Commit | Dateien | LoC |
|--------|---------|-----|
| 2a+2c+2e: ci.yml + PR Template + CODEOWNERS | 3 CREATE | ~120 |
| 2b: Branch Protection | gh-Befehle | 0 |

**Phase 1 danach (Hook-Änderung = Breaking Change):**

| Commit | Dateien | LoC |
|--------|---------|-----|
| 1a+1b: Labels + Issue Templates | 3 CREATE | ~80 |
| 1c+1d: Item-Migration + Board | gh-Befehle | 0 |
| 1e+1f: bash_gate.py + CLAUDE.md | 2 MODIFY | ~15 |

**Phase 3 zuletzt (abhängig von Phase 1):**

| Commit | Dateien | LoC |
|--------|---------|-----|
| 3a+3b: 10-bug.md + 06-validate.md | 2 MODIFY | ~20 |

### Technical Approach (Empfehlung)
1. **Phase 2 zuerst** — rein additive neue Dateien, kein Impact auf bestehenden Workflow
2. **Phase 1 danach** — Labels → Templates → Migration → Hook-Anpassung
3. **Phase 3 zuletzt** — Workflow-Commands mit Issue-System verzahnen

### Risiken
1. **bash_gate.py Verhaltensänderung (1e):** Aktuell "ACTIVE-todos staged?" → Neu "Issue-Link im Commit?". Braucht Ausnahme-Whitelist für `docs:`/`chore:`-Commits (nicht jeder Commit hat ein Issue)
2. **CI macOS Runner:** Repo ist public → kostenlos. Aber Builds dauern 8-15 Min. Empfehlung: nur Unit Tests, keine UI Tests in CI
3. **Projects V2 Board (1d):** Nur via GraphQL/Web-UI → manuell durch Henning einrichten

### Dependencies
- Phase 1 + 2 parallel möglich
- Phase 3 braucht Phase 1 (Issues müssen existieren)
- Branch Protection (2b) als letztes in Phase 2 (blockiert sonst sofort)

### Open Questions
- [ ] bash_gate.py: Welche Commit-Typen brauchen Issue-Verlinkung? Nur `fix:`/`feat:` oder alle?
- [ ] Projects V2 Board: Soll Henning das manuell in der Web-UI einrichten, oder via gh CLI (umständlich)?
- [ ] Branch Protection: Required Reviews (1) aktivieren? (Henning ist Solo-Developer)

## GitHub-Repo Status
- **Remote:** https://github.com/henemm/timebox-ios
- **Default Branch:** main
- **Labels:** nur Defaults
- **Issues:** keine vorhanden
- **`.github/`:** existiert noch nicht

## Existing Specs
- `docs/specs/infra/INFRA_002-workflow-v3.md` — Workflow v3 (Hooks)
- `docs/specs/infra/INFRA_003-session-aware-workflows.md` — Session-aware Workflows
- Kein INFRA_004-Spec vorhanden (wird in Phase 3 erstellt)

## Existing Analysis
- Memory: `reference_github-standards-analyse.md` — Vollständige Kompatibilitätsanalyse
