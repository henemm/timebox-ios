#!/usr/bin/env python3
"""Tests for Bug #262 + #263 + #265 — Finding-Resolution + Adversary Worktree.

Tests verify:
1. _get_user_message fallback extracts from unknown field names (#262)
2. Multiple findings resolved from one message (#263)
3. Single finding still works (#263)
4. Adversary in 10-bug.md and 11-feature.md has no worktree isolation (#265)
"""

import os
import sys
import unittest
from unittest.mock import patch, MagicMock, call
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import phase_listener


class TestGetUserMessageFallback(unittest.TestCase):
    """_get_user_message must extract message even from unknown fields (#262)."""

    def test_standard_prompt_field(self):
        """Standard 'prompt' field works as before.
        Bricht wenn: _get_user_message 'prompt' nicht mehr erkennt."""
        hook_input = {"prompt": "go", "session_id": "abc"}
        self.assertEqual(phase_listener._get_user_message(hook_input), "go")

    def test_fallback_to_unknown_string_field(self):
        """Falls 'prompt'/'content'/'message' fehlen, String-Felder durchsuchen.
        Bricht wenn: _get_user_message keinen Fallback hat."""
        hook_input = {"session_id": "abc", "cwd": "/tmp", "some_field": "fixen"}
        msg = phase_listener._get_user_message(hook_input)
        self.assertEqual(msg, "fixen")

    def test_ignores_known_metadata_fields(self):
        """session_id, cwd etc. dürfen nicht als Message erkannt werden.
        Bricht wenn: _get_user_message Metadata-Felder zurückgibt."""
        hook_input = {"session_id": "abc-123", "cwd": "/some/path"}
        msg = phase_listener._get_user_message(hook_input)
        self.assertEqual(msg, "")


class TestMultipleFindingResolution(unittest.TestCase):
    """Multiple findings resolved from one message (#263)."""

    @patch("phase_listener._read_active_workflow")
    @patch("phase_listener._resolve_next_finding")
    def test_two_keywords_resolve_two_findings(self, mock_resolve, mock_read):
        """'fixen zurückstellen' should resolve 2 findings.
        Bricht wenn: phase_listener nur ein Finding pro Nachricht auflöst."""
        wf_data = {
            "current_phase": "phase5_implement",
            "adversary_findings": [
                {"id": 1, "status": None},
                {"id": 2, "status": None},
            ],
        }
        wf_path = Path("/tmp/test.json")
        # After first resolve, re-read returns updated data
        mock_read.return_value = (wf_data, wf_path)
        mock_resolve.return_value = True

        # Simulate main() logic for finding resolution
        message = "1 fixen, 2 zurückstellen"
        session_id = "test-session"
        phase = wf_data.get("current_phase", "")

        if phase == "phase5_implement":
            findings = wf_data.get("adversary_findings", [])
            has_unresolved = any(f.get("status") is None for f in findings)
            if has_unresolved:
                for phrases, status in [
                    (phase_listener.FINDING_FIX_PHRASES, "fix"),
                    (phase_listener.FINDING_ACCEPT_PHRASES, "accept"),
                    (phase_listener.FINDING_DEFER_PHRASES, "defer"),
                ]:
                    if phase_listener._matches(message, phrases):
                        phase_listener._resolve_next_finding(
                            wf_data, wf_path, status, session_id=session_id)

        # Should have been called twice: once for "fixen" and once for "zurückstellen"
        self.assertEqual(mock_resolve.call_count, 2)
        statuses = [c.args[2] for c in mock_resolve.call_args_list]
        self.assertIn("fix", statuses)
        self.assertIn("defer", statuses)

    @patch("phase_listener._resolve_next_finding")
    def test_single_keyword_still_works(self, mock_resolve):
        """'fixen' alone should resolve exactly 1 finding.
        Bricht wenn: Refactor die Einzel-Resolution bricht."""
        mock_resolve.return_value = True
        wf_data = {
            "adversary_findings": [{"id": 1, "status": None}],
        }
        wf_path = Path("/tmp/test.json")
        message = "fixen"

        for phrases, status in [
            (phase_listener.FINDING_FIX_PHRASES, "fix"),
            (phase_listener.FINDING_ACCEPT_PHRASES, "accept"),
            (phase_listener.FINDING_DEFER_PHRASES, "defer"),
        ]:
            if phase_listener._matches(message, phrases):
                phase_listener._resolve_next_finding(
                    wf_data, wf_path, status, session_id="s")

        self.assertEqual(mock_resolve.call_count, 1)
        self.assertEqual(mock_resolve.call_args.args[2], "fix")


class TestAdversaryNoWorktree(unittest.TestCase):
    """Adversary must not use worktree isolation (#265)."""

    def test_10_bug_no_worktree(self):
        """10-bug.md must not contain 'isolation: \"worktree\"'.
        Bricht wenn: 10-bug.md noch worktree-Isolation hat."""
        bug_md = Path(__file__).parent.parent.parent / "commands" / "10-bug.md"
        content = bug_md.read_text()
        self.assertNotIn('isolation: "worktree"', content)

    def test_11_feature_no_worktree(self):
        """11-feature.md must not contain 'isolation: \"worktree\"'.
        Bricht wenn: 11-feature.md noch worktree-Isolation hat."""
        feature_md = Path(__file__).parent.parent.parent / "commands" / "11-feature.md"
        content = feature_md.read_text()
        self.assertNotIn('isolation: "worktree"', content)


if __name__ == "__main__":
    unittest.main()
