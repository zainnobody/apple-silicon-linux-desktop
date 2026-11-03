#!/bin/bash
# Flat Apple-style lock screen for KDE Plasma 6.7 (kscreenlocker). User level only. No root. No PAM change.
# In Plasma 6.7 the lock screen QML is part of the desktop shell package (org.kde.plasma.desktop), not of the look-and-feel package.
# Usage:
#   80-lockscreen.sh build      make a test package "org.m3.flat" in ~/.local/share/plasma/shells (does not change the real lock screen)
#   80-lockscreen.sh test [flat|stock] [OUT.png]   open the greeter in test mode (a window, no lock) and take a screenshot
#   80-lockscreen.sh install    use the flat lock screen for real: a user copy of the shell package shadows the system one
#   80-lockscreen.sh touchid    stock lock screen that starts the Touch ID check at lock, with no key press (tested on Plasma 6.8.2)
#   80-lockscreen.sh remove     remove the user copy and the guard. The stock lock screen is back at the next login or lock.
#   80-lockscreen.sh colour #RRGGBB | image /path.png    set the lock screen wallpaper (flat colour is the default)
# Why a full copy: Plasma loads the shell package by id and takes the first match in the user folder. The copy is the system package
# (468 KB) with only the lockscreen folder changed. A guard in ~/.config/plasma-workspace/env removes the copy when the system package changes,
# so a Plasma update never runs a stale copy.
. "$(dirname "$0")/lib.sh"
SYS=/usr/share/plasma/shells/org.kde.plasma.desktop
SHELLS="$DATA/plasma/shells"
STATE="$DATA/m3-lockscreen"
GUARD="$CFG/plasma-workspace/env/m3-lockscreen-guard.sh"
LOCK_COLOR="${LOCK_COLOR:-#0b3d91}"
PKG="$HERE/lockscreen"

fingerprint() { # changes when the system shell package changes
	( cd "$SYS" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1 )
}
make_pkg() { # id [flat|stock] [visible]   flat = our lock screen, stock = system lock screen; visible = show the prompt at start (tests only)
	local id=$1 kind=${2:-flat} vis=${3:-} dst="$SHELLS/$1"
	[ -d "$SYS" ] || { say "System shell package not found: $SYS"; exit 1; }
	[ -f "$PKG/FlatFader.qml" ] || { say "Missing $PKG"; exit 1; }
	rm -rf "$dst"; mkdir -p "$SHELLS"
	cp -r "$SYS" "$dst"
	if [ "$kind" = flat ]; then
		rm -rf "$dst/contents/lockscreen"; mkdir -p "$dst/contents/lockscreen"
		cp "$PKG"/*.qml "$PKG"/*.xml "$PKG"/qmldir "$dst/contents/lockscreen/"
	fi
	# Test variants only: keep the prompt on screen. The real QML hides it on the first mouse move, on pointer exit and after 10 s.
	if [ "$vis" = visible ]; then
		sed -i -e 's/property bool uiVisible: false/property bool uiVisible: true/' \
			-e 's/uiVisible = seenPositionChange;/uiVisible = true;/' \
			-e 's/interval: 10000/interval: 3600000/' \
			-e '/onExited: {/,/}/ s/uiVisible = false;/uiVisible = true;/' "$dst/contents/lockscreen/LockScreenUi.qml"
	fi
	sed -i "s/\"Id\": \"org.kde.plasma.desktop\"/\"Id\": \"$id\"/" "$dst/metadata.json"
}
write_guard() { # record the system shell and install the login guard that removes a stale copy
	mkdir -p "$STATE" "$(dirname "$GUARD")"
	fingerprint >"$STATE/system-shell.sha"
	cat >"$GUARD" <<GUARDEOF
#!/bin/sh
# Written by 80-lockscreen.sh. Runs at login before plasmashell. If the system shell package changed (a Plasma update),
# the user copy is stale, so remove it and the stock shell and lock screen are used.
SYS=$SYS
STATE=$STATE
now=\$(cd "\$SYS" 2>/dev/null && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
if [ "\$now" != "\$(cat "\$STATE/system-shell.sha" 2>/dev/null)" ]; then
	rm -rf "$SHELLS/org.kde.plasma.desktop"
fi
GUARDEOF
	chmod +x "$GUARD"
}
set_wallpaper() { # colour value
	kw kscreenlockerrc WallpaperPlugin org.kde.color Greeter
	kw kscreenlockerrc Color "$1" Greeter Wallpaper org.kde.color General
}

case "${1:-}" in
build)
	[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 80-lockscreen-build
	make_pkg org.m3.flat flat; make_pkg org.m3.flat-test flat visible; make_pkg org.m3.stock-test stock visible
	say "Test packages in $SHELLS: org.m3.flat, org.m3.flat-test, org.m3.stock-test" ;;
test)
	# test [flat|stock] [OUT.png]. The greeter runs in test mode: a window, no lock, no password needed.
	which="${2:-flat}"; out="${3:-/tmp/lock-test-$which.png}"
	session_up || { say "No Plasma session."; exit 1; }
	[ -d "$SHELLS/org.m3.$which-test" ] || { say "Run build first."; exit 1; }
	# A locked session gives blank screenshots, and the user may be at the lock screen.
	loginctl show-session "$(loginctl show-user "$(id -u)" -p Display --value)" -p LockedHint --value | grep -q yes && { say "The session is locked. Test later."; exit 1; }
	pid=$(pgrep -u "$(id -u)" -x plasmashell | head -1)
	while IFS= read -r -d '' kv; do case "$kv" in WAYLAND_DISPLAY=*|XDG_*|QT_*|DBUS_SESSION_BUS_ADDRESS=*|KDE_*|DESKTOP_SESSION=*|XCURSOR_*|LANG=*) export "$kv" ;; esac; done </proc/"$pid"/environ
	# This Plasma version has no --theme option. The test mode reads the shell package id from PLASMA_DEFAULT_SHELL.
	( PLASMA_DEFAULT_SHELL="org.m3.$which-test" timeout "${LOCK_TEST_SECONDS:-20}" /usr/libexec/kscreenlocker_greet --testing >"/tmp/lock-test-$which.log" 2>&1 & )
	sleep 6
	timeout 40 spectacle -b -n -f -o "$out"
	# the pattern has a bracket so that pkill does not match this shell
	pkill -u "$(id -u)" -f '[k]screenlocker_greet --testing' || true
	say "Screenshot: $out. Greeter log: /tmp/lock-test-$which.log" ;;
install)
	[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 80-lockscreen-install
	[ -d "$SHELLS/org.m3.flat" ] || { say "Run build and test first."; exit 1; }
	make_pkg org.kde.plasma.desktop
	write_guard
	# Keep a wallpaper that is already set (for example by 90-fit16.sh). Set the flat colour only when none is set.
	[ -n "$(kreadconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin)" ] || set_wallpaper "$LOCK_COLOR"
	say "Installed. The flat lock screen is used from the next lock. plasmashell loads the copy at the next login (it is identical code)." ;;
touchid)
	# Stock lock screen plus two edits: start the fingerprint check when the lock screen opens, and keep the
	# 1 s heartbeat running while locked. Stock KDE starts it only after a key press or mouse move (uiVisible),
	# so a finger on the Touch ID key did nothing on the clock screen.
	[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 80-lockscreen-touchid
	make_pkg org.kde.plasma.desktop stock
	python3 - "$SHELLS/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml" <<'PY' || { rm -rf "$SHELLS/org.kde.plasma.desktop"; exit 1; }
import sys
p = sys.argv[1]; s = open(p).read()
a = """        Timer { // heart beat keeping the backend active for as long as we are in visible state
            interval: 1000
            running: !authenticator.unlocked && parent.uiVisible"""
b = """        Timer { // heart beat keeping the backend active while locked (M3: also before uiVisible, for Touch ID)
            interval: 1000
            running: !authenticator.unlocked"""
c = """        Component.onCompleted: launchAnimation.start();
"""
d = """        // M3: also start the fingerprint check as soon as the screen locks, like macOS. Stock KDE waits
        // for a mouse move or key press (uiVisible), so a finger on the Touch ID key did nothing.
        Component.onCompleted: {
            launchAnimation.start();
            authenticator.startAuthenticating();
        }
"""
if s.count(a) != 1 or s.count(c) != 1:
    sys.exit("This Plasma lock screen differs from 6.8.2. Nothing changed.")
open(p, "w").write(s.replace(a, b).replace(c, d))
PY
	write_guard
	say "Installed. The Touch ID check starts at the next lock. After a Plasma update the guard removes the copy at login; run touchid again." ;;
remove)
	rm -rf "$SHELLS/org.kde.plasma.desktop" "$SHELLS"/org.m3.* "$GUARD" "$STATE"
	kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin --delete
	say "Removed. The stock lock screen is back." ;;
colour|color) set_wallpaper "${2:?#RRGGBB}" ;;
image)
	kw kscreenlockerrc WallpaperPlugin org.kde.image Greeter
	kw kscreenlockerrc Image "file://${2:?path}" Greeter Wallpaper org.kde.image General ;;
*) sed -n '2,12p' "$0"; exit 2 ;;
esac
