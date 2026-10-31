#!/bin/bash
# Take a full-screen screenshot inside the running Plasma session (for before and after pictures).
# Usage: session-shot.sh OUT.png [APP...]   Starts each APP with the session environment first, then closes it again.
# Apps must start with the plasmashell environment. A plain SSH shell lacks the Qt platform theme, so the colours are wrong.
. "$(dirname "$0")/lib.sh"
out="${1:?usage: session-shot.sh OUT.png [APP...]}"; shift
session_up || { say "No Plasma session."; exit 1; }
pid=$(pgrep -u "$(id -u)" -x plasmashell | head -1)
while IFS= read -r -d '' kv; do
	case "$kv" in WAYLAND_DISPLAY=*|XDG_*|QT_*|DBUS_SESSION_BUS_ADDRESS=*|KDE_*|DESKTOP_SESSION=*|XCURSOR_*|LANG=*) export "$kv" ;; esac
done </proc/"$pid"/environ
for a in "$@"; do nohup "$a" >/dev/null 2>&1 & sleep 1; done
[ $# -gt 0 ] && sleep 7
timeout 40 spectacle -b -n -f -o "$out"
for a in "$@"; do pkill -u "$(id -u)" -x "$a" || true; done
