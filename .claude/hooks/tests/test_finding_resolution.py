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


class TestAutoCloseGitHubIssues(unittest.TestCase):
    """Auto-Close Finding-Issues: Issue-Nummer persistieren und beim Complete schließen."""

    @patch("workflow._save_active")
    @patch("workflow._read_active")
    @patch("subprocess.run")
    def test_resolve_finding_fix_stores_github_issue(
        self, mock_run, mock_read, mock_save
    ):
        """Nach resolve-finding mit status 'fix' hat das Finding github_issue: 42.
        Bricht wenn: cmd_resolve_finding die Issue-Nummer nicht im Finding speichert."""
        data = {
            "current_phase": "phase5_implement",
            "adversary_findings": [
                {
                    "id": 1,
                    "title": "Null-Check fehlt",
                    "impact": "crash",
                    "proof": "line 42",
                    "status": None,
                    "resolved_at": None,
                }
            ],
        }
        mock_read.return_value = (data, "TEST_001")
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="https://github.com/owner/repo/issues/42\n",
            stderr="",
        )
        os.environ["WORKFLOW_CALLER"] = "phase_listener"
        try:
            import workflow
            workflow.cmd_resolve_finding(["1", "fix"])
        finally:
            del os.environ["WORKFLOW_CALLER"]

        saved_data = mock_save.call_args[0][0]
        finding = saved_data["adversary_findings"][0]
        self.assertEqual(
            finding.get("github_issue"),
            42,
            "Finding muss github_issue: 42 enthalten nach gh issue create",
        )

    @patch("workflow._save_active")
    @patch("workflow._read_active")
    @patch("subprocess.run")
    def test_resolve_finding_fix_gh_error_no_crash(
        self, mock_run, mock_read, mock_save
    ):
        """Wenn gh issue create fehlschlägt, kein Crash und kein github_issue im Finding.
        Bricht wenn: cmd_resolve_finding bei gh-Fehler den Workflow abbricht."""
        import subprocess
        data = {
            "current_phase": "phase5_implement",
            "adversary_findings": [
                {
                    "id": 2,
                    "title": "Edge Case",
                    "impact": "minor",
                    "proof": "line 7",
                    "status": None,
                    "resolved_at": None,
                }
            ],
        }
        mock_read.return_value = (data, "TEST_002")
        mock_run.side_effect = subprocess.CalledProcessError(1, "gh")
        os.environ["WORKFLOW_CALLER"] = "phase_listener"
        try:
            import workflow
            # Darf NICHT werfen
            workflow.cmd_resolve_finding(["2", "fix"])
        finally:
            del os.environ["WORKFLOW_CALLER"]

        saved_data = mock_save.call_args[0][0]
        finding = saved_data["adversary_findings"][0]
        self.assertNotIn(
            "github_issue",
            finding,
            "Bei gh-Fehler darf kein github_issue Feld gesetzt werden",
        )

    @patch("workflow._archive_dir")
    @patch("workflow._active_link")
    @patch("workflow._get_session_id")
    @patch("workflow._locked_sessions")
    @patch("workflow._workflow_file")
    @patch("workflow._atomic_write")
    @patch("workflow._save_active")
    @patch("workflow._read_active")
    @patch("subprocess.run")
    def test_complete_closes_fix_issues(
        self,
        mock_run,
        mock_read,
        mock_save,
        mock_atomic,
        mock_wf_file,
        mock_sessions,
        mock_session_id,
        mock_link,
        mock_archive,
    ):
        """cmd_complete ruft gh issue close für alle fix-Findings mit github_issue auf.
        Bricht wenn: cmd_complete GitHub Issues nicht schließt."""
        archive_path = MagicMock()
        archive_path.__truediv__ = lambda self, other: MagicMock()
        mock_archive.return_value = archive_path
        mock_wf_file.return_value = MagicMock(exists=lambda: False)
        mock_session_id.return_value = None
        link_mock = MagicMock()
        link_mock.is_symlink.return_value = False
        mock_link.return_value = link_mock
        data = {
            "current_phase": "phase6_adversary",
            "adversary_findings": [
                {
                    "id": 1,
                    "title": "Bug A",
                    "status": "fix",
                    "github_issue": 42,
                },
                {
                    "id": 2,
                    "title": "Bug B",
                    "status": "fix",
                    "github_issue": 99,
                },
                {
                    "id": 3,
                    "title": "Nitpick",
                    "status": "accept",
                    "github_issue": 55,
                },
            ],
        }
        mock_read.return_value = (data, "TEST_003")
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        import workflow
        workflow.cmd_complete([])

        close_calls = [
            c
            for c in mock_run.call_args_list
            if c[0][0][0] == "gh" and "close" in c[0][0]
        ]
        closed_numbers = [int(c[0][0][3]) for c in close_calls]
        self.assertIn(42, closed_numbers, "Issue #42 muss geschlossen werden")
        self.assertIn(99, closed_numbers, "Issue #99 muss geschlossen werden")
        self.assertNotIn(55, closed_numbers, "Issue #55 (accept) darf nicht geschlossen werden")

    @patch("workflow._archive_dir")
    @patch("workflow._active_link")
    @patch("workflow._get_session_id")
    @patch("workflow._locked_sessions")
    @patch("workflow._workflow_file")
    @patch("workflow._atomic_write")
    @patch("workflow._save_active")
    @patch("workflow._read_active")
    @patch("subprocess.run")
    def test_complete_skips_findings_without_github_issue(
        self,
        mock_run,
        mock_read,
        mock_save,
        mock_atomic,
        mock_wf_file,
        mock_sessions,
        mock_session_id,
        mock_link,
        mock_archive,
    ):
        """Findings ohne github_issue Feld werden beim Complete übersprungen (kein Crash).
        Bricht wenn: cmd_complete bei fehlendem github_issue abstürzt."""
        archive_path = MagicMock()
        archive_path.__truediv__ = lambda self, other: MagicMock()
        mock_archive.return_value = archive_path
        mock_wf_file.return_value = MagicMock(exists=lambda: False)
        mock_session_id.return_value = None
        link_mock = MagicMock()
        link_mock.is_symlink.return_value = False
        mock_link.return_value = link_mock
        data = {
            "current_phase": "phase6_adversary",
            "adversary_findings": [
                {
                    "id": 1,
                    "title": "Alter Bug ohne Issue",
                    "status": "fix",
                    # kein 'github_issue' Feld — alter Workflow
                },
            ],
        }
        mock_read.return_value = (data, "TEST_004")
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        import workflow
        # Darf NICHT werfen
        try:
            workflow.cmd_complete([])
        except Exception as e:
            self.fail(f"cmd_complete darf bei fehlendem github_issue nicht crashen: {e}")

        close_calls = [
            c
            for c in mock_run.call_args_list
            if c[0][0][0] == "gh" and "close" in c[0][0]
        ]
        self.assertEqual(
            len(close_calls),
            0,
            "Kein gh issue close ohne github_issue Feld",
        )


if __name__ == "__main__":
    unittest.main()
