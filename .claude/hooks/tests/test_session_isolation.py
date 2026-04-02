#!/usr/bin/env python3
"""Tests for session isolation fix (BUG_session_isolation).

Tests verify that:
1. Hooks extract session_id from stdin JSON (not just os.environ)
2. _set_active() does NOT write .active symlink when session_id is present
3. _get_session_id() falls back correctly: env → stdin → PPID
"""

import json
import os
import sys
import tempfile
import unittest
from io import StringIO
from pathlib import Path
from unittest.mock import patch

# Add hooks dir to path so we can import modules
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestBashGateSessionId(unittest.TestCase):
    """bash_gate.py must extract session_id from stdin JSON."""

    def test_session_id_extracted_from_stdin(self):
        """session_id from stdin JSON should be available to _get_session_id().

        Bricht wenn: bash_gate.py:115-116 session_id nicht aus stdin extrahiert.
        EXPECTED TO FAIL: _STDIN_SESSION_ID does not exist yet.
        """
        import bash_gate

        # Verify that bash_gate has a _STDIN_SESSION_ID variable or mechanism
        # to store session_id from stdin
        self.assertTrue(
            hasattr(bash_gate, "_STDIN_SESSION_ID"),
            "bash_gate must have _STDIN_SESSION_ID module variable"
        )

    def test_get_session_id_uses_stdin_fallback(self):
        """_get_session_id() should use stdin session_id when env var is empty.

        Bricht wenn: bash_gate.py:175-180 _get_session_id() ignores _STDIN_SESSION_ID.
        EXPECTED TO FAIL: _get_session_id() does not read _STDIN_SESSION_ID.
        """
        import bash_gate

        # Clear env var
        with patch.dict(os.environ, {}, clear=True):
            # Set the stdin session_id (once the fix exists)
            if hasattr(bash_gate, "_STDIN_SESSION_ID"):
                old_val = bash_gate._STDIN_SESSION_ID
                bash_gate._STDIN_SESSION_ID = "test-session-abc"
                try:
                    result = bash_gate._get_session_id()
                    self.assertEqual(result, "session:test-session-abc",
                                     "_get_session_id must use _STDIN_SESSION_ID as fallback")
                finally:
                    bash_gate._STDIN_SESSION_ID = old_val
            else:
                self.fail("bash_gate._STDIN_SESSION_ID does not exist")


class TestEditGateSessionId(unittest.TestCase):
    """edit_gate.py must extract session_id from stdin JSON."""

    def test_session_id_extracted_from_stdin(self):
        """session_id from stdin JSON should be available in edit_gate.

        Bricht wenn: edit_gate.py:226-227 session_id nicht aus stdin extrahiert.
        EXPECTED TO FAIL: _STDIN_SESSION_ID does not exist yet.
        """
        import edit_gate

        self.assertTrue(
            hasattr(edit_gate, "_STDIN_SESSION_ID"),
            "edit_gate must have _STDIN_SESSION_ID module variable"
        )


class TestPostBashSessionId(unittest.TestCase):
    """post_bash.py must extract session_id from stdin JSON."""

    def test_session_id_extracted_from_stdin(self):
        """session_id from stdin JSON should be available in post_bash.

        Bricht wenn: post_bash.py:108-109 session_id nicht aus stdin extrahiert.
        EXPECTED TO FAIL: _STDIN_SESSION_ID does not exist yet.
        """
        import post_bash

        self.assertTrue(
            hasattr(post_bash, "_STDIN_SESSION_ID"),
            "post_bash must have _STDIN_SESSION_ID module variable"
        )


class TestSetActiveSymlinkBehavior(unittest.TestCase):
    """workflow.py:_set_active() must NOT write .active when session_id exists."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)
        self.sessions_file = self.wf_dir / ".sessions.json"
        self.sessions_file.write_text("{}")
        self.active_link = self.wf_dir / ".active"

        import workflow
        self._patcher_wfdir = patch.object(workflow, "_workflows_dir", return_value=self.wf_dir)
        self._patcher_wfdir.start()

    def tearDown(self):
        self._patcher_wfdir.stop()
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_set_active_writes_symlink_always(self):
        """_set_active() must ALWAYS create .active symlink (Bug #192 fix).

        .active is always updated for backward compat + debugging.
        .sessions.json remains source of truth for session-aware tools.
        """
        import workflow

        # Create the workflow file so it's valid
        wf_file = self.wf_dir / "test-workflow.json"
        wf_file.write_text(json.dumps({"name": "test-workflow"}))

        with patch.object(workflow, "_get_session_id", return_value="session-xyz"):
            workflow._set_active("test-workflow")

        # .active symlink MUST exist even when session_id is present
        self.assertTrue(
            self.active_link.is_symlink(),
            ".active symlink must be created even when session_id is present (Bug #192)"
        )

    def test_set_active_writes_symlink_when_no_session_id(self):
        """_set_active() must create .active symlink when session_id is empty (legacy).

        Bricht wenn: workflow.py _set_active() nie .active schreibt.
        EXPECTED TO PASS: Current behavior already does this.
        """
        import workflow

        wf_file = self.wf_dir / "test-workflow.json"
        wf_file.write_text(json.dumps({"name": "test-workflow"}))

        with patch.object(workflow, "_get_session_id", return_value=""):
            workflow._set_active("test-workflow")

        self.assertTrue(
            self.active_link.is_symlink(),
            ".active symlink must be created when session_id is empty (backward compat)"
        )

    def test_set_active_writes_sessions_json_with_session_id(self):
        """_set_active() must write to .sessions.json when session_id is set.

        Bricht wenn: workflow.py:242-244 sessions mapping nicht geschrieben wird.
        EXPECTED TO PASS: This already works (but only if session_id is non-empty).
        """
        import workflow

        wf_file = self.wf_dir / "test-workflow.json"
        wf_file.write_text(json.dumps({"name": "test-workflow"}))

        with patch.object(workflow, "_get_session_id", return_value="session-xyz"):
            workflow._set_active("test-workflow")

        sessions = json.loads(self.sessions_file.read_text())
        self.assertEqual(sessions.get("session-xyz"), "test-workflow",
                         ".sessions.json must contain session mapping")


class TestSettingsJsonHasSessionStart(unittest.TestCase):
    """settings.json must have SessionStart hook registered."""

    def test_session_start_hook_registered(self):
        """settings.json must include a SessionStart hook entry.

        Bricht wenn: settings.json hat keinen SessionStart-Eintrag.
        EXPECTED TO FAIL: SessionStart is not registered.
        """
        settings_path = Path(__file__).parent.parent.parent / "settings.json"
        self.assertTrue(settings_path.exists(), f"settings.json not found at {settings_path}")

        settings = json.loads(settings_path.read_text())
        hooks = settings.get("hooks", {})

        self.assertIn("SessionStart", hooks,
                       "settings.json must have a SessionStart hook entry")

        session_start_hooks = hooks["SessionStart"]
        self.assertTrue(len(session_start_hooks) > 0,
                        "SessionStart must have at least one hook configured")

        # Verify it points to session_start.py
        commands = []
        for entry in session_start_hooks:
            for hook in entry.get("hooks", []):
                commands.append(hook.get("command", ""))

        self.assertTrue(
            any("session_start.py" in cmd for cmd in commands),
            "SessionStart hook must run session_start.py"
        )


if __name__ == "__main__":
    unittest.main()
