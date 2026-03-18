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
#   ./scripts/sim.sh screenshot                     # Screenshot → /tmp/sim_screenshot.png
#   ./scripts/sim.sh screenshot /path/to/output.png # Screenshot → custom path
#   ./scripts/sim.sh test TestClass                 # UI Test ausfuehren
#   ./scripts/sim.sh test TestClass/testMethod      # Einzelnen Test ausfuehren
#   ./scripts/sim.sh unit TestClass                 # Unit Test ausfuehren
#   ./scripts/sim.sh unit TestClass/testMethod      # Einzelnen Unit Test ausfuehren
#

set -eo pipefail

# ============================================
# KONFIGURATION — Einzige Quelle der Wahrheit
# ============================================
SIM_ID="1EC79950-6704-47D0-BDF8-2C55236B4B40"
SIM_NAME="FocusBlox"
PROJECT="FocusBlox.xcodeproj"
SCHEME="FocusBlox"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

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

    # Gebaute App pruefen
    local APP_PATH
    APP_PATH=$(find "$DERIVED_DATA"/FocusBlox-*/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
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
    info "Baue App fuer Simulator..."
    cd "$PROJECT_DIR"

    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "id=$SIM_ID" \
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
    local MOCK_FLAG=""
    if [ "${1:-}" = "--mock" ]; then
        MOCK_FLAG="-UITesting"
        info "Starte App mit Mock-Daten..."
    else
        info "Starte App..."
    fi

    # Sicherstellen dass Simulator laeuft
    cmd_boot

    # Gebaute App finden
    local APP_PATH
    APP_PATH=$(find "$DERIVED_DATA"/FocusBlox-*/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
    if [ -z "$APP_PATH" ]; then
        error "Keine gebaute App gefunden! Erst: ./scripts/sim.sh build"
        return 1
    fi

    local BUNDLE_ID
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")

    # App beenden, installieren, starten
    xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$SIM_ID" "$APP_PATH"
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" $MOCK_FLAG

    success "App gestartet ($BUNDLE_ID)"
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

    info "Fuehre UI Test aus: $TEST_TARGET"
    cd "$PROJECT_DIR"

    # Sicherstellen dass Simulator laeuft
    cmd_boot

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "id=$SIM_ID" \
        -only-testing:"FocusBloxUITests/$TEST_TARGET" \
        -parallel-testing-enabled NO \
        -disable-concurrent-destination-testing \
        CODE_SIGNING_ALLOWED=NO \
        2>&1

    local EXIT_CODE=$?

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

    info "Fuehre Unit Test aus: $TEST_TARGET"
    cd "$PROJECT_DIR"

    # Sicherstellen dass Simulator laeuft
    cmd_boot

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "id=$SIM_ID" \
        -only-testing:"FocusBloxTests/$TEST_TARGET" \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1

    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        success "Test bestanden!"
    else
        error "Test fehlgeschlagen (Exit $EXIT_CODE)"
    fi

    return $EXIT_CODE
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
    echo "  launch [--mock]                 App installieren + starten"
    echo "  screenshot [path]               Screenshot (default: /tmp/sim_screenshot.png)"
    echo "  test <TestClass[/method]>        UI Test ausfuehren"
    echo "  unit <TestClass[/method]>        Unit Test ausfuehren"
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
    screenshot) cmd_screenshot "$@" ;;
    test)       cmd_test "$@" ;;
    unit)       cmd_unit "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
        error "Unbekannter Befehl: $COMMAND"
        cmd_help
        exit 1
        ;;
esac
