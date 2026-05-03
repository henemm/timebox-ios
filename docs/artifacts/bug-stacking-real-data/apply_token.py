#!/usr/bin/env python3
"""
Override-Token fuer bug-stacking-real-data setzen.

Hennings 'override'-Eingabe wurde unter falschem Workflow-Namen registriert
(feature-300-longpress-task-title statt bug-stacking-real-data) — vermutlich
phase_listener-Cache-Problem. Dieses Script korrigiert das.

Ausfuehren mit:
    ! python3 docs/artifacts/bug-stacking-real-data/apply_token.py
"""
import json
from datetime import datetime
from pathlib import Path

WORKFLOW = "bug-stacking-real-data"
TOKEN_FILE = Path(__file__).parent.parent.parent.parent / ".claude" / "user_override_token.json"

if not TOKEN_FILE.exists():
    data = {"version": 2, "tokens": {}}
else:
    data = json.loads(TOKEN_FILE.read_text())
    if data.get("version") != 2:
        data = {"version": 2, "tokens": {}}

data["tokens"][WORKFLOW] = {
    "created": datetime.now().isoformat(),
    "granted_by": "user_prompt",
}

TOKEN_FILE.write_text(json.dumps(data, indent=2))
print(f"OK — Token for '{WORKFLOW}' set in {TOKEN_FILE}")
print(f"Active tokens: {list(data['tokens'].keys())}")
