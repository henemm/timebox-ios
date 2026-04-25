#!/usr/bin/env python3
"""Tests for INFRA_016 — Silent-Pass-Hardening.

Verifiziert drei unabhängige Mechanismen die verhindern dass Tests
GREEN melden ohne den Bug auszulösen:

A) test_quality_gate.py blockiert Silent-Pass-Patterns beim Schreiben
B) qa_gate.py --hook-mode blockiert ungültige Test-Outputs vor mark-red/green
C) adversary.md + implementation-validator.md enthalten Pre-Fix-Validation
D) Doku-Updates in qa-writer.md, developer.md, CLAUDE.md
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent.parent
HOOKS_DIR = PROJECT_ROOT / ".claude" / "hooks"
AGENTS_DIR = PROJECT_ROOT / ".claude" / "agents"
COMMANDS_DIR = PROJECT_ROOT / ".claude" / "commands"


def _clean_env(extra: dict | None = None) -> dict:
    """Build env without CLAUDE_ADMIN (which would deactivate all hooks)."""
    env = {k: v for k, v in os.environ.items() if k != "CLAUDE_ADMIN"}
    if extra:
        env.update(extra)
    return env


def _run_hook(hook_path: Path, tool_input: dict) -> tuple[int, str, str]:
    """Run a hook with given tool input. Returns (exit_code, stdout, stderr).

    Raises if hook file doesn't exist — prevents Silent-Pass when Python
    returns Exit 2 for missing files (which would coincidentally match
    "blocked" expectations).
    """
    if not hook_path.exists():
        raise FileNotFoundError(
            f"Hook not found: {hook_path}. Cannot test behavior of missing hook."
        )
    payload = json.dumps({"tool_input": tool_input})
    result = subprocess.run(
        [sys.executable, str(hook_path)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=10,
        env=_clean_env({"CLAUDE_TOOL_INPUT": json.dumps(tool_input)}),
    )
    return result.returncode, result.stdout, result.stderr


# ============================================================================
# Maßnahme A — test_quality_gate.py (Silent-Pass-Detector)
# ============================================================================


class TestQualityGateBlocksSilentPass(unittest.TestCase):
    """Tests that test_quality_gate.py blocks Silent-Pass-Patterns."""

    def setUp(self):
        self.hook = HOOKS_DIR / "test_quality_gate.py"
        # Token vorübergehend entfernen, damit blocking-Tests echte Hook-Logik prüfen.
        # Test 'respects_infra_token' setzt es selbst wieder.
        self.token_file = PROJECT_ROOT / ".claude" / "user_override_token.json"
        self._saved_token = None
        if self.token_file.exists():
            self._saved_token = self.token_file.read_text()
            try:
                data = json.loads(self._saved_token)
                if "__infra__" in data.get("tokens", {}):
                    del data["tokens"]["__infra__"]
                    self.token_file.write_text(json.dumps(data, indent=2))
            except (json.JSONDecodeError, OSError):
                pass

    def tearDown(self):
        if self._saved_token is not None:
            self.token_file.write_text(self._saved_token)

    def test_silent_pass_hook_blocks_guard_let_return(self):
        """P1: guard let ... else { return } in Test-File → Exit 2."""
        content = '''import XCTest
final class FooTests: XCTestCase {
    func test_foo() throws {
        let app = XCUIApplication()
        guard let button = app.buttons["bar"].firstMatch as? XCUIElement else { return }
        button.tap()
    }
}
'''
        exit_code, _, stderr = _run_hook(self.hook, {
            "file_path": "FocusBloxUITests/FooTests.swift",
            "content": content,
        })
        self.assertEqual(exit_code, 2,
                         f"Expected Exit 2 (blocked), got {exit_code}. stderr={stderr}")

    def test_silent_pass_hook_allows_xctunwrap(self):
        """XCTUnwrap statt guard let → durchgelassen."""
        content = '''import XCTest
final class FooTests: XCTestCase {
    func test_foo() throws {
        let app = XCUIApplication()
        let button = try XCTUnwrap(app.buttons["bar"].firstMatch)
        button.tap()
    }
}
'''
        exit_code, _, stderr = _run_hook(self.hook, {
            "file_path": "FocusBloxUITests/FooTests.swift",
            "content": content,
        })
        self.assertEqual(exit_code, 0,
                         f"Expected Exit 0 (allowed), got {exit_code}. stderr={stderr}")

    def test_silent_pass_hook_allows_if_let_with_xctfail(self):
        """if let mit else { XCTFail } → durchgelassen."""
        content = '''import XCTest
final class FooTests: XCTestCase {
    func test_foo() throws {
        let app = XCUIApplication()
        if let button = app.buttons["bar"].firstMatch as? XCUIElement {
            button.tap()
        } else {
            XCTFail("button not found")
        }
    }
}
'''
        exit_code, _, stderr = _run_hook(self.hook, {
            "file_path": "FocusBloxUITests/FooTests.swift",
            "content": content,
        })
        self.assertEqual(exit_code, 0,
                         f"Expected Exit 0 (allowed), got {exit_code}. stderr={stderr}")

    def test_silent_pass_hook_skips_non_test_files(self):
        """Sources/Foo.swift mit guard let return → durchgelassen (Production-Code)."""
        content = '''import Foundation
struct Foo {
    func bar() {
        guard let x = self.optional else { return }
        print(x)
    }
}
'''
        exit_code, _, stderr = _run_hook(self.hook, {
            "file_path": "Sources/Foo.swift",
            "content": content,
        })
        self.assertEqual(exit_code, 0,
                         f"Expected Exit 0 (non-test file), got {exit_code}. stderr={stderr}")

    def test_silent_pass_hook_respects_infra_token(self):
        """Mit __infra__-Token im user_override_token.json → durchgelassen."""
        # setUp hat das Token bereits entfernt; jetzt setzen wir es im v2-Format
        token_file = PROJECT_ROOT / ".claude" / "user_override_token.json"
        token_file.write_text(json.dumps({
            "version": 2,
            "tokens": {"__infra__": {"granted_by": "test"}},
        }))
        content = '''import XCTest
final class FooTests: XCTestCase {
    func test_foo() throws {
        let app = XCUIApplication()
        guard let button = app.buttons["bar"].firstMatch as? XCUIElement else { return }
        button.tap()
    }
}
'''
        exit_code, _, stderr = _run_hook(self.hook, {
            "file_path": "FocusBloxUITests/FooTests.swift",
            "content": content,
        })
        self.assertEqual(exit_code, 0,
                         f"Expected Exit 0 (infra-token bypass), got {exit_code}. stderr={stderr}")
        # tearDown stellt original wieder her


# ============================================================================
# Maßnahme B — qa_gate.py --hook-mode
# ============================================================================


class TestQaGateHookMode(unittest.TestCase):
    """Tests that qa_gate.py --hook-mode validates test output before mark-red/green."""

    def setUp(self):
        self.hook = HOOKS_DIR / "qa_gate.py"

    def _run_hook_mode(self, command: str) -> tuple[int, str, str]:
        if not self.hook.exists():
            raise FileNotFoundError(f"Hook not found: {self.hook}")
        result = subprocess.run(
            [sys.executable, str(self.hook), "--hook-mode"],
            input=json.dumps({"command": command}),
            capture_output=True,
            text=True,
            timeout=10,
            env=_clean_env({"CLAUDE_TOOL_INPUT": json.dumps({"command": command})}),
        )
        if "Hook-Mode requires" in result.stderr or "unrecognized arguments" in result.stderr:
            self.fail(
                f"qa_gate.py does not support --hook-mode flag yet. stderr={result.stderr}"
            )
        if "--hook-mode" in result.stderr and result.returncode == 2:
            self.fail(f"qa_gate.py rejected --hook-mode flag: {result.stderr}")
        return result.returncode, result.stdout, result.stderr

    def test_qa_gate_hook_mode_blocks_invalid_output(self):
        """mark-red mit nicht-existentem Output-File → Exit 2."""
        cmd = f"{sys.executable} {HOOKS_DIR}/workflow.py mark-red /tmp/nonexistent_output_xyz.txt"
        exit_code, _, stderr = self._run_hook_mode(cmd)
        self.assertEqual(exit_code, 2,
                         f"Expected Exit 2 (invalid output), got {exit_code}. stderr={stderr}")

    def test_qa_gate_hook_mode_allows_valid_output(self):
        """mark-red mit echtem XCTest-Output → Exit 0."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write(
                "Test Suite 'FocusBloxTests' started.\n"
                "Test Case 'test_foo' passed.\n"
                "Test Suite 'FocusBloxUITests' started.\n"
                "Test Case 'test_ui' passed.\n"
                "Executed 2 tests, with 0 failures (0 unexpected) in 0.5 seconds\n"
                + ("." * 500)
            )
            output_file = f.name
        try:
            cmd = f"{sys.executable} {HOOKS_DIR}/workflow.py mark-red {output_file}"
            exit_code, _, stderr = self._run_hook_mode(cmd)
            self.assertEqual(exit_code, 0,
                             f"Expected Exit 0 (valid output), got {exit_code}. stderr={stderr}")
        finally:
            os.unlink(output_file)

    def test_qa_gate_hook_mode_passes_unrelated_bash(self):
        """Bash ohne mark-red/green → Exit 0 (passthrough)."""
        cmd = "git status"
        exit_code, _, stderr = self._run_hook_mode(cmd)
        self.assertEqual(exit_code, 0,
                         f"Expected Exit 0 (passthrough), got {exit_code}. stderr={stderr}")


# ============================================================================
# Maßnahme C — Adversary + Validator Pre-Fix-Validation
# ============================================================================


class TestAdversaryPreFixValidation(unittest.TestCase):
    """Tests that adversary.md + implementation-validator.md require Pre-Fix-Validation."""

    def test_adversary_md_has_pre_fix_phase(self):
        """adversary.md enthält 'Phase 3b: Pre-Fix-Test-Validation'."""
        content = (COMMANDS_DIR / "adversary.md").read_text()
        self.assertIn("Phase 3b: Pre-Fix-Test-Validation", content,
                      "adversary.md fehlt: Pflicht-Phase 'Phase 3b: Pre-Fix-Test-Validation'")

    def test_adversary_md_has_before_after_table(self):
        """adversary.md enthält 'Vor Fix' Tabellen-Header für Pre-Fix-Reporting."""
        content = (COMMANDS_DIR / "adversary.md").read_text()
        self.assertIn("Vor Fix", content,
                      "adversary.md fehlt: Tabellen-Header 'Vor Fix' für Pre-Fix-Reporting")

    def test_validator_md_has_test_quality_audit(self):
        """implementation-validator.md enthält 'Test-Quality-Audit' als Standard-Schritt."""
        content = (AGENTS_DIR / "implementation-validator.md").read_text()
        self.assertIn("Test-Quality-Audit", content,
                      "implementation-validator.md fehlt: 'Test-Quality-Audit' Schritt")

    def test_validator_md_forbids_green_as_proof(self):
        """implementation-validator.md Verboten-Liste enthält Eintrag gegen 'GREEN als Beweis'."""
        content = (AGENTS_DIR / "implementation-validator.md").read_text()
        self.assertIn("Tests sind grün", content,
                      "implementation-validator.md fehlt: Verbot 'Tests sind grün als Beweis für Fix'")


# ============================================================================
# Maßnahme D — Doku-Updates
# ============================================================================


class TestDocumentationUpdates(unittest.TestCase):
    """Tests that agent prompts and CLAUDE.md document the Silent-Pass anti-pattern."""

    def test_qa_writer_md_forbids_silent_pass(self):
        """qa-writer.md Verbots-Liste enthält 'guard let ... else { return }'."""
        content = (AGENTS_DIR / "qa-writer.md").read_text()
        self.assertIn("guard let", content,
                      "qa-writer.md fehlt: Verbot von 'guard let ... else { return }' in Tests")

    def test_developer_md_handles_silent_pass_blocker(self):
        """developer.md enthält Anweisung 'BLOCKER an Orchestrator melden'."""
        content = (AGENTS_DIR / "developer.md").read_text()
        self.assertIn("Silent-Pass", content,
                      "developer.md fehlt: Anweisung wie mit Silent-Pass-Tests umzugehen ist")

    def test_claude_md_has_anti_pattern_section(self):
        """CLAUDE.md enthält Section 'Anti-Pattern: Silent-Pass-Tests'."""
        content = (PROJECT_ROOT / "CLAUDE.md").read_text()
        self.assertIn("Silent-Pass", content,
                      "CLAUDE.md fehlt: Anti-Pattern-Section zu Silent-Pass-Tests")


# ============================================================================
# Settings.json Registration
# ============================================================================


class TestHookRegistration(unittest.TestCase):
    """Tests that settings.json registers both new hooks."""

    def setUp(self):
        self.settings = json.loads((PROJECT_ROOT / ".claude" / "settings.json").read_text())

    def test_settings_json_registers_test_quality_gate(self):
        """settings.json registriert test_quality_gate.py als Edit|Write Hook."""
        edit_hooks = []
        for entry in self.settings.get("hooks", {}).get("PreToolUse", []):
            if entry.get("matcher") == "Edit|Write":
                edit_hooks.extend(h.get("command", "") for h in entry.get("hooks", []))
        self.assertTrue(any("test_quality_gate.py" in h for h in edit_hooks),
                        f"settings.json fehlt: test_quality_gate.py nicht in Edit|Write Hooks. "
                        f"Found: {edit_hooks}")

    def test_settings_json_registers_qa_gate_hook_mode(self):
        """settings.json registriert qa_gate.py --hook-mode als Bash Hook."""
        bash_hooks = []
        for entry in self.settings.get("hooks", {}).get("PreToolUse", []):
            if entry.get("matcher") == "Bash":
                bash_hooks.extend(h.get("command", "") for h in entry.get("hooks", []))
        self.assertTrue(any("qa_gate.py" in h and "--hook-mode" in h for h in bash_hooks),
                        f"settings.json fehlt: qa_gate.py --hook-mode nicht in Bash Hooks. "
                        f"Found: {bash_hooks}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
