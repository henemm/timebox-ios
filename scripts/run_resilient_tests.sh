#!/bin/bash
#
# run_resilient_tests.sh - Stabiler UI Test Runner
#
# Loest die haeufigsten Probleme mit xcodebuild test:
# - Exit Code 64 (Simulator nicht bereit)
# - Zombie-Prozesse
# - Flaky Tests durch Race Conditions
#
# Usage:
#   ./scripts/run_resilient_tests.sh                    # Alle UI Tests
#   ./scripts/run_resilient_tests.sh TestClass          # Spezifische Klasse
#   ./scripts/run_resilient_tests.sh TestClass/testMethod  # Spezifischer Test
#

set -e

# Konfiguration
PROJECT="FocusBlox.xcodeproj"
SCHEME="FocusBlox"
SIMULATOR_NAME="FocusBlox"
SIMULATOR_UUID="877731AF-6250-4E23-A07E-80270C69D827"
MAX_RETRIES=2
TIMEOUT=300

# Farben fuer Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================
# Phase 1: Simulator vorbereiten
# ============================================
prepare_simulator() {
    log_info "Phase 1: Simulator vorbereiten..."

    # Zombie-Prozesse beenden
    log_info "Beende haengende Simulator-Prozesse..."
    killall "Simulator" 2>/dev/null || true
    xcrun simctl shutdown all 2>/dev/null || true
    sleep 1

    # Pruefen ob Simulator existiert
    if ! xcrun simctl list devices available | grep -q "$SIMULATOR_UUID"; then
        log_warn "Simulator mit UUID $SIMULATOR_UUID nicht gefunden!"

        # Versuche nach Name zu finden
        FOUND_UUID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | head -1 | sed -E 's/.* \(([A-F0-9-]*)\).*/\1/')

        if [ -n "$FOUND_UUID" ]; then
            log_info "Gefunden: $SIMULATOR_NAME mit UUID $FOUND_UUID"
            SIMULATOR_UUID="$FOUND_UUID"
        else
            # Simulator neu erstellen
            log_info "Erstelle neuen Simulator..."
            SIMULATOR_UUID=$(xcrun simctl create "$SIMULATOR_NAME" "iPhone 16 Pro" "iOS26.2")
            log_success "Neuer Simulator erstellt: $SIMULATOR_UUID"
            log_warn "WICHTIG: UUID in CLAUDE.md aktualisieren!"
        fi
    fi

    # Simulator booten
    log_info "Boote Simulator $SIMULATOR_UUID..."
    xcrun simctl boot "$SIMULATOR_UUID" 2>/dev/null || true

    # Warten bis Simulator bereit
    log_info "Warte auf Simulator-Bereitschaft..."
    if ! xcrun simctl bootstatus "$SIMULATOR_UUID" -b 2>/dev/null; then
        log_error "Simulator konnte nicht gebootet werden!"
        return 1
    fi

    log_success "Simulator bereit."
    return 0
}

# ============================================
# Phase 2: Tests ausfuehren
# ============================================
run_tests() {
    local TEST_TARGET="$1"
    local ATTEMPT="$2"

    log_info "Phase 2: Tests ausfuehren (Versuch $ATTEMPT/$MAX_RETRIES)..."

    # Test-Filter bauen
    local ONLY_TESTING=""
    if [ -n "$TEST_TARGET" ]; then
        ONLY_TESTING="-only-testing:FocusBloxUITests/$TEST_TARGET"
        log_info "Teste nur: $TEST_TARGET"
    else
        log_info "Teste alle UI Tests"
    fi

    # Temporaere Datei fuer Output
    local OUTPUT_FILE=$(mktemp)

    # Tests ausfuehren mit stabilen Flags
    set +e
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "id=$SIMULATOR_UUID" \
        $ONLY_TESTING \
        -parallel-testing-enabled NO \
        -disable-concurrent-destination-testing \
        -retry-tests-on-failure \
        -resultBundlePath "TestResults_$(date +%s).xcresult" \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee "$OUTPUT_FILE"

    local EXIT_CODE=${PIPESTATUS[0]}
    set -e

    # Ergebnis analysieren
    if [ $EXIT_CODE -eq 0 ]; then
        log_success "Alle Tests bestanden!"
        rm -f "$OUTPUT_FILE"
        return 0
    elif [ $EXIT_CODE -eq 64 ]; then
        log_error "Exit Code 64: Simulator/Kommando-Syntax Problem"
        log_info "Pruefe Simulator-Zustand..."
        xcrun simctl list devices available | grep -E "iPhone|FocusBlox" || true
        rm -f "$OUTPUT_FILE"
        return 64
    elif [ $EXIT_CODE -eq 65 ]; then
        log_error "Exit Code 65: Test-Failure"
        # Fehler extrahieren
        echo ""
        log_info "Fehlgeschlagene Tests:"
        grep -E "(Test Case .* failed|XCTAssert.*failed)" "$OUTPUT_FILE" | head -20 || true
        rm -f "$OUTPUT_FILE"
        return 65
    else
        log_error "Exit Code $EXIT_CODE: Unbekannter Fehler"
        rm -f "$OUTPUT_FILE"
        return $EXIT_CODE
    fi
}

# ============================================
# Phase 3: Ergebnis zusammenfassen
# ============================================
summarize_results() {
    local EXIT_CODE="$1"

    echo ""
    echo "============================================"

    case $EXIT_CODE in
        0)
            log_success "ALLE TESTS BESTANDEN"
            ;;
        64)
            log_error "SIMULATOR-PROBLEM"
            echo ""
            echo "Moegliche Loesungen:"
            echo "1. Simulator manuell starten: open -a Simulator"
            echo "2. UUID in CLAUDE.md pruefen"
            echo "3. Simulator neu erstellen:"
            echo "   xcrun simctl create 'FocusBlox' 'iPhone 16 Pro' 'iOS26.2'"
            ;;
        65)
            log_error "TESTS FEHLGESCHLAGEN"
            echo ""
            echo "Naechste Schritte:"
            echo "1. /inspect-ui ausfuehren fuer Accessibility Tree"
            echo "2. Fehlerursache analysieren"
            echo "3. Gezielt fixen (NICHT spekulativ!)"
            ;;
        *)
            log_error "UNBEKANNTER FEHLER (Exit $EXIT_CODE)"
            echo ""
            echo "Vollstaendigen Output pruefen."
            ;;
    esac

    echo "============================================"
    return $EXIT_CODE
}

# ============================================
# Main
# ============================================
main() {
    local TEST_TARGET="${1:-}"

    echo "============================================"
    echo "  FocusBlox Resilient Test Runner"
    echo "============================================"
    echo ""

    # Simulator vorbereiten
    if ! prepare_simulator; then
        log_error "Simulator-Vorbereitung fehlgeschlagen"
        exit 64
    fi

    # Tests mit Retry-Logik
    local attempt=1
    local exit_code=0

    while [ $attempt -le $MAX_RETRIES ]; do
        if run_tests "$TEST_TARGET" "$attempt"; then
            exit_code=0
            break
        else
            exit_code=$?

            # Bei Exit 64 keinen Retry - Simulator-Problem
            if [ $exit_code -eq 64 ]; then
                log_warn "Exit 64 - Kein Retry sinnvoll"
                break
            fi

            # Bei Exit 65 - Retry bei Flaky Tests
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_warn "Retry in 3 Sekunden..."
                sleep 3
            fi
        fi

        attempt=$((attempt + 1))
    done

    summarize_results $exit_code
    exit $exit_code
}

main "$@"
