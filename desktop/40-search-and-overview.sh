#!/bin/bash
# Meta+Space (Cmd+Space on a Mac keyboard) opens KRunner in the middle of the screen, like Spotlight.
# Turns off the heavy effects (blur, wobbly windows, magic lamp). Overview is kept, without a blurred background.
. "$(dirname "$0")/lib.sh"
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 40-search-and-overview

kw krunnerrc FreeFloating true General
kw krunnerrc ActivateWhenTypingOnDesktop false General
kw kglobalshortcutsrc _launch $'Meta+Space\tAlt+Space\tAlt+F2' services org.kde.krunner.desktop

kwb kwinrc blurEnabled false Plugins
kwb kwinrc contrastEnabled false Plugins
kwb kwinrc wobblywindowsEnabled false Plugins
kwb kwinrc magiclampEnabled false Plugins
kwb kwinrc overviewEnabled true Plugins
kwb kwinrc BlurBackground false Effect-overview
# Hot corner and three-finger swipe are set by 45-gestures.sh after the live check.

if session_up; then
	reload_kwin
	# reconfigure does not unload a running effect, so unload the heavy ones now
	for e in blur contrast wobblywindows magiclamp; do
		busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects unloadEffect s "$e" >/dev/null 2>&1 || true
	done
	systemctl --user restart plasma-kglobalaccel.service || true
fi
say "Search and effects set."
