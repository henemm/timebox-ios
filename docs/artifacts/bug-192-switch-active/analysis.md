# Bug #192: workflow.py switch aktualisiert .active nicht

## Zusammenfassung der 5 Investigate-Ergebnisse

### Agent 1 — Wiederholungs-Check
4 Generationen von Session-Isolation-Fixes:
- v1 (9b5b772): TTY-basiert → failed (TTY nicht in Pipes)
- v2 (Epic #156): CLAUDE_SESSION_ID env + fcntl.flock → failed (SessionStart nie registriert)
- v3 (9893739, #178): stdin-JSON session_id + SessionStart Hook → **funktioniert**
- v4 (aktuell): Session-Mapping via .sessions.json, .active als Fallback → **Bug #192**

### Agent 2 — Datenfluss-Trace
- `workflow.py` `_get_session_id()` (Zeile 119): liest **NUR** `os.environ.get("CLAUDE_SESSION_ID")`
- `edit_gate.py` `_read_active_workflow()` (Zeile 119): liest `env OR _STDIN_SESSION_ID`
- `_set_active()` (Zeile 234-253): schreibt `.sessions.json` wenn session_id gesetzt, `.active` Symlink **NUR** wenn session_id LEER

### Agent 3 — Alle Schreiber
- `.active` wird NUR von `workflow.py:_set_active()` (Zeile 253) und `migrate_state.py` (einmalig) geschrieben
- `.sessions.json` wird NUR über `_locked_sessions()` geschrieben (atomic + fcntl.flock)
- Keine regulären Datei-Writes auf `.active` — immer Symlink

### Agent 4 — Szenarien
- **Szenario A** (kein session_id): .active wird korrekt aktualisiert ✅
- **Szenario B** (session_id gesetzt): .active wird NICHT aktualisiert, nur .sessions.json ⚠️
- **Szenario C** (Race Condition): Zwei Sessions ohne session_id → .active clobber
- **Szenario D** (.active als Datei): Wird korrekt zu Symlink konvertiert ✅

### Agent 5 — Blast Radius
Ähnliche Inkonsistenzen in:
- `bash_gate.py` Zeile 105: `_is_stop_locked()` liest nur env
- `bash_gate.py` Zeile 320: Git-commit adversary check liest nur env
- `post_bash.py` Zeile 35: `_read_active_workflow()` liest nur env

---

## Hypothesen

### Hypothese 1: _set_active() schreibt .active nicht wenn CLAUDE_SESSION_ID gesetzt (HOCH)

**Datenfluss:**
1. SessionStart-Hook setzt `CLAUDE_SESSION_ID` via `CLAUDE_ENV_FILE`
2. `workflow.py switch X` erbt env → `_get_session_id()` gibt session_id zurück
3. `_set_active(X)` schreibt `.sessions.json[sid] = X` ✅
4. `if not session_id:` → FALSE → `.active` wird **NICHT** aktualisiert 🔴

**Beweis dafür:**
- Code Zeile 246-247: `if not session_id:` — explizite Bedingung
- `.active` zeigt noch auf `epic-170c-smart-nudges.json` (verifiziert mit `ls -la`)
- Reproduktionsschritte im Issue bestätigen: switch meldet Erfolg, .active bleibt alt

**Beweis dagegen:**
- edit_gate.py liest zuerst .sessions.json (mit session_id aus stdin) — sollte dort den richtigen Workflow finden
- Wenn edit_gate korrekt aus .sessions.json liest, wäre .active irrelevant

**Wahrscheinlichkeit: HOCH** — Der Code macht genau das was das Issue beschreibt.

### Hypothese 2: edit_gate findet alten Workflow über affected_files statt über active (MITTEL)

**Datenfluss:**
1. `edit_gate.py` Zeile 290: `_find_workflow_for_file(file_path)` scannt ALLE Workflows
2. Alter Workflow `epic-170c` hat dieselben Files in `affected_files`
3. Wird VOR `_read_active_workflow()` gefunden (Zeile 290 vor 295)
4. Alter Workflow in `phase6_implement` → blockiert oder erlaubt mit falschen Gates

**Beweis dafür:**
- `_find_workflow_for_file` iteriert alphabetisch über alle .json-Dateien
- Mehrere Workflows können dieselben affected_files haben
- Der Workflow `epic-170c` hat 6 affected_files (verifiziert)

**Beweis dagegen:**
- Switch soll den AKTIVEN Workflow wechseln, nicht die affected_files transferieren
- Wenn nur der aktive Workflow relevant ist, greift Hypothese 1

**Wahrscheinlichkeit: MITTEL** — Könnte den Impact verschlimmern, ist aber nicht die Root Cause.

### Hypothese 3: CLAUDE_SESSION_ID ist NICHT gesetzt — .active Symlink wird erstellt aber falsch (NIEDRIG)

**Datenfluss:**
- Wenn CLAUDE_ENV_FILE nicht korrekt gesourced wird → kein session_id
- `_set_active` schreibt .active Symlink → sollte funktionieren (Zeile 248-253)
- Aber: Vielleicht schreibt ein anderer Prozess .active danach zurück?

**Beweis dagegen:**
- SessionStart-Hook IST registriert in settings.json (Zeile 57-66, verifiziert)
- session_start.py schreibt korrekt zu CLAUDE_ENV_FILE
- Kein anderer Prozess schreibt .active (Agent 3 bestätigt)

**Wahrscheinlichkeit: NIEDRIG**

---

## Wahrscheinlichste Ursache

**Hypothese 1 + 2 in Kombination:**

1. `_set_active()` aktualisiert `.active` nicht wenn session_id gesetzt ist (Root Cause)
2. edit_gate.py liest zwar korrekt aus `.sessions.json`, ABER `_find_workflow_for_file()` findet den alten Workflow über affected_files (verschärfender Faktor)

**Fix-Richtung:** `_set_active()` sollte `.active` IMMER aktualisieren — unabhängig von session_id. Das Symlink ist für Debugging, Statusline und Backward-Compat. `.sessions.json` bleibt die Quelle der Wahrheit für Session-Isolation.

---

## Verifizierte Fakten (nach Challenge-Runde 1)

### CLAUDE_SESSION_ID ist GESETZT — H1 bestätigt
```
echo $CLAUDE_SESSION_ID → 1345e86f-8f64-4469-b0db-2369332a7041
```
→ `_set_active()` schreibt NUR .sessions.json, NICHT .active. **H1 BEWIESEN.**

### Massive affected_files-Überlappung — H2 bestätigt
```
epic-170c:         MainTabView, CoachView, ContentView, SettingsView, FocusBloxApp, CoachTabLayoutUITests (6 Files)
coach-tab-layout-v2: MainTabView, CoachView, ContentView, SettingsView, FocusBloxApp, CoachTabLayoutUITests, MonsterRemovalCleanupTests (7 Files)
```
**6 von 7 Dateien überlappen!** `_find_workflow_for_file()` (Zeile 157, alphabetisch sortiert) findet `coach-tab-layout-v2` VOR `epic-170c` (c < e). Aber beide matchen.

### H3 widerlegt
CLAUDE_SESSION_ID ist gesetzt → H3 ist ausgeschlossen.

---

## Aktualisierte Root Cause

**H1 ist die direkte Root Cause:**
`_set_active()` Zeile 247 `if not session_id:` überspringt .active-Update wenn session_id gesetzt ist. Da CLAUDE_SESSION_ID via SessionStart-Hook IMMER gesetzt ist, wird .active NIE aktualisiert nach einem switch.

**H2 ist ein separates Problem (aber OUT OF SCOPE für #192):**
`_find_workflow_for_file()` ist session-agnostisch. Bei überlappenden affected_files findet es den ERSTEN alphabetischen Match. Das ist Design-Intent (File-Ownership), kein Bug — aber problematisch wenn zwei Workflows dieselben Files claimen.

**Fix:** `_set_active()` soll .active IMMER aktualisieren. Bei parallelen Sessions "gewinnt" der letzte Switcher das Symlink — das ist OK weil:
- Session-aware Tools nutzen .sessions.json (Quelle der Wahrheit)
- .active ist NUR für Backward-Compat und Debugging
- Ein "falsches" .active bei parallelen Sessions ist besser als ein STALES .active

---

## Blast Radius

### Direkt betroffen:
- .active zeigt falschen Workflow nach jedem switch (IMMER, nicht nur manchmal)
- `workflow.py status` (ohne session_id von extern) zeigt alten Workflow
- Statusline zeigt falschen Workflow als Fallback

### Ähnliches Pattern (session_id nur aus env) — separater Scope:
- `bash_gate.py:105` — stop-lock Check
- `bash_gate.py:320` — git commit adversary Check
- `post_bash.py:35` — active Workflow Reader

### NICHT betroffen (lesen korrekt):
- `edit_gate.py` — liest env + stdin ✅
- `phase_listener.py` — liest aus hook_input ✅
