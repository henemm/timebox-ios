# Analyse: Feature #310 — Execution Log + /06-validate

## User-Erwartung (User Advocate)

"In drei Wochen frage ich: 'Wie war das damals?' und bekomme eine konkrete Antwort — ohne dass Claude 'kurz nachschauen' muss."

Das Log soll sich **automatisch schreiben**, nicht manuell ausgelöst werden. 
Zitat: "Wenn ich daran denken muss das Log zu 'schreiben' — werde ich es vergessen."

Gewünschtes Format: lesbar wie ein Tagebucheintrag, nicht wie eine Datenbank. 
"2 Adversary-Runden gebraucht" statt "fix_loop_count: 2".

## Technische Analyse (Feature Planner)

### Aktueller Zustand
- `workflow.py` kennt keine Phase-History, keinen Fix-Loop-Zähler, kein Execution Log
- `cmd_complete()` hat kein Log-Gate
- Alle benötigten Patterns (git diff, atomic write) existieren bereits im Code

### Was entsteht (1 Datei + 1 Markdown)

**`.claude/hooks/workflow.py`** (~65 LoC):
- `_new_workflow()`: 3 neue Felder (`phase_transitions[]`, `fix_loop_count`, `execution_log_written`)
- `cmd_phase()`: Transition loggen (from/to/at) + Fix-Loop-Counter aus `phase_transitions[]` ableiten
- `cmd_mark_adversary_verdict()`: bei BROKEN kein Extra-Flag nötig — `phase_transitions`-basierte Erkennung
- `cmd_write_log()` neu (~35 LoC): LoC-Delta via git, Log nach `.claude/workflows/_logs/`
- `cmd_complete()`: schreibt Log automatisch (löst User-Advocate-Besorgnis auf) — kein manuelles `write-log` nötig
- `cmd_status()`: `fix_loop_count` anzeigen

**`.claude/commands/06-validate.md`** (Markdown, kein Code):
- Guide für den Abschluss-Schritt — kein Gate, da Log automatisch in `complete` geschrieben wird

## Wichtige Design-Entscheidung

**User Advocate vs. Issue-Beschreibung — Spannung aufgelöst:**

Issue sagt: "`complete` blockiert ohne Log". User Advocate sagt: "Manuelle Schritte werden vergessen."

Lösung: `complete` schreibt das Log **selbst** (intern) — kein separater `write-log`-Aufruf nötig. `/06-validate.md` ist ein Leitfaden ohne Blockier-Funktion. Damit ist das Log garantiert vorhanden ohne zusätzliche Pflicht.

## Scope

| Datei | Typ | LoC |
|-------|-----|-----|
| `.claude/hooks/workflow.py` | ÄNDERUNG | ~65 |
| `.claude/commands/06-validate.md` | NEU | Markdown |

1 Code-Datei, weit unter Limit.
