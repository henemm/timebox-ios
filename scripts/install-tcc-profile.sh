#!/bin/bash
# install-tcc-profile.sh — Installiert/deinstalliert das PPPC-Profil fuer macOS UI Test Automation
# Loest BUG_111: TCC-Dialog "Enable UI Automation" blockiert Tests via SSH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE_PATH="$SCRIPT_DIR/focusblox-uitest-tcc.mobileconfig"
PROFILE_IDENTIFIER="com.henning.focusblox.uitest-tcc"

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
    echo "  --install     Installiert das PPPC-Profil (benoetigt sudo)"
    echo "  --uninstall   Entfernt das PPPC-Profil (benoetigt sudo)"
    echo "  --status      Prueft ob das Profil installiert ist"
    echo ""
    echo "Ohne Argumente: --status"
}

check_profile_installed() {
    if profiles -P 2>/dev/null | grep -q "$PROFILE_IDENTIFIER"; then
        return 0
    fi
    return 1
}

cmd_status() {
    if check_profile_installed; then
        info "PPPC-Profil ist installiert ($PROFILE_IDENTIFIER)"
        return 0
    else
        warn "PPPC-Profil ist NICHT installiert"
        echo "  Installieren mit: sudo $0 --install"
        return 1
    fi
}

cmd_install() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Installation benoetigt sudo"
        echo "  Ausfuehren mit: sudo $0 --install"
        return 1
    fi

    if [ ! -f "$PROFILE_PATH" ]; then
        error "Profil nicht gefunden: $PROFILE_PATH"
        return 1
    fi

    if check_profile_installed; then
        info "Profil ist bereits installiert"
        return 0
    fi

    info "Installiere PPPC-Profil..."
    profiles install -type configuration -path "$PROFILE_PATH"

    if check_profile_installed; then
        info "Profil erfolgreich installiert!"
        info "macOS UI Tests koennen jetzt ohne TCC-Dialog ausgefuehrt werden."
    else
        error "Installation fehlgeschlagen — Profil nicht in 'profiles -P' gefunden"
        return 1
    fi
}

cmd_uninstall() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Deinstallation benoetigt sudo"
        echo "  Ausfuehren mit: sudo $0 --uninstall"
        return 1
    fi

    if ! check_profile_installed; then
        info "Profil ist nicht installiert — nichts zu tun"
        return 0
    fi

    info "Entferne PPPC-Profil..."
    profiles remove -identifier "$PROFILE_IDENTIFIER"

    if ! check_profile_installed; then
        info "Profil erfolgreich entfernt"
    else
        error "Deinstallation fehlgeschlagen"
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
