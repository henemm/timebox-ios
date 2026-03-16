#!/usr/bin/env python3
from __future__ import annotations
"""
OpenSpec Framework - Pre-Commit Gate Hook

Blocks git commits if tests are failing.
Ensures TDD GREEN phase before allowing commits.

Configuration (in config.yaml):
  pre_commit:
    enabled: true
    test_command: ["pytest", "--tb=line", "-q"]  # or ["npm", "test"]
    timeout: 120
    allow_amend: true  # Allow git commit --amend
    ui_patterns:
      - "web/pages/"
      - "templates/"
      - ".vue"
      - ".tsx"
      - ".jsx"
    screenshot_reminder: true  # Remind about screenshots for UI changes

Exit Codes:
- 0: Allowed (with optional JSON response)
- 2: Blocked
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# Try to import config loader
try:
    from config_loader import load_config, get_project_root
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from config_loader import load_config, get_project_root
    except ImportError:
        def load_config():
            return {}
        def get_project_root():
            cwd = Path.cwd()
            for parent in [cwd] + list(cwd.parents):
                if (parent / ".git").exists():
                    return parent
            return cwd


def get_pre_commit_config() -> dict:
    """Get pre-commit configuration with defaults."""
    config = load_config()
    pre_commit = config.get("pre_commit", {})

    return {
        "enabled": pre_commit.get("enabled", True),
        "test_command": pre_commit.get("test_command", ["pytest", "--tb=line", "-q"]),
        "timeout": pre_commit.get("timeout", 120),
        "allow_amend": pre_commit.get("allow_amend", True),
        "ui_patterns": pre_commit.get("ui_patterns", [
            "web/pages/",
            "templates/",
            ".vue",
            ".tsx",
            ".jsx",
            "components/",
            ".svelte",
        ]),
        "screenshot_reminder": pre_commit.get("screenshot_reminder", True),
    }


def get_tool_input() -> dict:
    """Read tool input from stdin or environment."""
    tool_input_str = os.environ.get("CLAUDE_TOOL_INPUT", "")

    if tool_input_str:
        try:
            return json.loads(tool_input_str)
        except json.JSONDecodeError:
            pass

    try:
        data = json.load(sys.stdin)
        return data.get("tool_input", data)
    except (json.JSONDecodeError, EOFError, Exception):
        return {}


def is_git_commit(tool_input: dict, config: dict) -> bool:
    """Check if this is a git commit command."""
    command = tool_input.get("command", "")

    if "git commit" not in command:
        return False

    # Allow amend if configured
    if config["allow_amend"] and "--amend" in command:
        return False

    return True


def run_tests(config: dict) -> tuple[bool, str]:
    """Run tests and return (success, output)."""
    project_root = get_project_root()
    test_command = config["test_command"]
    timeout = config["timeout"]

    # Check if test command executable exists
    try:
        # Try with uv first (Python projects)
        if test_command[0] in ("pytest", "python"):
            full_command = ["uv", "run"] + test_command
        elif test_command[0] in ("npm", "npx", "yarn", "pnpm"):
            full_command = test_command
        else:
            full_command = test_command

        result = subprocess.run(
            full_command,
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=timeout,
        )

        output = result.stdout + result.stderr

        # Check return code and output for failures
        if result.returncode == 0:
            return True, output

        # Some test frameworks return non-zero for various reasons
        # Check output for actual failures
        output_lower = output.lower()
        if "failed" in output_lower or "error" in output_lower:
            return False, output

        # If no failures mentioned, consider it passed
        return True, output

    except subprocess.TimeoutExpired:
        return False, f"Tests timed out after {timeout} seconds"
    except FileNotFoundError as e:
        # Test runner not found - try direct command
        try:
            result = subprocess.run(
                test_command,
                cwd=project_root,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            output = result.stdout + result.stderr
            return result.returncode == 0, output
        except Exception:
            return True, f"Test runner not available: {e}. Allowing commit."
    except Exception as e:
        return False, f"Failed to run tests: {e}"


def check_for_ui_changes(config: dict) -> bool:
    """Check if staged changes include UI files."""
    project_root = get_project_root()
    ui_patterns = config["ui_patterns"]

    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            cwd=project_root,
            capture_output=True,
            text=True,
        )

        files = result.stdout.strip().split("\n")
        return any(
            any(pattern in f for pattern in ui_patterns)
            for f in files if f
        )
    except Exception:
        return False


def check_todos_staged() -> tuple[bool, str]:
    """Check if docs/ACTIVE-todos.md is in the staged files.

    Only blocks if the file has unstaged changes (i.e. was modified but not added).
    If the file is clean (no changes), it's already up-to-date and doesn't need staging.
    """
    project_root = get_project_root()
    try:
        # Check if ACTIVE-todos.md is already staged
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            cwd=project_root,
            capture_output=True,
            text=True,
        )
        staged_files = result.stdout.strip().split("\n")
        if "docs/ACTIVE-todos.md" in staged_files:
            return True, ""

        # Check if it has unstaged modifications
        result2 = subprocess.run(
            ["git", "diff", "--name-only", "--", "docs/ACTIVE-todos.md"],
            cwd=project_root,
            capture_output=True,
            text=True,
        )
        has_unstaged_changes = bool(result2.stdout.strip())

        if has_unstaged_changes:
            return False, "docs/ACTIVE-todos.md hat Aenderungen die nicht staged sind."

        # File is clean — already up-to-date, no need to stage
        return True, ""
    except Exception as e:
        return True, f"Could not check staged files: {e}"


def check_adversary_verdict() -> tuple[bool, str]:
    """
    Check if the implementation-validator (adversary) has verified the fix.

    The adversary agent's job is to TRY TO BREAK the fix.
    Only if it FAILS to break it, the verdict is VERIFIED.

    Verdict is stored in workflow state as adversary_verdict.
    """
    try:
        state = load_workflow_state()
        if not state:
            return True, "No workflow state — skipping adversary check"

        workflows = state.get("workflows", {})
        active_name = state.get("active_workflow")
        if not active_name or active_name not in workflows:
            return True, "No active workflow — skipping adversary check"

        workflow = workflows[active_name]
        phase = workflow.get("current_phase", "phase0_idle")

        # Only require adversary verdict for implementation/complete phases
        if phase not in ("phase6_implement", "phase7_validate", "phase8_complete"):
            return True, f"Phase {phase} doesn't require adversary verdict"

        verdict = workflow.get("adversary_verdict")
        if not verdict:
            return False, f"""
======================================================================
  BLOCKED — Adversary Verification Missing
======================================================================

  Workflow: {active_name}
  Phase: {phase}

  Before committing, you MUST run the implementation-validator agent.
  The agent's job is to PROVE YOUR FIX IS BROKEN.
  Only if it FAILS to break it, you may commit.

  Step 1: Run implementation-validator agent (Task subagent)
    - Read analysis at docs/artifacts/{active_name}/analysis.md
    - Read the diff, check edge cases
    - Run xcodebuild tests, capture output to file
    - Try to BREAK the fix

  Step 2: Feed test output to adversary gate
    python3 .claude/hooks/adversary_gate.py <test-output-file>

  The gate validates REAL test output. No shortcuts.
  set-field adversary_verdict is BLOCKED.

======================================================================"""

        if not verdict.startswith("VERIFIED"):
            return False, f"""
======================================================================
  BLOCKED — Adversary Found Issues
======================================================================

  Verdict: {verdict}

  The adversary agent found problems with your fix.
  Address the issues before committing.
======================================================================"""

        return True, f"Adversary verdict: {verdict}"

    except Exception as e:
        # Don't block on hook errors
        return True, f"Adversary check error: {e}"


def load_workflow_state() -> dict | None:
    """Load workflow state file (same as workflow_state_multi.py uses)."""
    state_file = Path(__file__).parent.parent / "workflow_state.json"
    if not state_file.exists():
        return None
    try:
        with open(state_file, 'r') as f:
            return json.load(f)
    except Exception:
        return None


def main():
    config = get_pre_commit_config()
    tool_input = get_tool_input()

    if not is_git_commit(tool_input, config):
        sys.exit(0)

    # ALWAYS check ACTIVE-todos.md (independent of test config)
    todos_ok, todos_msg = check_todos_staged()
    if not todos_ok:
        print("=" * 70, file=sys.stderr)
        print("BLOCKED - ACTIVE-todos.md nicht aktualisiert", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        print(file=sys.stderr)
        print(todos_msg, file=sys.stderr)
        print(file=sys.stderr)
        print("HARTE REGEL: Vor jedem Commit docs/ACTIVE-todos.md", file=sys.stderr)
        print("aktualisieren (Status, Beschreibung, Commit-Hash).", file=sys.stderr)
        print(file=sys.stderr)
        print("Erst updaten, dann committen.", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        sys.exit(2)

    # CHECK: Adversary verdict required before commit
    adv_ok, adv_msg = check_adversary_verdict()
    if not adv_ok:
        print(adv_msg, file=sys.stderr)
        sys.exit(2)

    # Run tests (only if test gate enabled)
    if not config["enabled"]:
        sys.exit(0)

    success, output = run_tests(config)

    if not success:
        # Extract failure summary
        lines = output.split("\n")
        failures = [l for l in lines if "FAILED" in l or "Error" in l or "FAIL" in l]
        summary = "\n".join(failures[:5]) if failures else "Tests failed"

        print("=" * 70, file=sys.stderr)
        print("BLOCKED - Pre-Commit Gate", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        print(file=sys.stderr)
        print("Tests must pass before committing (TDD-GREEN).", file=sys.stderr)
        print(file=sys.stderr)
        print("Failures:", file=sys.stderr)
        print(summary, file=sys.stderr)
        print(file=sys.stderr)
        print("Fix tests first, then commit.", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        sys.exit(2)

    # Check for UI changes - remind about screenshot
    if config["screenshot_reminder"] and check_for_ui_changes(config):
        # Don't block, just output reminder
        print("Note: UI changes detected. Consider adding screenshot artifacts.", file=sys.stderr)

    # Clean up override token after successful commit gate pass
    token_path = Path(__file__).parent.parent / "user_override_token.json"
    if token_path.exists():
        try:
            token_path.unlink()
        except OSError:
            pass

    sys.exit(0)


if __name__ == "__main__":
    main()
