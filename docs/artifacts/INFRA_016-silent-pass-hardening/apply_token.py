#!/usr/bin/env python3
"""Setzt __infra__ Override-Token für INFRA_016-Implementation.

Wird einmal manuell von Henning aufgerufen, damit Claude die Hooks
(.claude/hooks/*.py) und Agent-Prompts (.claude/agents/*.md) editieren darf.

Token wird nach dem nächsten git commit automatisch gelöscht
(siehe override_token.py:remove_all_tokens).
"""

import json
from datetime import datetime
from pathlib import Path

token_file = Path(".claude/user_override_token.json")
data = json.loads(token_file.read_text()) if token_file.exists() else {"version": 2, "tokens": {}}

if data.get("version") != 2:
    data = {"version": 2, "tokens": {}}

data["tokens"]["__infra__"] = {
    "created": datetime.now().isoformat(),
    "granted_by": "user_prompt",
    "purpose": "INFRA_016-silent-pass-hardening implementation",
}

token_file.write_text(json.dumps(data, indent=2))
print(f"OK — __infra__ token gesetzt für INFRA_016. Aktive tokens: {list(data['tokens'].keys())}")
