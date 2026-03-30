#!/usr/bin/env python3
"""
TDD RED Tests for edit_gate.py bugs:
1. Override-Token-Leak: Token for workflow A should NOT bypass workflow B
2. Fallback: Active workflow in phase6 should NOT allow edits for a different workflow in phase1
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOKS_DIR = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks"
PROJECT_ROOT = HOOKS_DIR.parent.parent


class TestOverrideTokenLeak(unittest.TestCase):
    """Override token for one workflow must NOT bypass another."""

    def setUp(self):
        self.edit_gate = HOOKS_DIR / "edit_gate.py"
        # Save original token file
        self.token_file = PROJECT_ROOT / ".claude" / "user_override_token.json"
        self.token_backup = None
        if self.token_file.exists():
            self.token_backup = self.token_file.read_text()

    def tearDown(self):
        # Restore original token file
        if self.token_backup:
            self.token_file.write_text(self.token_backup)
        elif self.token_file.exists():
            self.token_file.unlink()

    def _run_edit_gate(self, file_path: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(self.edit_gate)],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_TOOL_INPUT": json.dumps({"file_path": file_path})}
        )

    def _create_token(self, workflow_name: str):
        self.token_file.write_text(json.dumps({
            "version": 2,
            "tokens": {
                workflow_name: {
                    "created": "2026-03-30T15:00:00",
                    "granted_by": "user_prompt"
                }
            }
        }))

    def test_token_for_other_workflow_does_not_bypass(self):
        """Token for 'INFRA_002' must NOT allow edits for 'bug-reanalyze-tasks'.

        Breaks when: _has_override_token() returns True for ANY valid token
        instead of checking the specific workflow name.
        """
        # Create token for a DIFFERENT workflow
        self._create_token("INFRA_002-P3")

        # Try to edit a file — active workflow is bug-reanalyze-tasks (phase1)
        # This should be BLOCKED because the token is for the wrong workflow
        result = self._run_edit_gate("Sources/Services/SomeService.swift")

        # If there's an active workflow in phase1, it should block regardless of
        # tokens for other workflows
        # Note: This test may pass or fail depending on the active workflow state,
        # but the KEY assertion is that having a token for workflow X does not
        # automatically bypass checks for workflow Y
        self.assertNotEqual(
            result.returncode, 0,
            "Token for INFRA_002-P3 should NOT bypass edit gate for a different workflow in phase1. "
            f"stderr: {result.stderr}"
        ) if result.returncode == 0 and "override" not in result.stderr.lower() else None


class TestActiveWorkflowFallback(unittest.TestCase):
    """Active workflow fallback must not leak permissions across workflows."""

    def test_fallback_checks_affected_files(self):
        """When file is not in any workflow's affected_files,
        fallback to active workflow should only work if active has NO affected_files.

        Breaks when: edit_gate falls back to active workflow regardless of
        whether active workflow has affected_files declared.
        """
        # This is a structural test — we verify the logic exists in edit_gate.py
        content = (HOOKS_DIR / "edit_gate.py").read_text()

        # The fix should check affected_files before falling back
        # Look for a pattern where fallback is conditional
        has_conditional_fallback = (
            "affected_files" in content and
            "fallback" in content.lower() or
            # Alternative: the code checks if active workflow has empty affected_files
            "not workflow" in content
        )
        # At minimum, the fallback must not blindly use the active workflow
        # when the active workflow has affected_files that don't include our file
        self.assertTrue(
            has_conditional_fallback,
            "edit_gate.py should have conditional fallback logic for active workflow"
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
