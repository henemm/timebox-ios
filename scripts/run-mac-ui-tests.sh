#!/bin/bash
# Run macOS UI tests — works locally AND via SSH
#
# Usage: ./scripts/run-mac-ui-tests.sh [options] [test_filter]
#
# Options:
#   --clean     Force xcodebuild clean before tests
#   --all       Run ALL macOS UI tests (not just FEATURE_004)
#
# Examples:
#   ./scripts/run-mac-ui-tests.sh                          # Default FEATURE_004 tests
#   ./scripts/run-mac-ui-tests.sh test_coachBacklog_search # Filter by name
#   ./scripts/run-mac-ui-tests.sh --clean                  # Clean build first
#   ./scripts/run-mac-ui-tests.sh --all                    # All macOS UI tests

set -euo pipefail
cd "$(dirname "$0")/.."

# --- Parse options ---
CLEAN=false
RUN_ALL=false
FILTER=""

for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=true ;;
        --all)   RUN_ALL=true ;;
        *)       FILTER="$arg" ;;
    esac
done

# --- Output file ---
OUTPUT="docs/artifacts/mac-ui-test-output.txt"
mkdir -p "$(dirname "$OUTPUT")"

# --- SSH Detection & Keychain Unlock ---
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
    echo ">> SSH session detected — unlocking keychain for code signing..."
    if security unlock-keychain -p "" ~/Library/Keychains/login.keychain-db 2>/dev/null; then
        echo "   Keychain unlocked (empty password)"
    else
        echo "   Keychain unlock with empty password failed."
        echo "   Trying interactive unlock..."
        security unlock-keychain ~/Library/Keychains/login.keychain-db
    fi
    echo ""
fi

# --- Clean (optional or on retry) ---
if [ "$CLEAN" = true ]; then
    echo ">> Cleaning build..."
    xcodebuild clean -scheme FocusBloxMac -quiet 2>/dev/null || true
    echo ""
fi

# --- Determine tests to run ---
TESTS=()

if [ "$RUN_ALL" = true ]; then
    # Run all macOS UI tests — no -only-testing filter
    :
elif [ -n "$FILTER" ]; then
    # Find matching test methods across all macOS UI test files
    while IFS= read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        func=$(echo "$line" | grep -o "func ${FILTER}[^(]*" | sed 's/func //')
        class=$(grep -o "class [A-Za-z]*" "$file" | head -1 | sed 's/class //')
        if [ -n "$func" ] && [ -n "$class" ]; then
            TESTS+=("-only-testing:FocusBloxMacUITests/${class}/${func}")
        fi
    done < <(grep -rn "func ${FILTER}" FocusBloxMacUITests/ --include="*.swift" 2>/dev/null)
fi

if [ "$RUN_ALL" = false ] && [ ${#TESTS[@]} -eq 0 ] && [ -z "$FILTER" ]; then
    # Default: all FEATURE_004 search tests
    TESTS=(
        "-only-testing:FocusBloxMacUITests/MacCoachBacklogUITests/test_coachBacklog_searchFieldExists"
        "-only-testing:FocusBloxMacUITests/MacCoachBacklogUITests/test_coachBacklog_searchFiltersByTitle"
        "-only-testing:FocusBloxMacUITests/MacCoachBacklogUITests/test_coachBacklog_searchNoMatch_showsNoTasks"
        "-only-testing:FocusBloxMacUITests/MacCoachBacklogUITests/test_coachBacklog_searchClear_showsAllTasks"
    )
fi

echo ">> Running ${#TESTS[@]} test(s)..."
echo ""

# --- Run tests ---
set +e
xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBloxMac \
    -destination 'platform=macOS' \
    -allowProvisioningUpdates \
    "${TESTS[@]}" \
    2>&1 | tee "$OUTPUT"
TEST_EXIT=${PIPESTATUS[0]}
set -e

echo ""
echo "=== SUMMARY ==="

# --- Diagnose failures ---
if [ $TEST_EXIT -ne 0 ]; then
    if grep -q "errSecInternalComponent" "$OUTPUT"; then
        echo ""
        echo "!! CODE SIGNING FAILED: errSecInternalComponent"
        echo ""
        echo "This typically happens in SSH sessions when the keychain is locked."
        echo "Fixes to try:"
        echo "  1. Run: security unlock-keychain ~/Library/Keychains/login.keychain-db"
        echo "  2. Re-run this script"
        echo "  3. If it persists, try: ./scripts/run-mac-ui-tests.sh --clean"
        echo ""
    elif grep -q "CodeSign.*failed" "$OUTPUT"; then
        echo ""
        echo "!! CODE SIGNING FAILED (other reason)"
        echo "Try: ./scripts/run-mac-ui-tests.sh --clean"
        echo ""
    fi
fi

grep -E "(Test Case|Executed)" "$OUTPUT" | tail -20
echo ""

if [ $TEST_EXIT -eq 0 ]; then
    echo "Result: PASSED"
else
    echo "Result: FAILED (exit code $TEST_EXIT)"
fi

echo "Output saved to: $OUTPUT"
exit $TEST_EXIT
