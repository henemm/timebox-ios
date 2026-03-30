#!/bin/bash
# install-tcc-profile.sh — Aktiviert Automation Mode fuer macOS UI Tests
# Loest BUG_111: TCC-Dialog "Enable UI Automation" blockiert Tests via SSH
# macOS 26: automationmodetool ist die einzige SSH-taugliche Methode

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    echo "Usage: $0 [--install | --uninstall | --status]"
    echo ""
    echo "  --install     Aktiviert Automation Mode ohne Auth-Dialog (benoetigt sudo)"
    echo "  --uninstall   Deaktiviert Automation Mode ohne Auth (benoetigt sudo)"
    echo "  --status      Prueft ob Automation Mode aktiv ist"
    echo ""
    echo "Ohne Argumente: --status"
}

check_automation_mode() {
    automationmodetool 2>&1 | grep -qi "does not require"
}

cmd_status() {
    if check_automation_mode; then
        info "Automation Mode aktiv (ohne Auth-Dialog)"
        return 0
    else
        warn "Automation Mode NICHT aktiv — TCC-Dialog koennte Tests blockieren"
        echo "  Aktivieren mit: sudo $0 --install"
        return 1
    fi
}

cmd_install() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Installation benoetigt sudo"
        echo "  Ausfuehren mit: sudo $0 --install"
        return 1
    fi

    if check_automation_mode; then
        info "Automation Mode ist bereits aktiv"
        return 0
    fi

    info "Aktiviere Automation Mode ohne Auth-Dialog..."
    automationmodetool enable-automationmode-without-authentication

    if check_automation_mode; then
        info "Automation Mode erfolgreich aktiviert!"
        info "macOS UI Tests koennen jetzt ohne TCC-Dialog ausgefuehrt werden."
    else
        error "Aktivierung fehlgeschlagen"
        return 1
    fi
}

cmd_uninstall() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Deaktivierung benoetigt sudo"
        echo "  Ausfuehren mit: sudo $0 --uninstall"
        return 1
    fi

    if ! check_automation_mode; then
        info "Automation Mode ist bereits deaktiviert — nichts zu tun"
        return 0
    fi

    info "Deaktiviere Automation Mode ohne Auth..."
    automationmodetool disable-automationmode-without-authentication

    if ! check_automation_mode; then
        info "Automation Mode deaktiviert"
    else
        error "Deaktivierung fehlgeschlagen"
        return 1
    fi
}

case "${1:---status}" in
    --install)   cmd_install ;;
    --uninstall) cmd_uninstall ;;
    --status)    cmd_status ;;
    --help|-h)   usage ;;
    *)           usage; exit 1 ;;
esac
