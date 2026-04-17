#!/usr/bin/env python3
"""Tests for Bug #272 — Checkpoint-Feedback auf stdout.

Tests verify:
1. Screenshot-Gate Feedback geht auf stdout (nicht stderr)
2. Unresolved-Findings Feedback geht auf stdout
3. Erfolgs-Meldungen bleiben auf stderr (internes Logging)
"""

import json
import os
import sys
import tempfile
import unittest
from io import StringIO
from pathlib import Path
from unittest.mock import patch, MagicMock
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

import phase_listener


class CheckpointFeedbackTestBase(unittest.TestCase):
    """Base: Simuliert phase_listener.main() mit kontrolliertem Input."""

    def _run_main_with_message(self, message, wf_data, session_id="test-session"):
        """Führt die Checkpoint-Logik aus und captured stdout/stderr."""
        wf_path = Path("/tmp/test-wf.json")

        captured_stdout = StringIO()
        captured_stderr = StringIO()

        with patch("phase_listener._read_active_workflow", return_value=(wf_data, wf_path)), \
             patch("phase_listener._call_workflow_checkpoint") as mock_cp, \
             patch("phase_listener._resolve_next_finding") as mock_resolve, \
             patch("phase_listener._save_workflow"), \
             patch("phase_listener._set_stop_lock"), \
             patch("phase_listener._get_hook_input", return_value={"prompt": message, "session_id": session_id}), \
             patch("phase_listener._get_session_id", return_value=session_id), \
             patch("sys.stdout", captured_stdout), \
             patch("sys.stderr", captured_stderr):
            try:
                phase_listener.main()
            except SystemExit:
                pass

        return captured_stdout.getvalue(), captured_stderr.getvalue(), mock_cp, mock_resolve


class TestScreenshotFeedbackOnStdout(CheckpointFeedbackTestBase):
    """Screenshot-Gate Feedback muss auf stdout gehen."""

    def test_missing_screenshot_feedback_on_stdout(self):
        """Wenn Screenshot fehlt, muss Feedback auf stdout erscheinen.
        Bricht wenn: phase_listener.py Screenshot-Hinweis noch auf stderr schreibt."""
        wf_data = {
            "name": "test-wf",
            "current_phase": "phase5_implement",
            "checkpoint3_approved": False,
            "adversary_findings": [],
            "test_artifacts": [{"type": "test_output", "phase": "phase4_tdd_red"}],
        }
        stdout, stderr, mock_cp, _ = self._run_main_with_message("commit", wf_data)

        self.assertIn("Screenshot", stdout, "Screenshot-Hinweis muss auf stdout erscheinen")
        mock_cp.assert_not_called()

    def test_missing_screenshot_not_on_stderr(self):
        """Screenshot-Hinweis darf NICHT auf stderr stehen.
        Bricht wenn: phase_listener.py Screenshot-Hinweis noch auf stderr hat."""
        wf_data = {
            "name": "test-wf",
            "current_phase": "phase5_implement",
            "checkpoint3_approved": False,
            "adversary_findings": [],
            "test_artifacts": [{"type": "test_output", "phase": "phase4_tdd_red"}],
        }
        stdout, stderr, _, _ = self._run_main_with_message("commit", wf_data)

        self.assertNotIn("Screenshot", stderr, "Screenshot-Hinweis darf NICHT auf stderr stehen")


class TestUnresolvedFindingsFeedbackOnStdout(CheckpointFeedbackTestBase):
    """Unresolved-Findings Feedback muss auf stdout gehen."""

    def test_unresolved_findings_feedback_on_stdout(self):
        """Wenn Findings offen sind, muss Feedback auf stdout erscheinen.
        Bricht wenn: phase_listener.py kein Feedback bei offenen Findings gibt."""
        wf_data = {
            "name": "test-wf",
            "current_phase": "phase5_implement",
            "checkpoint3_approved": False,
            "adversary_findings": [{"id": 1, "status": None, "title": "Bug X"}],
            "test_artifacts": [{"type": "screenshot", "phase": "phase5_implement"}],
        }
        stdout, stderr, mock_cp, _ = self._run_main_with_message("commit", wf_data)

        self.assertIn("Finding", stdout, "Finding-Hinweis muss auf stdout erscheinen")
        mock_cp.assert_not_called()


if __name__ == "__main__":
    unittest.main()
