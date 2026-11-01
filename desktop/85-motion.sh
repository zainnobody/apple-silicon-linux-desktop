#!/bin/bash
# Small, cheap motion. User level, no root. No new effect is loaded and no effect uses blur or shaders.
# Usage: 85-motion.sh [light|default|off]   default: light
#   light    animations about 25 percent faster than the Plasma default (factor 0.75), like the snappy macOS feel
#   default  Plasma default speed (factor 1)
#   off      no animations (factor 0)
# Light effects that stay on: window open and close (scale), minimize (squash), maximize, desktop slide, popups (slide and fade).
# Heavy effects stay off: blur, contrast, wobbly windows, magic lamp.
. "$(dirname "$0")/lib.sh"
mode="${1:-light}"
case "$mode" in light) F=0.75 ;; default) F=1 ;; off) F=0 ;; *) say "usage: $0 [light|default|off]"; exit 2 ;; esac
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup "85-motion-$mode"
kw kdeglobals AnimationDurationFactor "$F" KDE
for e in scale squash maximize slide slidingpopups fadingpopups; do kwb kwinrc "${e}Enabled" true Plugins; done
for e in blur contrast wobblywindows magiclamp; do kwb kwinrc "${e}Enabled" false Plugins; done
if session_up; then
	reload_kwin
	for e in scale squash maximize slide slidingpopups fadingpopups; do
		busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects loadEffect s "$e" >/dev/null 2>&1 || true
	done
	for e in blur contrast wobblywindows magiclamp; do
		busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects unloadEffect s "$e" >/dev/null 2>&1 || true
	done
fi
say "Motion: $mode (factor $F)."
