#!/bin/bash
# Install the M3 Flat icon theme (original icons drawn for this pack, see icons/m3-flat). User level, no root.
# The theme overrides the dock apps, the folder, the trash and the launcher. Everything else comes from KDE Breeze (Inherits).
# Usage: 86-icons.sh [install|remove]      install also switches the icon theme (light or dark, as the colour scheme).
. "$(dirname "$0")/lib.sh"
I="$DATA/icons"
theme() { # dir Name Inherits
	cat >"$I/$1/index.theme" <<THEME
[Icon Theme]
Name=$2
Comment=Original flat icons for the M3 desktop design pack
Inherits=$3
FollowsColorScheme=true
Directories=scalable/apps,scalable/places,scalable/mimetypes

[scalable/apps]
Size=128
MinSize=8
MaxSize=512
Type=Scalable
Context=Applications

[scalable/places]
Size=128
MinSize=8
MaxSize=512
Type=Scalable
Context=Places

[scalable/mimetypes]
Size=128
MinSize=8
MaxSize=512
Type=Scalable
Context=MimeTypes
THEME
}
case "${1:-install}" in
install)
	[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 86-icons
	rm -rf "$I/m3-flat" "$I/m3-flat-dark"; mkdir -p "$I/m3-flat" "$I/m3-flat-dark"
	cp -r "$HERE/icons/m3-flat/scalable" "$I/m3-flat/"
	mkdir -p "$I/m3-flat/scalable/mimetypes"; ln -sfn ../places/folder.svg "$I/m3-flat/scalable/mimetypes/inode-directory.svg"
	theme m3-flat "M3 Flat" breeze
	ln -sfn ../m3-flat/scalable "$I/m3-flat-dark/scalable"
	theme m3-flat-dark "M3 Flat Dark" breeze-dark
	for d in m3-flat m3-flat-dark; do gtk-update-icon-cache -q -f "$I/$d" 2>/dev/null || true; done
	# switch the icon theme to match the current colour scheme
	if [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" = WhiteSurDark ]; then T=m3-flat-dark; else T=m3-flat; fi
	kw kdeglobals Theme "$T" Icons
	notify_change 1; notify_change 4
	say "M3 Flat icons installed and set ($T). Log out and in if some icons keep the old look." ;;
remove)
	rm -rf "$I/m3-flat" "$I/m3-flat-dark"
	if [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" = WhiteSurDark ]; then T=breeze-dark; else T=breeze; fi
	kw kdeglobals Theme "$T" Icons; notify_change 1; notify_change 4
	say "M3 Flat icons removed. Icon theme: $T." ;;
*) say "usage: $0 [install|remove]"; exit 2 ;;
esac
