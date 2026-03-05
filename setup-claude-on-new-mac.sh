#!/bin/bash
# ============================================================
# Claude Code Setup fuer neuen Mac
# Uebertraegt alle Einstellungen, die NICHT im Git-Repo liegen
# ============================================================
# Verwendung:
#   1. Dieses Script + die 3 Dateien auf den neuen Mac kopieren
#   2. chmod +x setup-claude-on-new-mac.sh
#   3. ./setup-claude-on-new-mac.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="$HOME/.claude"

echo "=== Claude Code Setup ==="
echo ""

# 1. Globales Verzeichnis anlegen
mkdir -p "$CLAUDE_HOME"
echo "[1/4] ~/.claude/ Verzeichnis bereit"

# 2. Globale CLAUDE.md kopieren
if [ -f "$SCRIPT_DIR/transfer/CLAUDE.md" ]; then
    cp "$SCRIPT_DIR/transfer/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"
    echo "[2/4] Globale CLAUDE.md installiert"
else
    echo "[2/4] WARNUNG: transfer/CLAUDE.md nicht gefunden - uebersprungen"
fi

# 3. Globale settings.json kopieren
if [ -f "$SCRIPT_DIR/transfer/global-settings.json" ]; then
    cp "$SCRIPT_DIR/transfer/global-settings.json" "$CLAUDE_HOME/settings.json"
    echo "[3/4] Globale settings.json installiert"
else
    echo "[3/4] WARNUNG: transfer/global-settings.json nicht gefunden - uebersprungen"
fi

# 4. Projekt-spezifische Dateien
# settings.local.json ins Projekt kopieren
PROJECT_DIR="$SCRIPT_DIR"
if [ -f "$SCRIPT_DIR/transfer/settings.local.json" ]; then
    cp "$SCRIPT_DIR/transfer/settings.local.json" "$PROJECT_DIR/.claude/settings.local.json"
    echo "[4/4] Projekt settings.local.json installiert"
else
    echo "[4/4] WARNUNG: transfer/settings.local.json nicht gefunden - uebersprungen"
fi

# Memory-Verzeichnis wird beim ersten Claude Code Start automatisch angelegt
# MEMORY.md wird von Claude selbst befuellt

echo ""
echo "=== Fertig! ==="
echo ""
echo "Naechste Schritte:"
echo "  1. Claude Code installieren (falls noch nicht): npm install -g @anthropic-ai/claude-code"
echo "  2. Im Projektverzeichnis 'claude' starten"
echo "  3. Memory wird automatisch aufgebaut"
echo ""
echo "Hinweis: Die Projekt-Settings (.claude/settings.json) und alle"
echo "Hooks/Commands/Agents kommen automatisch mit 'git clone'."
