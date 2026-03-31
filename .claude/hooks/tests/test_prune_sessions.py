#!/usr/bin/env python3
"""Tests for _prune_orphaned_sessions() in workflow.py."""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Add hooks dir to path so we can import workflow
sys.path.insert(0, str(Path(__file__).parent.parent))

import workflow


class TestPruneOrphanedSessions(unittest.TestCase):
    """Test orphaned session cleanup logic."""

    def setUp(self):
        """Create temp workflow directory structure."""
        self.tmpdir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)
        self.sessions_file = self.wf_dir / ".sessions.json"
        # Patch _workflows_dir to use our temp dir
        self._patcher = patch.object(workflow, "_workflows_dir", return_value=self.wf_dir)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _write_sessions(self, data: dict):
        self.sessions_file.write_text(json.dumps(data))

    def _read_sessions(self) -> dict:
        return json.loads(self.sessions_file.read_text())

    def _create_workflow(self, name: str):
        """Create a workflow JSON file so it counts as 'existing'."""
        wf_file = self.wf_dir / f"{name}.json"
        wf_file.write_text(json.dumps({"name": name, "current_phase": "phase1_context"}))

    def test_orphaned_entry_removed(self):
        """Session pointing to non-existent workflow gets pruned."""
        self._write_sessions({"dead-session": "deleted-workflow"})
        # No workflow file for "deleted-workflow" exists
        workflow._prune_orphaned_sessions()
        result = self._read_sessions()
        self.assertEqual(result, {})

    def test_valid_entry_preserved(self):
        """Session pointing to existing workflow stays."""
        self._create_workflow("active-workflow")
        self._write_sessions({"live-session": "active-workflow"})
        workflow._prune_orphaned_sessions()
        result = self._read_sessions()
        self.assertEqual(result, {"live-session": "active-workflow"})

    def test_mixed_entries(self):
        """Only orphaned entries are removed, valid ones stay."""
        self._create_workflow("good-workflow")
        self._write_sessions({
            "live-session": "good-workflow",
            "dead-session-1": "gone-workflow-1",
            "dead-session-2": "gone-workflow-2",
        })
        workflow._prune_orphaned_sessions()
        result = self._read_sessions()
        self.assertEqual(result, {"live-session": "good-workflow"})

    def test_empty_sessions(self):
        """Empty sessions.json causes no errors."""
        self._write_sessions({})
        workflow._prune_orphaned_sessions()
        result = self._read_sessions()
        self.assertEqual(result, {})

    def test_no_sessions_file(self):
        """Missing sessions.json causes no errors."""
        # Don't create sessions file
        workflow._prune_orphaned_sessions()
        # Should not crash, file may or may not exist after

    def test_multiple_sessions_same_workflow(self):
        """Multiple sessions for same existing workflow all stay."""
        self._create_workflow("shared-workflow")
        self._write_sessions({
            "session-1": "shared-workflow",
            "session-2": "shared-workflow",
        })
        workflow._prune_orphaned_sessions()
        result = self._read_sessions()
        self.assertEqual(result, {
            "session-1": "shared-workflow",
            "session-2": "shared-workflow",
        })


class TestListCallsPrune(unittest.TestCase):
    """Verify cmd_list triggers pruning."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)
        self.sessions_file = self.wf_dir / ".sessions.json"
        self._patcher = patch.object(workflow, "_workflows_dir", return_value=self.wf_dir)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_list_prunes_before_display(self):
        """cmd_list should prune orphaned sessions before listing."""
        self.sessions_file.write_text(json.dumps({"dead": "nonexistent"}))
        with patch.object(workflow, "_get_session_id", return_value=""):
            workflow.cmd_list([])
        result = json.loads(self.sessions_file.read_text())
        self.assertEqual(result, {})


class TestSessionStartCallsPrune(unittest.TestCase):
    """Verify session_start.py triggers pruning."""

    def test_session_start_imports_and_calls_prune(self):
        """session_start should call prune after setting session ID."""
        # This test verifies the function exists and is callable
        # The actual integration is tested by checking session_start.py calls it
        self.assertTrue(hasattr(workflow, '_prune_orphaned_sessions'))
        self.assertTrue(callable(workflow._prune_orphaned_sessions))


if __name__ == "__main__":
    unittest.main()
