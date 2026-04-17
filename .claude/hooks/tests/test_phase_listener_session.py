#!/usr/bin/env python3
"""Tests for Bug #257 — phase_listener Session-ID Fix.

Tests verify:
1. _call_workflow_checkpoint passes session_id to subprocess environment
2. _resolve_next_finding passes session_id to subprocess environment
3. "weiter" removed from checkpoint phrases (keyword conflict)
4. "weiter" still in CONTINUE_PHRASES
"""

import os
import sys
import unittest
from unittest.mock import patch, MagicMock
from pathlib import Path

# Add hooks dir to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import phase_listener


class TestSessionIdInSubprocess(unittest.TestCase):
    """Session-ID must be passed to subprocess environment."""

    @patch("phase_listener.subprocess.run")
    @patch("phase_listener._project_root", return_value=Path("/tmp/test"))
    def test_checkpoint_passes_session_id(self, mock_root, mock_run):
        """_call_workflow_checkpoint must set CLAUDE_SESSION_ID in env.
        Bricht wenn: phase_listener.py session_id nicht ins env setzt."""
        mock_run.return_value = MagicMock(returncode=0, stdout="OK", stderr="")
        phase_listener._call_workflow_checkpoint(2, "test", session_id="abc-123")
        mock_run.assert_called_once()
        call_kwargs = mock_run.call_args
        env = call_kwargs.kwargs.get("env") or call_kwargs[1].get("env")
        self.assertEqual(env.get("CLAUDE_SESSION_ID"), "abc-123")
        self.assertEqual(env.get("WORKFLOW_CALLER"), "phase_listener")

    @patch("phase_listener.subprocess.run")
    @patch("phase_listener._project_root", return_value=Path("/tmp/test"))
    def test_checkpoint_without_session_id(self, mock_root, mock_run):
        """_call_workflow_checkpoint without session_id must not set empty env var.
        Bricht wenn: phase_listener.py leere session_id ins env setzt."""
        mock_run.return_value = MagicMock(returncode=0, stdout="OK", stderr="")
        phase_listener._call_workflow_checkpoint(1, "test", session_id="")
        mock_run.assert_called_once()
        call_kwargs = mock_run.call_args
        env = call_kwargs.kwargs.get("env") or call_kwargs[1].get("env")
        # Should not have set CLAUDE_SESSION_ID if empty (unless already in os.environ)
        if "CLAUDE_SESSION_ID" not in os.environ:
            self.assertNotIn("CLAUDE_SESSION_ID", env)

    @patch("phase_listener.subprocess.run")
    def test_resolve_finding_passes_session_id(self, mock_run):
        """_resolve_next_finding must set CLAUDE_SESSION_ID in env.
        Bricht wenn: phase_listener.py session_id nicht an resolve weitergibt."""
        mock_run.return_value = MagicMock(returncode=0, stdout="OK", stderr="")
        wf_data = {
            "adversary_findings": [{"id": 1, "status": None}]
        }
        phase_listener._resolve_next_finding(
            wf_data, Path("/tmp/test.json"), "fix", session_id="xyz-789")
        mock_run.assert_called_once()
        call_kwargs = mock_run.call_args
        env = call_kwargs.kwargs.get("env") or call_kwargs[1].get("env")
        self.assertEqual(env.get("CLAUDE_SESSION_ID"), "xyz-789")


class TestWeiterKeywordConflict(unittest.TestCase):
    """'weiter' must not be in checkpoint phrases to avoid ambiguity."""

    def test_weiter_not_in_checkpoint1(self):
        """'weiter' must not be in CHECKPOINT1_PHRASES.
        Bricht wenn: phase_listener.py CHECKPOINT1_PHRASES 'weiter' enthält."""
        self.assertNotIn("weiter", phase_listener.CHECKPOINT1_PHRASES)

    def test_weiter_not_in_checkpoint2(self):
        """'weiter' must not be in CHECKPOINT2_PHRASES.
        Bricht wenn: phase_listener.py CHECKPOINT2_PHRASES 'weiter' enthält."""
        self.assertNotIn("weiter", phase_listener.CHECKPOINT2_PHRASES)

    def test_weiter_not_in_checkpoint3(self):
        """'weiter' must not be in CHECKPOINT3_PHRASES.
        Bricht wenn: phase_listener.py CHECKPOINT3_PHRASES 'weiter' enthält."""
        self.assertNotIn("weiter", phase_listener.CHECKPOINT3_PHRASES)

    def test_weiter_still_in_continue_phrases(self):
        """'weiter' must still be in CONTINUE_PHRASES.
        Bricht wenn: phase_listener.py CONTINUE_PHRASES 'weiter' nicht mehr enthält."""
        self.assertIn("weiter", phase_listener.CONTINUE_PHRASES)


if __name__ == "__main__":
    unittest.main()
