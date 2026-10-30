#!/bin/bash
# Apply the whole desktop design in order. Each stage makes its own backup and undo script (see backup.sh).
# Usage: apply-all.sh [light|dark]    Needs a running Plasma session for the panel stage.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
mode="${1:-light}"
"$HERE/fetch-themes.sh"
"$HERE/10-themes.sh"
"$HERE/20-appearance.sh" "$mode"
"$HERE/40-search-and-overview.sh"
"$HERE/50-apps.sh"
"$HERE/60-notifications.sh"
"$HERE/30-panels.sh"
# Helper to switch light and dark later
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/m3-desktop-design" "$HOME/.local/bin"
cp "$HERE"/*.sh "$HERE/m3-appearance" "${XDG_DATA_HOME:-$HOME/.local/share}/m3-desktop-design/"
ln -sfn "${XDG_DATA_HOME:-$HOME/.local/share}/m3-desktop-design/m3-appearance" "$HOME/.local/bin/m3-appearance"
echo "Done. Switch look: m3-appearance light|dark"
