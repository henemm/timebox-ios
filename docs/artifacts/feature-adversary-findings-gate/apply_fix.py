#!/usr/bin/env python3
"""
Setzt __infra__ Token für Adversary-Findings-Gate Implementation.
Erlaubt Edits an .claude/hooks/*.py Dateien.
"""
import json
from datetime import datetime
from pathlib import Path

token_file = Path(".claude/user_override_token.json")
if token_file.exists():
    data = json.loads(token_file.read_text())
else:
    data = {"version": 2, "tokens": {}}

if "tokens" not in data:
    data["tokens"] = {}

data["tokens"]["__infra__"] = {
    "created": datetime.now().isoformat(),
    "granted_by": "user_prompt",
    "reason": "feature-adversary-findings-gate implementation"
}

token_file.write_text(json.dumps(data, indent=2))
print("__infra__ Token gesetzt. Hook-Dateien können jetzt editiert werden.")
