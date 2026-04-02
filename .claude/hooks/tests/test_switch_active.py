#!/usr/bin/env python3
"""Tests for Bug #192: workflow.py switch must ALWAYS update .active symlink.

Root Cause: _set_active() skips .active update when CLAUDE_SESSION_ID is set
(line 247: `if not session_id:`). Since SessionStart hook ALWAYS sets the
env var, .active is NEVER updated after switch.

Fix: Remove the `if not session_id:` guard — .active is always updated.
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Add hooks dir to path
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestSwitchUpdatesActive(unittest.TestCase):
    """_set_active() must ALWAYS update .active symlink, even with session_id."""

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

    def test_set_active_updates_symlink_with_session_id(self):
        """_set_active() must create .active symlink EVEN when session_id is set.

        Bricht wenn: workflow.py:247 `if not session_id:` verhindert .active-Update.
        Root Cause von Bug #192.
        """
        import workflow

        wf_file = self.wf_dir / "new-workflow.json"
        wf_file.write_text(json.dumps({"name": "new-workflow"}))

        with patch.object(workflow, "_get_session_id", return_value="session-abc"):
            workflow._set_active("new-workflow")

        # .active MUST exist and point to new-workflow.json
        self.assertTrue(
            self.active_link.is_symlink(),
            ".active symlink must be created even when session_id is set"
        )
        target = os.readlink(str(self.active_link))
        self.assertEqual(target, "new-workflow.json",
                         ".active must point to the switched workflow")

    def test_switch_updates_both_sessions_and_active(self):
        """switch must update BOTH .sessions.json AND .active symlink.

        Bricht wenn: _set_active() nur eine der beiden Quellen aktualisiert.
        """
        import workflow

        wf_file = self.wf_dir / "target-wf.json"
        wf_file.write_text(json.dumps({"name": "target-wf"}))

        with patch.object(workflow, "_get_session_id", return_value="session-xyz"):
            workflow._set_active("target-wf")

        # Check .sessions.json
        sessions = json.loads(self.sessions_file.read_text())
        self.assertEqual(sessions.get("session-xyz"), "target-wf",
                         ".sessions.json must be updated")

        # Check .active symlink
        self.assertTrue(self.active_link.is_symlink(),
                        ".active must also be updated")
        target = os.readlink(str(self.active_link))
        self.assertEqual(target, "target-wf.json",
                         ".active must point to target-wf.json")

    def test_switch_overwrites_stale_active(self):
        """switch must replace a stale .active pointing to old workflow.

        Bricht wenn: .active bleibt auf altem Workflow nach switch.
        Reproduziert das exakte Symptom aus Issue #192.
        """
        import workflow

        # Setup: old workflow with .active pointing to it
        old_wf = self.wf_dir / "old-workflow.json"
        old_wf.write_text(json.dumps({"name": "old-workflow"}))
        os.symlink("old-workflow.json", str(self.active_link))

        # New workflow
        new_wf = self.wf_dir / "new-workflow.json"
        new_wf.write_text(json.dumps({"name": "new-workflow"}))

        # Switch with session_id set (the Bug #192 scenario)
        with patch.object(workflow, "_get_session_id", return_value="session-123"):
            workflow._set_active("new-workflow")

        # .active must now point to new-workflow.json, NOT old-workflow.json
        target = os.readlink(str(self.active_link))
        self.assertEqual(target, "new-workflow.json",
                         ".active must be updated from old-workflow.json to new-workflow.json")


if __name__ == "__main__":
    unittest.main()
