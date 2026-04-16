# Analyse: #238 Adversary-Findings-Gate (Update 2026-04-16)

## User-Erwartung (User Advocate)

Henning will **Vertrauen durch Kontrolle**: Kein Finding darf an ihm vorbei. Jedes Problem wird ihm einzeln vorgelegt, er entscheidet bewusst (Fixen / Akzeptabel / Zurückstellen). Erst wenn alles beantwortet ist, wird Commit freigeschaltet.

**Kern-Wert:** Nicht Vertrauen in Claude, sondern Vertrauen in sich selbst als PO — "Nichts ist durchgerutscht, weil ich jede Entscheidung bewusst getroffen habe."

**Risiko:** Wenn Findings trivial oder unverständlich sind, klickt Henning blind durch → Sicherheitstheater statt echte Kontrolle.

## Technische Analyse (Feature Planner)

**Kern-Feature ist BEREITS implementiert** (Commit a800d03):
- `workflow.py`: add-finding, resolve-finding, list-findings, Transition-Gate
- `phase_listener.py`: Keywords (fixen/akzeptabel/zurückstellen), CP3-Check
- `bash_gate.py`: Commit-Block bei offenen Findings
- `adversary.md`: JSON-Output-Format für strukturierte Findings

**Was noch fehlt:**
1. **Auto-Ticket für "fix"-Findings** — Roadmap sagt "wird automatisch zu GitHub Issue", Code fehlt
2. **`import-findings` Kommando** — Adversary generiert JSON, aber Claude muss manuell `add-finding` pro Finding aufrufen (fehleranfällig)
3. **`status` zeigt keine Findings** — Henning sieht beim Status-Aufruf nicht welche Findings offen sind

## Scope-Schätzung

- 1 Datei betroffen: `workflow.py` (~50-70 LoC)
- Weit unter Scoping-Limit
