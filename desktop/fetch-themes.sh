#!/bin/bash
# Download the pinned WhiteSur repositories. Each goes into its own new folder. No root. Needs network.
. "$(dirname "$0")/lib.sh"
mkdir -p "$DL"
get() { # name sha
	local d="$DL/$1-$2"
	[ -d "$d" ] && { say "have $d"; return; }
	mkdir "$d"
	git -C "$d" init -q
	git -C "$d" remote add origin "https://github.com/vinceliuice/$1.git"
	timeout 600 git -C "$d" fetch -q --depth 1 origin "$2"
	git -C "$d" checkout -q FETCH_HEAD
	say "$1 $(git -C "$d" rev-parse HEAD) $(du -sh "$d" | cut -f1)"
}
get WhiteSur-kde "$WHITESUR_KDE"
get WhiteSur-icon-theme "$WHITESUR_ICONS"
get WhiteSur-cursors "$WHITESUR_CURSORS"
