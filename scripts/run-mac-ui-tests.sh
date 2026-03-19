#!/bin/bash
# Run macOS UI tests — works locally AND via SSH
#
# Usage: ./scripts/run-mac-ui-tests.sh [options] [test_filter]
#
# Options:
#   --clean     Force xcodebuild clean before tests
#   --all       Run ALL macOS UI tests (not just FEATURE_004)
#
# Filter modes (tried in order):
#   1. Exact class name   → runs all tests in that class
#   2. Exact method name  → runs that specific test method
#   3. Substring match    → finds test methods containing the filter
#   4. No match           → ABORTS with error (never silently runs all)
#
# Examples:
#   ./scripts/run-mac-ui-tests.sh                              # Default FEATURE_004 tests
#   ./scripts/run-mac-ui-tests.sh MacUnifiedSearchUITests      # All tests in class
#   ./scripts/run-mac-ui-tests.sh test_coachBacklog_search     # Exact method match
#   ./scripts/run-mac-ui-tests.sh UnifiedSearch                # Substring match
#   ./scripts/run-mac-ui-tests.sh --clean                      # Clean build first
#   ./scripts/run-mac-ui-tests.sh --all                        # All macOS UI tests

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
    KEYCHAIN_PW_FILE="$HOME/.keychain_password"
    if [ -f "$KEYCHAIN_PW_FILE" ]; then
        if security unlock-keychain -p "$(cat "$KEYCHAIN_PW_FILE")" ~/Library/Keychains/login.keychain-db 2>/dev/null; then
            echo "   Keychain unlocked (via ~/.keychain_password)"
        else
            echo "!! Keychain unlock failed — password in ~/.keychain_password may be wrong"
            exit 1
        fi
    else
        echo "!! ~/.keychain_password not found."
        echo "   Create it on the iMac:"
        echo "     echo 'YOUR_LOGIN_PASSWORD' > ~/.keychain_password"
        echo "     chmod 600 ~/.keychain_password"
        echo ""
        echo "   Or unlock manually:"
        echo "     security unlock-keychain ~/Library/Keychains/login.keychain-db"
        exit 1
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
    # Strategy 1: Filter matches a class name → run all tests in that class
    CLASS_MATCH=$(grep -rn "class ${FILTER}" FocusBloxMacUITests/ --include="*.swift" 2>/dev/null | head -1 || true)
    if [ -n "$CLASS_MATCH" ]; then
        class=$(echo "$CLASS_MATCH" | grep -o "class ${FILTER}[A-Za-z0-9_]*" | head -1 | sed 's/class //')
        if [ -n "$class" ]; then
            TESTS+=("-only-testing:FocusBloxMacUITests/${class}")
            echo ">> Filter matched class: ${class}"
        fi
    fi

    # Strategy 2: Filter matches function names → run specific test methods
    if [ ${#TESTS[@]} -eq 0 ]; then
        while IFS= read -r line; do
            file=$(echo "$line" | cut -d: -f1)
            func=$(echo "$line" | grep -o "func ${FILTER}[^(]*" | sed 's/func //')
            class=$(grep -o 'class [A-Za-z0-9_]*' "$file" | head -1 | sed 's/class //')
            if [ -n "$func" ] && [ -n "$class" ]; then
                TESTS+=("-only-testing:FocusBloxMacUITests/${class}/${func}")
            fi
        done < <(grep -rn "func ${FILTER}" FocusBloxMacUITests/ --include="*.swift" 2>/dev/null)
    fi

    # Strategy 3: Filter matches partial class/function names (substring search)
    if [ ${#TESTS[@]} -eq 0 ]; then
        while IFS= read -r line; do
            file=$(echo "$line" | cut -d: -f1)
            func=$(echo "$line" | grep -o "func test[^(]*${FILTER}[^(]*" | sed 's/func //')
            class=$(grep -o 'class [A-Za-z0-9_]*' "$file" | head -1 | sed 's/class //')
            if [ -n "$func" ] && [ -n "$class" ]; then
                TESTS+=("-only-testing:FocusBloxMacUITests/${class}/${func}")
            fi
        done < <(grep -rn "func test.*${FILTER}" FocusBloxMacUITests/ --include="*.swift" 2>/dev/null)
    fi

    # FAIL SAFE: Filter given but nothing matched → abort instead of running all tests
    if [ ${#TESTS[@]} -eq 0 ]; then
        echo "!! ERROR: Filter '${FILTER}' matched no classes or test methods."
        echo ""
        echo "Available test classes:"
        grep -rh "class [A-Za-z0-9_]*.*XCTestCase" FocusBloxMacUITests/ --include="*.swift" 2>/dev/null \
            | sed 's/.*class \([A-Za-z0-9_]*\).*/  \1/' | sort -u
        echo ""
        echo "Usage examples:"
        echo "  ./scripts/run-mac-ui-tests.sh MacUnifiedSearchUITests    # Full class name"
        echo "  ./scripts/run-mac-ui-tests.sh test_search_fieldExists    # Full method name"
        echo "  ./scripts/run-mac-ui-tests.sh UnifiedSearch              # Substring match"
        echo "  ./scripts/run-mac-ui-tests.sh --all                      # All tests"
        exit 1
    fi
fi

if [ "$RUN_ALL" = false ] && [ ${#TESTS[@]} -eq 0 ]; then
    # No filter, no --all → default tests
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
if [ ${#TESTS[@]} -gt 0 ]; then
    xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBloxMac \
        -destination 'platform=macOS' \
        -allowProvisioningUpdates \
        "${TESTS[@]}" \
        2>&1 | tee "$OUTPUT"
else
    xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBloxMac \
        -destination 'platform=macOS' \
        -allowProvisioningUpdates \
        2>&1 | tee "$OUTPUT"
fi
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
