#!/usr/bin/env python3
"""
Project Structure Guard - Prevents writing to wrong directories

The project root is: /Users/hem/Documents/opt/my-daily-sprints/
TimeBox/ is the Xcode project subdirectory.

BLOCKED paths (these should NOT exist inside TimeBox/):
- TimeBox/docs/      → use docs/ in root
- TimeBox/.claude/   → use .claude/ in root
- TimeBox/openspec/  → use openspec/ in root

Exit Codes:
- 0: Allowed
- 2: Blocked (wrong location)
"""

import json
import sys

# Paths that should NOT be inside TimeBox/
BLOCKED_PATHS = [
    ('TimeBox/docs/', 'docs/', 'Dokumentation'),
    ('TimeBox/.claude/', '.claude/', 'Claude Konfiguration'),
    ('TimeBox/openspec/', 'openspec/', 'OpenSpec Dateien'),
]


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    tool_input = data.get('tool_input', {})
    file_path = tool_input.get('file_path', '')

    for blocked, correct, description in BLOCKED_PATHS:
        if blocked in file_path or blocked.replace('/', '\\') in file_path:
            print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  🚫 BLOCKED: Falsches Verzeichnis!                               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Du versuchst in {blocked:<43}zu schreiben.
║                                                                  ║
║  {description} gehört nach:
║    {correct:<57}
║                                                                  ║
║  NICHT nach {blocked:<49}
║                                                                  ║
║  Korrigiere den Pfad und versuche es erneut!                     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
            sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
