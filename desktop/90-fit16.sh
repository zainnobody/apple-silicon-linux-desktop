#!/bin/bash
# Fit the design to the 16 inch MacBook Pro panel (3456x2160) and use one flat gradient wallpaper on the desktop and the lock screen.
# User level, no root. Needs a running Plasma session. Backup first (undo script in ~/desktop-design-backups).
# Usage: 90-fit16.sh [SCALE]    default scale 2 (1728x1080, the same size as the macOS default on this panel). The old scale was 2.7.
# Undo the scale only:  kscreen-doctor output.eDP-1.scale.2.7
. "$(dirname "$0")/lib.sh"
SCALE="${1:-2}"; OUTPUT="${OUTPUT:-eDP-1}"
WP_DIR="$DATA/wallpapers/m3-flat"; WP="$WP_DIR/m3-flat-blue.png"
session_up || { say "No Plasma session."; exit 1; }
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 90-fit16
kscreen-doctor "output.$OUTPUT.scale.$SCALE"
mkdir -p "$WP_DIR"
python3 "$HERE/assets/make-wallpaper.py" "$WP"
plasma-apply-wallpaperimage "$WP"
[ -x "$HERE/80-lockscreen.sh" ] && "$HERE/80-lockscreen.sh" image "$WP"
# Dock: a little taller, like the macOS dock on a 16 inch panel
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s \
  'panels().forEach(function(p){ if (p.location == "bottom") { p.height = 68; } });' >/dev/null
say "Done: scale $SCALE, flat wallpaper, dock 68."
