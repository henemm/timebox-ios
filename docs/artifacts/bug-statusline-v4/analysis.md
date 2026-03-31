# Bug-Analyse: Statusline zeigt Workflow nicht an

## Symptom

Sessions mit aktivem Workflow zeigen diesen nicht in der Statusline an. Die Session-Aware-Infrastruktur (session_start.py, .sessions.json, workflow.py) existiert und ist committed, aber die Statusline funktioniert nicht zuverlässig.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 — Wiederholungs-Check
- **4 Versuche** bisher: v1 (os.ttyname, gescheitert), v2 (TERM_SESSION_ID, funktionierte), v3 (.active Symlink, Regression), v4 (.sessions.json, teilweise implementiert)
- v2 wurde beim v3-Refactoring (INFRA_002) entfernt
- v4 Code existiert und ist committed (a3c04cb), aber SessionStart-Hook fehlt in settings.json
- **KORREKTUR:** Agent behauptete SessionStart-Hook sei nicht registriert. Nachprüfung bestätigte: Hook fehlt tatsächlich in settings.json. ABER: `CLAUDE_SESSION_ID` ist trotzdem gesetzt (möglicherweise automatisch von Claude Code).

### Agent 2 — Datenfluss-Trace
- Statusline liest `session_id` aus stdin JSON → Lookup in `.sessions.json` → Workflow-JSON lesen
- **Kritischer Fund:** Statusline nutzte `workspace.current_dir` statt `workspace.project_dir`
- `.claude/workflows/` liegt im Projekt-Root — wenn current_dir ein Subdirectory ist, wird `.sessions.json` nicht gefunden
- **KORREKTUR:** Statusline wurde zwischenzeitlich von mir auf `project_dir` gefixt (Write-Tool auf `~/.claude/scripts/statusline.sh`)

### Agent 3 — Alle Schreiber
- NUR `_set_active()` in workflow.py (Zeile 220-223) schreibt in `.sessions.json`
- Aufgerufen von `cmd_start()` (Z.327) und `cmd_switch()` (Z.340)
- **Schreibt NUR wenn `CLAUDE_SESSION_ID` gesetzt** — sonst nur `.active` Symlink
- `cmd_complete()` (Z.461-464) entfernt Session aus `.sessions.json`
- **Verifiziert:** `.sessions.json` hat 6 echte Session-Mappings → Mechanismus funktioniert

### Agent 4 — Failure-Szenarien
- 9 Failure-Modes identifiziert, davon 3 kritisch:
  1. CLAUDE_SESSION_ID nicht gesetzt → .sessions.json wird nicht gefüllt
  2. current_dir ≠ project_dir → .sessions.json nicht gefunden
  3. jq-Fehler werden silent verschluckt → kein Debugging möglich

### Agent 5 — Blast Radius
- **NUR die Statusline ist betroffen**
- Python-Hooks (workflow.py, phase_listener.py, edit_gate.py) nutzen `_project_root()` für Pfad-Auflösung → korrekt
- bash_gate.py und post_bash.py nutzen File-Matching → immun
- Dead Code: `.claude/statusline.sh` im Repo (v2-Relikt, liest `workflow_state.json`)

## Hypothesen

### Hypothese 1: `current_dir` statt `project_dir` in Statusline (HOCH — BEWIESEN)

**Beschreibung:** Die Statusline nutzte `workspace.current_dir` für den Pfad zu `.sessions.json`. Wenn Claude Code in einem Subdirectory arbeitet (z.B. nach einem `cd Sources/`), zeigt `current_dir` auf das Subdirectory, aber `.claude/workflows/` liegt im Projekt-Root.

**Beweis DAFÜR:**
- Original-Code (vor Fix): `cwd=$(... '.workspace.current_dir' ...)` und `sessions_file="$cwd/.claude/workflows/.sessions.json"`
- `/Users/hem/Developer/my-daily-sprints/Sources/Views/.claude/` existiert NICHT → Lookup schlägt fehl
- Python-Hooks nutzen `_project_root()` → finden `.sessions.json` immer korrekt
- Fix mit `project_dir` funktioniert in Tests (verifiziert mit simuliertem Input)

**Beweis DAGEGEN:**
- Claude Code startet normalerweise im Projekt-Root → `current_dir == project_dir` in vielen Fällen
- **Unklar wie oft `current_dir` tatsächlich abweicht** — kein Logging der originalen Statusline vorhanden

**Wahrscheinlichkeit:** HOCH — Code-Defekt ist bewiesen, aber Häufigkeit des Triggers unklar

### Hypothese 2: SessionStart-Hook nicht registriert (MITTEL — TEILWEISE WIDERLEGT)

**Beschreibung:** `session_start.py` existiert, ist aber nicht in `settings.json` als `SessionStart`-Hook registriert. Ohne den Hook würde `CLAUDE_SESSION_ID` nie gesetzt, und `.sessions.json` würde nie gefüllt.

**Beweis DAFÜR:**
- `settings.json` enthält KEINEN `SessionStart`-Eintrag (verifiziert)
- `session_start.py` wird nie aufgerufen

**Beweis DAGEGEN:**
- `CLAUDE_SESSION_ID` IST gesetzt in dieser Session (`5b0a1271...`) — trotz fehlendem Hook
- `.sessions.json` HAT 6 echte Mappings → wird gefüllt
- Möglicherweise setzt Claude Code `CLAUDE_SESSION_ID` mittlerweile automatisch (undokumentiert)

**Wahrscheinlichkeit:** MITTEL — Hook fehlt, aber Variable wird trotzdem gesetzt. Der Hook ist möglicherweise redundant geworden.

### Hypothese 3: Race Condition bei .sessions.json Lesen (NIEDRIG)

**Beschreibung:** Statusline liest `.sessions.json` mit jq ohne File-Locking. Wenn workflow.py gleichzeitig schreibt, könnte jq eine halb-geschriebene Datei lesen.

**Beweis DAFÜR:**
- jq nutzt kein flock
- `2>/dev/null` verschluckt Parse-Errors

**Beweis DAGEGEN:**
- `_atomic_write()` in workflow.py nutzt tempfile + rename → atomarer Schreibvorgang
- Race Window ist extrem klein (rename ist atomar auf POSIX)

**Wahrscheinlichkeit:** NIEDRIG — atomare Writes machen dieses Szenario quasi unmöglich

## Wahrscheinlichste Ursache

**Hypothese 1 ist die Root Cause.** Die Statusline nutzte `workspace.current_dir` statt `workspace.project_dir` für den `.sessions.json`-Pfad. In Sessions wo `current_dir` vom Projekt-Root abweicht, wird die Datei nicht gefunden → kein Workflow angezeigt.

Hypothese 2 ist unklar (Hook fehlt, aber Variable funktioniert trotzdem) und sollte als Härtung adressiert werden, ist aber nicht die primäre Ursache.

## Debugging-Plan — DURCHGEFÜHRT

### Hypothese 1 BESTÄTIGT mit echtem Input:

Debug-Logging in Statusline eingebaut, echten Claude Code Input captured:

```
--- 17:54:44 ---  (meine Session)
{"sid":"5b0a1271...","cwd":"/Users/hem/Developer/my-daily-sprints","proj":"/Users/hem/Developer/my-daily-sprints"}

--- 17:54:47 ---  (Session 90571472 — BUG-TRIGGER!)
{"sid":"90571472...","cwd":"/Users/hem/Developer/my-daily-sprints/.claude/hooks/tests","proj":"/Users/hem/Developer/my-daily-sprints"}
```

**Session 90571472 hat `cwd` im Subdirectory `.claude/hooks/tests`!**
- Alte Statusline hätte `.sessions.json` in `.claude/hooks/tests/.claude/workflows/` gesucht → existiert nicht
- Neue Statusline mit `project_dir` findet die Datei korrekt
- **Dieselbe Session hatte auch den phase_listener.py Pfad-Fehler** (gemeldet vom User)

### Challenge-Ergebnis (Devil's Advocate):
- Verdict: LÜCKEN → Lücken geschlossen durch echten Input-Capture
- Übersehene Hypothese "project_dir könnte leer sein" → WIDERLEGT (immer befüllt in 4/4 Samples)
- Übersehene Hypothese "session_id fehlt im Statusline-JSON" → WIDERLEGT (immer vorhanden)

## Blast Radius

### Direkt betroffen:
- `~/.claude/scripts/statusline.sh` — einzige Datei mit dem Bug

### NICHT betroffen:
- `workflow.py` — nutzt `_project_root()` (korrekt)
- `phase_listener.py` — nutzt `_project_root()` (korrekt)
- `edit_gate.py` — nutzt `_project_root()` (korrekt)
- `bash_gate.py` — nutzt File-Matching, kein `.sessions.json` nötig

### Aufzuräumen:
- `.claude/statusline.sh` im Repo — Dead Code aus v2
