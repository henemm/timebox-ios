#!/bin/bash
#
# sim.sh — Simulator-Toolkit fuer FocusBlox
#
# EINE Anlaufstelle fuer alle Simulator-Operationen.
# Simulator-ID ist fest eingebaut — kein Raten, kein Suchen.
#
# Usage:
#   ./scripts/sim.sh status                         # Simulator-Status pruefen
#   ./scripts/sim.sh boot                           # Simulator starten
#   ./scripts/sim.sh build                          # App fuer Simulator bauen
#   ./scripts/sim.sh launch                         # App installieren + starten
#   ./scripts/sim.sh launch --mock                  # App mit Mock-Daten starten
#   ./scripts/sim.sh launch --screen day             # App starten + zum Screen navigieren
#   ./scripts/sim.sh launch --mock --screen review  # Mock-Daten + Screen
#   ./scripts/sim.sh navigate day                   # App neu starten + zum Screen navigieren
#   ./scripts/sim.sh screenshot                     # Screenshot → /tmp/sim_screenshot.png
#   ./scripts/sim.sh screenshot /path/to/output.png # Screenshot → custom path
#   ./scripts/sim.sh test TestClass                 # UI Test ausfuehren
#   ./scripts/sim.sh test TestClass/testMethod      # Einzelnen Test ausfuehren
#   ./scripts/sim.sh unit TestClass                 # Unit Test ausfuehren
#   ./scripts/sim.sh unit TestClass/testMethod      # Einzelnen Unit Test ausfuehren
#   ./scripts/sim.sh mac-build                      # macOS App bauen (nativ, kein Simulator)
#   ./scripts/sim.sh mac-unit TestClass              # macOS Unit Test ausfuehren
#   ./scripts/sim.sh mac-unit TestClass/testMethod   # Einzelnen macOS Unit Test ausfuehren
#

set -eo pipefail

# ============================================
# KONFIGURATION — Einzige Quelle der Wahrheit
# ============================================
SIM_ID="1EC79950-6704-47D0-BDF8-2C55236B4B40"
SIM_NAME="FocusBlox"
PROJECT="FocusBlox.xcodeproj"
SCHEME="FocusBlox"
MAC_SCHEME="FocusBloxMac"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# --- Session-Isolation ---
# Per-Session DerivedData verhindert Build-Artefakt-Konflikte
# Simulator-Lock serialisiert Simulator-Zugriff zwischen Sessions
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
SESSION_DERIVED_DATA="$DERIVED_DATA/FocusBlox-session-${SESSION_ID}"
SIM_LOCK_FILE="$PROJECT_DIR/.claude/sim_lock"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[sim]${NC} $1" >&2; }
success() { echo -e "${GREEN}[sim]${NC} $1" >&2; }
warn()    { echo -e "${YELLOW}[sim]${NC} $1" >&2; }
error()   { echo -e "${RED}[sim]${NC} $1" >&2; }

# Simulator-Lock: serialisiert Simulator-Zugriff zwischen Sessions
# Verwendet mkdir (atomar auf POSIX) als Lock-Mechanismus
SIM_LOCK_DIR="$PROJECT_DIR/.claude/sim_lock.d"
SIM_LOCK_ACQUIRED=""
MAX_SIM_WAIT=300

acquire_sim_lock() {
    local WAITED=0
    while ! mkdir "$SIM_LOCK_DIR" 2>/dev/null; do
        # Check for stale lock (older than 10 min)
        if [ -f "$SIM_LOCK_DIR/info" ]; then
            local LOCK_TIME
            LOCK_TIME=$(cat "$SIM_LOCK_DIR/info" 2>/dev/null | head -1)
            local NOW
            NOW=$(date +%s)
            if [ -n "$LOCK_TIME" ] && [ $((NOW - LOCK_TIME)) -gt 600 ]; then
                warn "Stale Simulator-Lock entfernt (>10min alt)"
                rm -rf "$SIM_LOCK_DIR"
                continue
            fi
        fi
        if [ $WAITED -ge $MAX_SIM_WAIT ]; then
            error "Simulator-Lock Timeout (${MAX_SIM_WAIT}s) — andere Session blockiert"
            return 1
        fi
        if [ $((WAITED % 30)) -eq 0 ] && [ $WAITED -gt 0 ]; then
            info "Warte auf Simulator-Lock... (${WAITED}s/${MAX_SIM_WAIT}s)"
        fi
        sleep 5
        WAITED=$((WAITED + 5))
    done
    # Write lock info for stale detection
    echo "$(date +%s)" > "$SIM_LOCK_DIR/info"
    echo "${SESSION_ID}" >> "$SIM_LOCK_DIR/info"
    SIM_LOCK_ACQUIRED=1
    info "Simulator-Lock acquired (Session: ${SESSION_ID:0:8})"
}

release_sim_lock() {
    if [ -n "$SIM_LOCK_ACQUIRED" ]; then
        rm -rf "$SIM_LOCK_DIR" 2>/dev/null || true
        SIM_LOCK_ACQUIRED=""
    fi
}

# Cleanup bei Exit
trap release_sim_lock EXIT

# ============================================
# SUBCOMMANDS
# ============================================

cmd_status() {
    info "Simulator: $SIM_NAME ($SIM_ID)"
    echo ""

    # Pruefen ob Simulator existiert
    if ! xcrun simctl list devices available 2>/dev/null | grep -q "$SIM_ID"; then
        error "Simulator mit ID $SIM_ID nicht gefunden!"
        echo ""
        info "Verfuegbare Simulatoren:"
        xcrun simctl list devices available | grep -E "iPhone|FocusBlox" || true
        return 1
    fi

    # Status pruefen
    local STATE
    STATE=$(xcrun simctl list devices 2>/dev/null | grep "$SIM_ID" | sed -E 's/.*\((Booted|Shutdown)\).*/\1/' | tail -1)

    if [ "$STATE" = "Booted" ]; then
        success "Simulator laeuft (Booted)"
    else
        warn "Simulator ist aus (Shutdown)"
    fi

    # Gebaute App pruefen (Session-DerivedData zuerst, dann global)
    local APP_PATH
    APP_PATH=$(find "$SESSION_DERIVED_DATA"/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
    if [ -z "$APP_PATH" ]; then
        APP_PATH=$(find "$DERIVED_DATA"/FocusBlox-*/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
    fi
    if [ -n "$APP_PATH" ]; then
        success "App gebaut: $APP_PATH"
    else
        warn "Keine gebaute App gefunden (erst ./scripts/sim.sh build)"
    fi
}

cmd_boot() {
    info "Starte Simulator..."

    # Simulator.app oeffnen mit korrektem Device
    open -a Simulator --args -CurrentDeviceUDID "$SIM_ID" 2>/dev/null || true
    xcrun simctl boot "$SIM_ID" 2>/dev/null || true

    # Warten bis bereit
    info "Warte auf Boot..."
    if xcrun simctl bootstatus "$SIM_ID" -b 2>/dev/null; then
        success "Simulator bereit."
    else
        # Manchmal ist er schon booted, dann schlaegt bootstatus fehl
        local STATE
        STATE=$(xcrun simctl list devices 2>/dev/null | grep "$SIM_ID" | grep -o "Booted" || true)
        if [ "$STATE" = "Booted" ]; then
            success "Simulator laeuft bereits."
        else
            error "Simulator konnte nicht gestartet werden!"
            return 1
        fi
    fi
}

cmd_build() {
    info "Baue App fuer Simulator... (DerivedData: ${SESSION_ID:0:8})"
    cd "$PROJECT_DIR"

    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$SIM_ID" \
        -derivedDataPath "$SESSION_DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        -quiet \
        2>&1

    if [ $? -eq 0 ]; then
        success "Build erfolgreich."
    else
        error "Build fehlgeschlagen!"
        return 1
    fi
}

cmd_launch() {
    local EXTRA_ARGS=()
    local SCREEN=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --mock)
                EXTRA_ARGS+=("-UITesting")
                info "Mock-Daten aktiviert"
                ;;
            --screen)
                shift
                SCREEN="${1:-}"
                if [ -z "$SCREEN" ]; then
                    error "--screen braucht einen Screen-Namen!"
                    echo "Verfuegbar: backlog, blox, day, focus, review, refiner"
                    return 1
                fi
                EXTRA_ARGS+=("--screen" "$SCREEN")
                info "Navigiere zu Screen: $SCREEN"
                ;;
            *)
                EXTRA_ARGS+=("$1")
                ;;
        esac
        shift
    done

    info "Starte App..."

    # Simulator-Lock fuer exklusiven Zugriff
    acquire_sim_lock

    # Sicherstellen dass Simulator laeuft
    cmd_boot

    # Gebaute App finden (Session-isoliertes DerivedData zuerst, Fallback auf global)
    local APP_PATH
    APP_PATH=$(find "$SESSION_DERIVED_DATA"/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
    if [ -z "$APP_PATH" ]; then
        APP_PATH=$(find "$DERIVED_DATA"/FocusBlox-*/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
    fi
    if [ -z "$APP_PATH" ]; then
        error "Keine gebaute App gefunden! Erst: ./scripts/sim.sh build"
        return 1
    fi

    local BUNDLE_ID
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")

    # App beenden, installieren, starten
    xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$SIM_ID" "$APP_PATH"
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" "${EXTRA_ARGS[@]}"

    success "App gestartet ($BUNDLE_ID)"
    release_sim_lock
}

cmd_navigate() {
    local SCREEN="${1:-}"

    if [ -z "$SCREEN" ]; then
        error "Screen-Name fehlt!"
        echo "Usage: ./scripts/sim.sh navigate <screen>"
        echo ""
        echo "Screens: backlog, blox, day, focus, review, refiner"
        return 1
    fi

    # Validate screen name
    case "$SCREEN" in
        backlog|blox|day|focus|review|refiner|coach) ;;
        *)
            error "Unbekannter Screen: $SCREEN"
            echo "Verfuegbar: backlog, blox, day, focus, review, refiner, coach"
            return 1
            ;;
    esac

    # Relaunch app with --screen argument
    cmd_launch --screen "$SCREEN"
}

cmd_screenshot() {
    local OUTPUT="${1:-/tmp/sim_screenshot.png}"

    # Sicherstellen dass Simulator laeuft
    local STATE
    STATE=$(xcrun simctl list devices 2>/dev/null | grep "$SIM_ID" | grep -o "Booted" || true)
    if [ "$STATE" != "Booted" ]; then
        error "Simulator laeuft nicht! Erst: ./scripts/sim.sh boot"
        return 1
    fi

    rm -f "$OUTPUT" 2>/dev/null || true
    xcrun simctl io "$SIM_ID" screenshot "$OUTPUT" 2>/dev/null

    if [ -f "$OUTPUT" ]; then
        local SIZE
        SIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || echo "0")
        success "Screenshot: $OUTPUT ($SIZE bytes)"
    else
        error "Screenshot fehlgeschlagen!"
        return 1
    fi
}

cmd_test() {
    local TEST_TARGET="${1:-}"

    if [ -z "$TEST_TARGET" ]; then
        error "Test-Name fehlt!"
        echo "Usage: ./scripts/sim.sh test TestClass"
        echo "       ./scripts/sim.sh test TestClass/testMethod"
        return 1
    fi

    info "Fuehre UI Test aus: $TEST_TARGET (Session: ${SESSION_ID:0:8})"
    cd "$PROJECT_DIR"

    # Simulator-Lock fuer exklusiven Zugriff
    acquire_sim_lock

    # Sicherstellen dass Simulator laeuft
    cmd_boot

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$SIM_ID" \
        -derivedDataPath "$SESSION_DERIVED_DATA" \
        -only-testing:"FocusBloxUITests/$TEST_TARGET" \
        -parallel-testing-enabled NO \
        -disable-concurrent-destination-testing \
        CODE_SIGNING_ALLOWED=NO \
        2>&1

    local EXIT_CODE=$?
    release_sim_lock

    if [ $EXIT_CODE -eq 0 ]; then
        success "Test bestanden!"
    elif [ $EXIT_CODE -eq 65 ]; then
        error "Test fehlgeschlagen (Exit 65)"
    elif [ $EXIT_CODE -eq 64 ]; then
        error "Simulator/Syntax-Problem (Exit 64)"
    else
        error "Fehler (Exit $EXIT_CODE)"
    fi

    return $EXIT_CODE
}

cmd_unit() {
    local TEST_TARGET="${1:-}"

    if [ -z "$TEST_TARGET" ]; then
        error "Test-Name fehlt!"
        echo "Usage: ./scripts/sim.sh unit TestClass"
        echo "       ./scripts/sim.sh unit TestClass/testMethod"
        return 1
    fi

    info "Fuehre Unit Test aus: $TEST_TARGET (Session: ${SESSION_ID:0:8})"
    cd "$PROJECT_DIR"

    # Simulator-Lock fuer exklusiven Zugriff
    acquire_sim_lock

    # Sicherstellen dass Simulator laeuft
    cmd_boot

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$SIM_ID" \
        -derivedDataPath "$SESSION_DERIVED_DATA" \
        -only-testing:"FocusBloxTests/$TEST_TARGET" \
        -parallel-testing-enabled NO \
        2>&1

    local EXIT_CODE=$?
    release_sim_lock

    if [ $EXIT_CODE -eq 0 ]; then
        success "Test bestanden!"
    else
        error "Test fehlgeschlagen (Exit $EXIT_CODE)"
    fi

    return $EXIT_CODE
}

cmd_mac_build() {
    info "Baue macOS App (nativ, Session: ${SESSION_ID:0:8})..."
    cd "$PROJECT_DIR"

    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$MAC_SCHEME" \
        -destination "platform=macOS" \
        -derivedDataPath "$SESSION_DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        -quiet \
        2>&1

    if [ $? -eq 0 ]; then
        success "macOS Build erfolgreich."
    else
        error "macOS Build fehlgeschlagen!"
        return 1
    fi
}

cmd_mac_unit() {
    local TEST_TARGET="${1:-}"

    if [ -z "$TEST_TARGET" ]; then
        error "Test-Name fehlt!"
        echo "Usage: ./scripts/sim.sh mac-unit TestClass"
        echo "       ./scripts/sim.sh mac-unit TestClass/testMethod"
        return 1
    fi

    info "Fuehre macOS Unit Test aus: $TEST_TARGET (Session: ${SESSION_ID:0:8})"
    cd "$PROJECT_DIR"

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$MAC_SCHEME" \
        -destination "platform=macOS" \
        -derivedDataPath "$SESSION_DERIVED_DATA" \
        -only-testing:"FocusBloxMacTests/$TEST_TARGET" \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1

    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        success "macOS Test bestanden!"
    else
        error "macOS Test fehlgeschlagen (Exit $EXIT_CODE)"
    fi

    return $EXIT_CODE
}

cmd_mac_test() {
    local TEST_TARGET="${1:-}"

    if [ -z "$TEST_TARGET" ]; then
        error "Test-Name fehlt!"
        echo "Usage: ./scripts/sim.sh mac-test TestClass"
        echo "       ./scripts/sim.sh mac-test TestClass/testMethod"
        return 1
    fi

    # BUG_111: Pruefen ob Automation Mode ohne Auth-Dialog aktiv ist
    if ! automationmodetool 2>&1 | grep -qi "does not require"; then
        warn "Automation Mode nicht aktiv — TCC-Dialog koennte Tests blockieren!"
        warn "Aktivieren mit: sudo ./scripts/install-tcc-profile.sh --install"
    fi

    info "Fuehre macOS UI Test aus: $TEST_TARGET (Session: ${SESSION_ID:0:8})"
    cd "$PROJECT_DIR"

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$MAC_SCHEME" \
        -destination "platform=macOS" \
        -derivedDataPath "$SESSION_DERIVED_DATA" \
        -only-testing:"FocusBloxMacUITests/$TEST_TARGET" \
        -parallel-testing-enabled NO \
        2>&1

    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        success "macOS UI Test bestanden!"
    else
        error "macOS UI Test fehlgeschlagen (Exit $EXIT_CODE)"
    fi

    return $EXIT_CODE
}

cmd_coach_screenshot() {
    local DRAWER="${1:-}"
    local OUTPUT="${2:-/tmp/coach_screenshot.png}"

    info "Coach-Screenshot (Drawer: ${DRAWER:-auto})..."

    # Simulator-Lock fuer exklusiven Zugriff
    acquire_sim_lock

    # Sicherstellen dass Simulator laeuft
    cmd_boot

    # Gebaute App finden
    local APP_PATH
    APP_PATH=$(find "$SESSION_DERIVED_DATA"/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
    if [ -z "$APP_PATH" ]; then
        APP_PATH=$(find "$DERIVED_DATA"/FocusBlox-*/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
    fi
    if [ -z "$APP_PATH" ]; then
        error "Keine gebaute App gefunden! Erst: ./scripts/sim.sh build"
        release_sim_lock
        return 1
    fi

    local BUNDLE_ID
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")

    # App beenden, installieren, mit Coach-Screen + optionalem Drawer starten
    xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$SIM_ID" "$APP_PATH"

    local LAUNCH_ARGS=("-UITesting" "--coach-tab-layout" "--screen" "coach")
    if [ -n "$DRAWER" ]; then
        case "$DRAWER" in
            morning|daytime|evening)
                LAUNCH_ARGS+=("--open-drawer" "$DRAWER")
                ;;
            *)
                error "Unbekannter Drawer: $DRAWER (morning/daytime/evening)"
                release_sim_lock
                return 1
                ;;
        esac
    fi

    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" "${LAUNCH_ARGS[@]}"

    # Warten bis App UI bereit ist
    sleep 2

    # Screenshot
    rm -f "$OUTPUT" 2>/dev/null || true
    xcrun simctl io "$SIM_ID" screenshot "$OUTPUT" 2>/dev/null

    release_sim_lock

    if [ -f "$OUTPUT" ]; then
        local SIZE
        SIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || echo "0")
        success "Coach-Screenshot: $OUTPUT ($SIZE bytes)"
    else
        error "Screenshot fehlgeschlagen!"
        return 1
    fi
}

cmd_help() {
    echo "sim.sh — FocusBlox Simulator-Toolkit"
    echo ""
    echo "Usage: ./scripts/sim.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  status                          Simulator-Status pruefen"
    echo "  boot                            Simulator starten"
    echo "  build                           App fuer Simulator bauen"
    echo "  launch [--mock] [--screen name] App installieren + starten"
    echo "  navigate <screen>               App neu starten + zum Screen navigieren"
    echo "                                  Screens: backlog, blox, day, focus, review, refiner"
    echo "  screenshot [path]               Screenshot (default: /tmp/sim_screenshot.png)"
    echo "  coach-screenshot [drawer] [path] Coach-Tab Screenshot (drawer: morning/daytime/evening)"
    echo "  test <TestClass[/method]>        UI Test ausfuehren"
    echo "  unit <TestClass[/method]>        Unit Test ausfuehren"
    echo "  mac-build                       macOS App bauen (nativ)"
    echo "  mac-unit <TestClass[/method]>   macOS Unit Test ausfuehren"
    echo "  mac-test <TestClass[/method]>   macOS UI Test ausfuehren"
    echo "  help                            Diese Hilfe"
    echo ""
    echo "Simulator: $SIM_NAME ($SIM_ID)"
}

# ============================================
# MAIN
# ============================================

COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
    status)     cmd_status ;;
    boot)       cmd_boot ;;
    build)      cmd_build ;;
    launch)     cmd_launch "$@" ;;
    navigate)   cmd_navigate "$@" ;;
    screenshot)       cmd_screenshot "$@" ;;
    coach-screenshot) cmd_coach_screenshot "$@" ;;
    test)       cmd_test "$@" ;;
    unit)       cmd_unit "$@" ;;
    mac-build)  cmd_mac_build ;;
    mac-unit)   cmd_mac_unit "$@" ;;
    mac-test)   cmd_mac_test "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
        error "Unbekannter Befehl: $COMMAND"
        cmd_help
        exit 1
        ;;
esac
