#!/bin/bash
# TDD RED Tests für INFRA_012: Hook-System Scope-Validierung
# Diese Tests MÜSSEN FEHLSCHLAGEN vor der Implementation.
#
# Test 1-3: Phase-Guard für set-affected-files (workflow.py)
# Test 4-5: pbxproj-Schutz (bash_gate.py)

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Navigate from docs/artifacts/INFRA_012-hook-scope-validation/ to project root
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WF_DIR="$PROJECT_ROOT/.claude/workflows"
WORKFLOW_PY="$PROJECT_ROOT/.claude/hooks/workflow.py"
BASH_GATE="$PROJECT_ROOT/.claude/hooks/bash_gate.py"

PASSED=0
FAILED=0
ERRORS=""

# --- Helpers ---

create_test_workflow() {
    local name="$1"
    local phase="$2"
    cat > "$WF_DIR/${name}.json" <<JSONEOF
{
  "name": "$name",
  "current_phase": "$phase",
  "created": "2026-04-02T00:00:00",
  "last_updated": "2026-04-02T00:00:00",
  "affected_files": ["Sources/Existing.swift"],
  "test_artifacts": [],
  "red_test_done": false,
  "ui_test_red_done": false,
  "spec_file": "test.md",
  "spec_approved": true,
  "fix_proposal_approved": true,
  "workflow_type": "bug"
}
JSONEOF
    # Set as active via symlink (unset SESSION_ID to force symlink fallback)
    ln -sf "${name}.json" "$WF_DIR/.active"
}

cleanup_test_workflow() {
    local name="$1"
    rm -f "$WF_DIR/${name}.json"
}

# Unset CLAUDE_SESSION_ID so _read_active() uses .active symlink, not session mapping
unset CLAUDE_SESSION_ID

assert_exit_code() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    local output="$4"

    if [ "$actual" -eq "$expected" ]; then
        PASSED=$((PASSED + 1))
        echo "  ✅ $test_name (exit=$actual)"
    else
        FAILED=$((FAILED + 1))
        echo "  ❌ $test_name (expected exit=$expected, got exit=$actual)"
        echo "     Output: $output"
        ERRORS="$ERRORS\n  - $test_name"
    fi
}

assert_contains() {
    local test_name="$1"
    local expected_substr="$2"
    local actual="$3"

    if echo "$actual" | grep -q "$expected_substr"; then
        PASSED=$((PASSED + 1))
        echo "  ✅ $test_name (contains '$expected_substr')"
    else
        FAILED=$((FAILED + 1))
        echo "  ❌ $test_name (missing '$expected_substr')"
        echo "     Output: $actual"
        ERRORS="$ERRORS\n  - $test_name"
    fi
}

# --- Save current state ---
echo "=== INFRA_012 Scope-Validation Tests ==="
echo ""

# Backup current .active symlink
BACKUP_ACTIVE=""
if [ -L "$WF_DIR/.active" ]; then
    BACKUP_ACTIVE="$(readlink "$WF_DIR/.active")"
fi

TEST_WF="_test_infra012"

# ============================================
# TEST 1: set-affected-files BLOCKED in phase6_implement
# Bricht wenn: Phase-Guard in cmd_set_affected_files() fehlt
# ============================================
echo "--- Test 1: set-affected-files BLOCKED in phase6_implement ---"
create_test_workflow "$TEST_WF" "phase6_implement"

output=$(python3 "$WORKFLOW_PY" set-affected-files "Sources/NewFile.swift" 2>&1)
exit_code=$?

assert_exit_code "phase6 → set-affected-files exit code" 1 "$exit_code" "$output"
assert_contains "phase6 → BLOCKED message" "BLOCKED" "$output"

# ============================================
# TEST 2: set-affected-files ALLOWED in phase2_analyse
# Bricht wenn: Phase-Guard blockt zu aggressiv (phase2 nicht in Whitelist)
# ============================================
echo ""
echo "--- Test 2: set-affected-files ALLOWED in phase2_analyse ---"
create_test_workflow "$TEST_WF" "phase2_analyse"

output=$(python3 "$WORKFLOW_PY" set-affected-files "Sources/NewFile.swift" 2>&1)
exit_code=$?

assert_exit_code "phase2 → set-affected-files exit code" 0 "$exit_code" "$output"
assert_contains "phase2 → Set affected_files" "Set affected_files" "$output"

# ============================================
# TEST 3: set-affected-files ALLOWED in phase4_approved
# Bricht wenn: phase4_approved nicht in der Whitelist (braucht /10-bug Schritt 7.5)
# ============================================
echo ""
echo "--- Test 3: set-affected-files ALLOWED in phase4_approved ---"
create_test_workflow "$TEST_WF" "phase4_approved"

output=$(python3 "$WORKFLOW_PY" set-affected-files "Sources/AnotherFile.swift" 2>&1)
exit_code=$?

assert_exit_code "phase4 → set-affected-files exit code" 0 "$exit_code" "$output"
assert_contains "phase4 → Set affected_files" "Set affected_files" "$output"

# ============================================
# TEST 4: pbxproj via Python-Einzeiler BLOCKED by bash_gate
# Bricht wenn: project.pbxproj nicht in PROTECTED_FILE_PATTERNS
# ============================================
echo ""
echo "--- Test 4: pbxproj Python-Einzeiler BLOCKED ---"

output=$(echo '{"tool_input":{"command":"python3 -c \"from pbxproj import XcodeProject; proj = XcodeProject.load(\\\"FocusBlox.xcodeproj/project.pbxproj\\\"); proj.save()\""}}' | python3 "$BASH_GATE" 2>&1)
exit_code=$?

assert_exit_code "pbxproj Python → bash_gate exit code" 2 "$exit_code" "$output"
assert_contains "pbxproj Python → BLOCKED message" "BLOCKED" "$output"

# ============================================
# TEST 5: pbxproj via whitegelistetes Script ALLOWED
# Bricht wenn: add_file_to_project.py nicht in WHITELIST_COMMANDS
# ============================================
echo ""
echo "--- Test 5: pbxproj whitegelistetes Script ALLOWED ---"

output=$(echo '{"tool_input":{"command":"python3 scripts/add_file_to_project.py Sources/Views/NewView.swift --target FocusBlox"}}' | python3 "$BASH_GATE" 2>&1)
exit_code=$?

assert_exit_code "pbxproj Script → bash_gate exit code" 0 "$exit_code" "$output"

# --- Cleanup ---
cleanup_test_workflow "$TEST_WF"

# Restore original .active
if [ -n "$BACKUP_ACTIVE" ]; then
    ln -sf "$BACKUP_ACTIVE" "$WF_DIR/.active"
elif [ -L "$WF_DIR/.active" ]; then
    rm -f "$WF_DIR/.active"
fi

# --- Summary ---
echo ""
echo "=== SUMMARY ==="
TOTAL=$((PASSED + FAILED))
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "FAILED tests (expected in RED phase):"
    echo -e "$ERRORS"
    exit 1
else
    echo "All tests passed (unexpected in RED phase!)"
    exit 0
fi
