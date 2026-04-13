# Context: INFRA_014 — Workflow Hardening

## Auslöser
Selbstkritik-Analyse aus Praxis-Session identifizierte 5 wiederkehrende Schwachstellen:
1. `/inspect-ui` Pre-Flight wird übersprungen → falsche Accessibility-IDs in Tests
2. Spec-Testplan wird nicht vollständig umgesetzt → fehlende Tests unbemerkt
3. Affected-Files-Liste unvollständig → 3x Nachregistrierung nötig
4. Spec-ACs beim Implementieren vergessen → Adversary deckt erst spät auf
5. Regressions-Lauf zu schmal → nur Teilmenge statt volle Suite

## Betroffene Dateien
- `.claude/hooks/edit_gate.py` — Inspect-UI Gate (Maßnahme A)
- `.claude/hooks/workflow.py` — Neues Feld `inspect_ui_done`, neuer Command
- `.claude/hooks/adversary_dialog.py` — Testplan-Extraktion (Maßnahme B)
- `.claude/commands/04-tdd-red.md` — Inspect-UI Pflicht-Hinweis
- `.claude/commands/03-write-spec.md` — Affected-Files-Warnung (Maßnahme C)
- `.claude/commands/06-validate.md` — Regression-Scope-Mindestanforderung

## Abhängigkeiten
- `inspect-ui.md` referenziert `preflight_gate.py` die NICHT existiert
- Workflow-State braucht neues Feld `inspect_ui_done`
- adversary_dialog.py braucht neue Funktion `parse_spec_test_plan()`
