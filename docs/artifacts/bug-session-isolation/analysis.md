# Bug-Analyse: Session-Isolation funktioniert nicht

## Symptom
Neue Claude-Sessions sehen den Workflow einer anderen Session. Beim Start eines neuen Workflows wird der `.active`-Symlink überschrieben, was die andere Session stört.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- Epic #156 (INFRA_005-009) hat Session-Isolation implementiert (Commit a3c04cb, 2026-03-31)
- `.sessions.json` mit fcntl.flock, Build-Lock, Stop-Lock, Edit-Gate — alles vorhanden
- **Aber:** `SessionStart`-Hook wurde NIE in `settings.json` registriert
- GitHub Issue #178 ist OFFEN

### Agent 2: Datenfluss-Trace
- `session_start.py` existiert und ist korrekt implementiert
- Liest `session_id` aus stdin-JSON, schreibt nach `CLAUDE_ENV_FILE`
- **Kette bricht bei der Quelle:** Hook wird nie aufgerufen (nicht registriert)
- `_get_session_id()` in workflow.py gibt IMMER `""` zurück
- ALLE Hooks fallen auf `.active` Symlink zurück

### Agent 3: Alle Schreiber
- `_set_active()` (workflow.py:246-252) schreibt `.active` Symlink **IMMER** — unabhängig von Session-ID
- `.sessions.json` wird nur beschrieben wenn `CLAUDE_SESSION_ID` gesetzt (was nie passiert)
- 6 Dateien LESEN `.sessions.json`, aber weil Session-ID leer: alle Fallback auf `.active`

### Agent 4: Szenarien
- 10 Szenarien identifiziert, davon 3 mit HOHER Wahrscheinlichkeit:
  1. `session_start.py` wird nie aufgerufen (Hook nicht registriert)
  2. `.active` Symlink Race Condition (nicht-atomar: unlink + symlink)
  3. Hook-Prozess erbt `CLAUDE_ENV_FILE` nicht

### Agent 5: Blast Radius
- **5 von 6 Hook-Dateien** nutzen Session-ID und fallen ohne sie zurück
- Stop-Lock Isolation zerfällt komplett (bash_gate.py, edit_gate.py)
- Build-Lock degradiert zu PPID-basiert (funktioniert, aber nicht session-isoliert)
- phase_listener erstellt globale Stop-Locks statt per-Session

## Hypothesen

### Hypothese 1: `SessionStart`-Hook nicht in settings.json registriert (HOCH)
**Beweis DAFÜR:**
- `.claude/settings.json` enthält nur `PreToolUse`, `PostToolUse`, `UserPromptSubmit`
- Kein `SessionStart`-Eintrag vorhanden
- `session_start.py` existiert aber wird nie aufgerufen

**Beweis DAGEGEN:**
- Keiner. settings.json ist eindeutig — kein SessionStart-Hook.

**Wahrscheinlichkeit: HOCH (99%)**

### Hypothese 2: Selbst mit Hook — `CLAUDE_ENV_FILE` nur für SessionStart verfügbar (MITTEL)
**Beweis DAFÜR:**
- Claude Code Docs: `CLAUDE_ENV_FILE` wird nur für `SessionStart`, `CwdChanged`, `FileChanged` gesetzt
- `session_start.py` schreibt `export CLAUDE_SESSION_ID="..."` in diese Datei
- PreToolUse/PostToolUse Hooks lesen `os.environ.get("CLAUDE_SESSION_ID")` — das funktioniert NUR wenn Claude Code die env-Datei sourced

**Beweis DAGEGEN:**
- Claude Code SOLL env-Dateien zwischen Hooks sourced — das ist der dokumentierte Mechanismus

**Wahrscheinlichkeit: MITTEL (40%) — hängt von Claude Code Runtime ab**

### Hypothese 3: session_id im stdin-JSON wird von den meisten Hooks ignoriert (HOCH)
**Beweis DAFÜR:**
- Claude Code sendet `session_id` in JEDEM Hook-Input (PreToolUse, PostToolUse, UserPromptSubmit)
- **Aber:** `bash_gate.py`, `edit_gate.py`, `post_bash.py` lesen Session-ID aus `os.environ` — NICHT aus stdin
- Nur `phase_listener.py` liest `session_id` aus dem Hook-Input-JSON
- Die Session-ID ist also VERFÜGBAR, wird aber von 4 von 5 Hooks IGNORIERT

**Beweis DAGEGEN:**
- Keiner. Die Code-Analyse ist eindeutig.

**Wahrscheinlichkeit: HOCH (95%)**

## Wahrscheinlichste Ursache(n)

**Kombination aus Hypothese 1 + 3:**

1. `SessionStart`-Hook fehlt in settings.json → `CLAUDE_SESSION_ID` wird nie als env-var gesetzt
2. Die meisten Hooks lesen aus `os.environ` statt aus stdin-JSON → Session-ID bleibt leer
3. Alle fallen auf `.active` Symlink zurück → keine Isolation

**Der sauberste Fix:** Alle Hooks sollen `session_id` aus dem stdin-JSON lesen (wie `phase_listener.py` es schon tut). Zusätzlich `SessionStart`-Hook registrieren für den `CLAUDE_ENV_FILE`-Mechanismus als Backup.

## Debugging-Plan

### Beweis für Hypothese 1+3:
1. In `bash_gate.py` Logging einbauen: `session_id` aus stdin-JSON UND aus `os.environ` loggen
2. Hook aufrufen → Log prüfen: stdin hat session_id, env hat keine

### Widerlegung:
Wenn `os.environ` DOCH `CLAUDE_SESSION_ID` enthält, ist die Hook-Registrierung nicht das Problem.

## Blast Radius

| Hook | Betroffen | Auswirkung |
|------|-----------|------------|
| workflow.py | JA | Falscher Workflow wird angezeigt/modifiziert |
| bash_gate.py | JA | Stop-Lock nicht session-isoliert, Build-Lock degradiert |
| edit_gate.py | JA | Stop-Lock nicht session-isoliert |
| post_bash.py | JA | Build-Lock Release auf falscher Session |
| phase_listener.py | NEIN | Liest session_id bereits aus stdin-JSON |
| session_start.py | JA | Wird nie aufgerufen |

## Challenge Report (Devil's Advocate)

**Verdict: LÜCKEN** — Diagnose bestätigt, Fix-Ansatz verfeinert.

### Lücke 1: stdin wird bereits konsumiert
In `bash_gate.py:_get_command()` (Z.115), `edit_gate.py:main()` (Z.226), `post_bash.py:main()` (Z.108) wird `json.load(sys.stdin)` aufgerufen und nur `tool_input` extrahiert. `session_id` wird WEGGEWORFEN. Ein zweites `json.load(sys.stdin)` ist unmöglich.

**Lösung:** Beim ERSTEN stdin-Read session_id MIT-extrahieren und als Modul-Variable speichern.

### Lücke 2: CLAUDE_ENV_FILE Persistenz unsicher
`CLAUDE_ENV_FILE` ist nur für `SessionStart`/`CwdChanged`/`FileChanged` dokumentiert. Ob env-Variablen daraus in PreToolUse/PostToolUse verfügbar sind, ist nicht bewiesen.

**Lösung:** Fix A (stdin-basiert) ist der Hauptweg. SessionStart-Registrierung ist Backup.

### Lücke 3: .active Symlink Race Condition bleibt
Selbst MIT session_id schreibt `_set_active()` den .active Symlink nicht-atomar (unlink + symlink).

**Lösung:** Im Fix mitadressieren — .active nur noch schreiben wenn session_id leer (Legacy).

## Fix-Ansatz (Vorschlag, nach Challenge verfeinert)

### Fix A: session_id aus stdin beim ersten Read extrahieren (Hauptfix)

**Konkreter Patch-Plan:**

Alle 3 Hooks haben dasselbe Pattern:
```python
# VORHER (bash_gate.py:111-116, edit_gate.py:223-227, post_bash.py:106-109):
data = json.load(sys.stdin)
tool_input = json.dumps(data.get("tool_input", {}))
# session_id wird WEGGEWORFEN

# NACHHER:
data = json.load(sys.stdin)
tool_input = json.dumps(data.get("tool_input", {}))
_STDIN_SESSION_ID = data.get("session_id", "")  # NEU: session_id speichern
```

Dann `_get_session_id()` anpassen:
```python
# VORHER:
def _get_session_id() -> str:
    sid = os.environ.get("CLAUDE_SESSION_ID", "")
    ...

# NACHHER:
def _get_session_id() -> str:
    sid = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID
    ...
```

**Betroffene Dateien:** `bash_gate.py`, `edit_gate.py`, `post_bash.py`
**workflow.py:** Wird über CLI aufgerufen (nicht als Hook) — braucht separaten Mechanismus

### Fix B: SessionStart-Hook registrieren (Backup)

```json
// In settings.json hinzufügen:
"SessionStart": [{
  "hooks": [{
    "type": "command",
    "command": "python3 .claude/hooks/session_start.py",
    "timeout": 5
  }]
}]
```

Setzt `CLAUDE_SESSION_ID` als env-var via `CLAUDE_ENV_FILE`. Redundanz für `workflow.py` CLI-Aufrufe.

### Fix C: .active Symlink absichern
- `_set_active()` schreibt .active NUR wenn session_id leer (Legacy-Kompatibilität)
- Bei gesetzter session_id: nur `.sessions.json` updaten, .active nicht anfassen
- Langfristig: .active entfernen
