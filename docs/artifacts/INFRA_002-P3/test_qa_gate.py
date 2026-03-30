#!/usr/bin/env python3
"""
TDD RED Tests for INFRA_002-P3 — QA Gate

Tests MUST FAIL because qa_gate.py doesn't exist yet.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOKS_DIR = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks"


class TestQaGateExists(unittest.TestCase):
    """qa_gate.py must exist as replacement for adversary_gate.py.

    Breaks when: .claude/hooks/qa_gate.py is not created yet.
    """
    def test_qa_gate_exists(self):
        self.assertTrue(
            (HOOKS_DIR / "qa_gate.py").exists(),
            "qa_gate.py does not exist"
        )


class TestQaGateValidation(unittest.TestCase):
    """QA Gate validates test output before setting verdict."""

    def setUp(self):
        self.qa_gate = HOOKS_DIR / "qa_gate.py"
        self.tmpdir = tempfile.mkdtemp()

    def _write_test_output(self, content: str) -> str:
        path = os.path.join(self.tmpdir, "test_output.txt")
        with open(path, "w") as f:
            f.write(content)
        return path

    def _run_gate(self, *args) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(self.qa_gate)] + list(args),
            capture_output=True, text=True
        )

    def test_rejects_empty_file(self):
        """Rejects empty/tiny test output.

        Breaks when: qa_gate.py doesn't validate file size.
        """
        path = self._write_test_output("small")
        result = self._run_gate(path)
        self.assertNotEqual(result.returncode, 0, "Should reject tiny file")

    def test_rejects_no_test_patterns(self):
        """Rejects file without test suite patterns.

        Breaks when: qa_gate.py doesn't check for test patterns.
        """
        path = self._write_test_output("x" * 600)  # big enough but no patterns
        result = self._run_gate(path)
        self.assertNotEqual(result.returncode, 0, "Should reject file without test patterns")

    def test_accepts_valid_output(self):
        """Accepts valid test output with both test targets.

        Breaks when: qa_gate.py doesn't recognize valid xcodebuild output.
        """
        content = """Test Suite 'FocusBloxTests.SomeTests' started at 2026-03-30.
Test Case '-[FocusBloxTests.SomeTests test_something]' passed (0.01 seconds).
Test Suite 'FocusBloxUITests.SomeUITests' started at 2026-03-30.
Test Case '-[FocusBloxUITests.SomeUITests test_ui]' passed (0.05 seconds).
\t Executed 2 tests, with 0 failures (0 unexpected) in 0.06 seconds
** TEST SUCCEEDED **"""
        path = self._write_test_output(content)
        result = self._run_gate(path, "--no-visual", "test only")
        self.assertEqual(result.returncode, 0,
            f"Should accept valid output. stderr: {result.stderr}")

    def test_infra_flag_skips_target_check(self):
        """--infra flag accepts Python test output without FocusBlox targets.

        Breaks when: qa_gate.py doesn't support --infra flag.
        """
        content = """Test Suite 'InfraTests' started at 2026-03-30.
Test Case '-[InfraTests test_workflow]' passed (0.01 seconds).
\t Executed 1 tests, with 0 failures (0 unexpected) in 0.01 seconds
** TEST SUCCEEDED **"""
        path = self._write_test_output(content)
        result = self._run_gate(path, "--infra", "--no-visual", "infra test")
        self.assertEqual(result.returncode, 0,
            f"--infra should skip target check. stderr: {result.stderr}")


class TestBrokenReferencesFixed(unittest.TestCase):
    """Old adversary_gate.py references must be replaced."""

    def test_implementation_validator_no_old_refs(self):
        """implementation-validator.md must not reference workflow_state_multi.

        Breaks when: Agent file still has old imports.
        """
        agent = HOOKS_DIR.parent / "agents" / "implementation-validator.md"
        content = agent.read_text()
        self.assertNotIn("workflow_state_multi", content,
            "implementation-validator.md still references workflow_state_multi")

    def test_implement_command_no_old_refs(self):
        """05-implement.md must not reference adversary_gate.py.

        Breaks when: Command file still has old hook name.
        """
        cmd = HOOKS_DIR.parent / "commands" / "05-implement.md"
        content = cmd.read_text()
        self.assertNotIn("adversary_gate.py", content,
            "05-implement.md still references adversary_gate.py")


if __name__ == "__main__":
    unittest.main(verbosity=2)
