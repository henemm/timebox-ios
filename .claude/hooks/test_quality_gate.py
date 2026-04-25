#!/usr/bin/env python3
"""Test-Quality-Gate — blockiert Silent-Pass-Patterns in Test-Dateien.

PreToolUse-Hook für Edit|Write. Triggert nur bei Test-Dateien
(.swift in *Tests/ oder *UITests/). Erkennt Patterns, die Tests
GREEN melden lassen ohne den Bug auszulösen:

  P1: guard let x = ... else { return }      → blockiert
  P3: XCTAssertNotNil(x); guard let x = ...  → blockiert (verwende XCTUnwrap)

P2 (if let ohne else { XCTFail }) wird vom Adversary geprüft — Hook
würde zu viele false positives erzeugen (legitimes Setup-Code).

Bypass via __infra__-Override-Token in user_override_token.json.

Exit Codes: 0 = allowed, 2 = blocked
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

INFRA_TOKEN_TTL_MIN = 60

TEST_PATH_PATTERNS = [
    re.compile(r"Tests?/.*\.swift$"),
    re.compile(r"UITests?/.*\.swift$"),
]

# P1: guard let X = ... else { return }
PATTERN_GUARD_LET_RETURN = re.compile(
    r"guard\s+(?:let|var)\s+\w+.*?\selse\s*\{\s*return\b",
    re.DOTALL,
)

# P3: XCTAssertNotNil(...) gefolgt von guard let
PATTERN_ASSERT_THEN_GUARD = re.compile(
    r"XCTAssertNotNil\s*\([^)]+\)\s*[;\n][^\n]*\n?\s*guard\s+(?:let|var)\s+\w+",
    re.MULTILINE,
)


def _project_root() -> Path:
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _has_infra_token() -> bool:
    """Check whether __infra__ override token is set AND not expired.

    TTL: token expires after INFRA_TOKEN_TTL_MIN minutes. Prevents stale
    tokens from disabling the hook session-wide between implementation
    and commit. Token is also auto-removed after git commit (see
    override_token.py:remove_all_tokens) — TTL covers the window between.
    """
    token_file = _project_root() / ".claude" / "user_override_token.json"
    if not token_file.exists():
        return False
    try:
        data = json.loads(token_file.read_text())
        if data.get("version") == 2:
            tokens = data.get("tokens", {})
            if "__infra__" not in tokens:
                return False
            created = tokens["__infra__"].get("created", "")
            if created:
                try:
                    age_min = (datetime.now() - datetime.fromisoformat(created)).total_seconds() / 60
                    if age_min > INFRA_TOKEN_TTL_MIN:
                        return False
                except (ValueError, TypeError):
                    pass
            return True
        return data.get("workflow") == "__infra__"
    except (json.JSONDecodeError, OSError):
        return False


def _is_test_file(file_path: str) -> bool:
    """Check if path looks like a Swift test file."""
    return any(p.search(file_path) for p in TEST_PATH_PATTERNS)


def _get_tool_input() -> dict:
    """Read tool_input from env or stdin."""
    env_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if env_input:
        try:
            return json.loads(env_input)
        except json.JSONDecodeError:
            pass
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError, OSError):
        return {}
    if isinstance(data, dict) and "tool_input" in data:
        return data["tool_input"]
    return data if isinstance(data, dict) else {}


def _extract_content(tool_input: dict, file_path: str = "") -> str:
    """Get the post-edit content for Silent-Pass detection.

    Write: returns content directly.
    Edit: reads existing file, simulates the old_string→new_string
    replacement, returns the final content. This catches Silent-Pass
    patterns that already exist in the file but aren't part of the
    new_string itself. Falls back to new_string if file can't be read.
    """
    if "content" in tool_input:
        return tool_input.get("content", "") or ""
    new_str = tool_input.get("new_string", "") or ""
    if not new_str:
        return ""
    old_str = tool_input.get("old_string", "") or ""
    if file_path and old_str:
        full_path = Path(file_path)
        if not full_path.is_absolute():
            full_path = _project_root() / file_path
        if full_path.exists():
            try:
                current = full_path.read_text()
                if old_str in current:
                    return current.replace(old_str, new_str, 1)
            except OSError:
                pass
    return new_str


def _line_for_match(content: str, match: re.Match) -> int:
    return content[: match.start()].count("\n") + 1


def _check_silent_pass(content: str) -> tuple[bool, str]:
    """Returns (has_silent_pass, message)."""
    p3_match = PATTERN_ASSERT_THEN_GUARD.search(content)
    if p3_match:
        line = _line_for_match(content, p3_match)
        return True, (
            f"Silent-Pass-Pattern P3 erkannt (Zeile ~{line}): "
            f"XCTAssertNotNil gefolgt von 'guard let'. "
            f"Verwende stattdessen 'let x = try XCTUnwrap(...)'."
        )
    p1_match = PATTERN_GUARD_LET_RETURN.search(content)
    if p1_match:
        line = _line_for_match(content, p1_match)
        snippet = p1_match.group(0)[:80].replace("\n", " ")
        return True, (
            f"Silent-Pass-Pattern P1 erkannt (Zeile ~{line}): "
            f"'guard let ... else {{ return }}' lässt Tests still bestehen. "
            f"Verwende 'let x = try XCTUnwrap(...)' oder "
            f"'if let x = ... {{ ... }} else {{ XCTFail(\"...\") }}'. "
            f"Match: {snippet!r}"
        )
    return False, ""


def main():
    if os.environ.get("CLAUDE_ADMIN"):
        sys.exit(0)

    tool_input = _get_tool_input()
    file_path = tool_input.get("file_path", "")

    if not file_path or not _is_test_file(file_path):
        sys.exit(0)

    content = _extract_content(tool_input, file_path)
    if not content:
        sys.exit(0)

    if _has_infra_token():
        sys.exit(0)

    has_issue, message = _check_silent_pass(content)
    if has_issue:
        print(
            f"BLOCKED: {message}\n"
            f"File: {file_path}\n"
            f"Hintergrund: Tests die GREEN melden ohne den Bug auszulösen sind wertlos. "
            f"Siehe CLAUDE.md Section 'Anti-Pattern: Silent-Pass-Tests'.",
            file=sys.stderr,
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
