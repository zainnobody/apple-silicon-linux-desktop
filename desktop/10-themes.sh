#!/bin/bash
# Install the WhiteSur colour schemes, window decoration, Plasma theme, icons and cursors for this user.
# Source: github.com/vinceliuice/WhiteSur-kde, -icon-theme, -cursors (GPL-3.0), fetched by fetch-themes.sh at pinned commits.
# Only flat parts are installed: opaque window decoration, a "solid" Plasma theme (no see-through panels), no Kvantum, no SDDM.
# No upstream script is run. This script only copies files out of the downloaded folders.
# Undo: ./backup.sh makes the undo script before this runs. Installed folders are listed in $DATA/m3-design-installed.txt.
. "$(dirname "$0")/lib.sh"
KDE="$DL/WhiteSur-kde-$WHITESUR_KDE"; ICO="$DL/WhiteSur-icon-theme-$WHITESUR_ICONS"; CUR="$DL/WhiteSur-cursors-$WHITESUR_CURSORS"
for d in "$KDE" "$ICO" "$CUR"; do [ -d "$d" ] || { say "missing $d. Run fetch-themes.sh first."; exit 1; }; done
backup 10-themes
LOG="$DATA/m3-design-installed.txt"; : >"$LOG"

# Colour schemes (light and dark)
mkdir -p "$DATA/color-schemes"
for f in WhiteSur WhiteSurDark; do install -m 0644 "$KDE/color-schemes/$f.colors" "$DATA/color-schemes/$f.colors"; echo "$DATA/color-schemes/$f.colors" >>"$LOG"; done

# Window decoration: the opaque variants only. The layout follows the upstream installer (install_aurorae).
mkdir -p "$DATA/aurorae/themes"
for pair in "WhiteSur-opaque:assets" "WhiteSur-dark-opaque:assets-dark"; do
	d=${pair%%:*}; assets=${pair##*:}
	T="$DATA/aurorae/themes/$d"
	rm -rf "$T"
	cp -r "$KDE/aurorae/main-opaque/$d" "$T"
	cp "$KDE/aurorae/common/$assets/"*.svg "$T/"
	cp "$KDE/aurorae/metadata.desktop" "$KDE/aurorae/metadata.json" "$T/"
	cp "$KDE/aurorae/main-opaque/${d}rc" "$T/${d}rc"
	sed -i "s/WhiteSur/$d/g" "$T/metadata.desktop" "$T/metadata.json"
	echo "$T" >>"$LOG"
done

# Plasma theme: copy WhiteSur and WhiteSur-dark, then lay the "solid" files over them so panels and popups are not see-through.
mkdir -p "$DATA/plasma/desktoptheme"
for pair in "WhiteSur:WhiteSur-solid" "WhiteSur-dark:WhiteSur-solid-dark"; do
	src=${pair%%:*}; dst=${pair##*:}
	rm -rf "$DATA/plasma/desktoptheme/$dst"
	cp -r "$KDE/plasma/desktoptheme/$src" "$DATA/plasma/desktoptheme/$dst"
	cp -r "$KDE/plasma/desktoptheme/$src/solid/." "$DATA/plasma/desktoptheme/$dst/"
	cp -r "$KDE/plasma/desktoptheme/icons" "$KDE/plasma/desktoptheme/weather" "$DATA/plasma/desktoptheme/$dst/"
	rm -rf "$DATA/plasma/desktoptheme/$dst/solid"
	sed -i "s/\"Id\": \"$src\"/\"Id\": \"$dst\"/; s/\"Name\": \"$src\"/\"Name\": \"$dst\"/" "$DATA/plasma/desktoptheme/$dst/metadata.json"
	[ -f "$DATA/plasma/desktoptheme/$dst/metadata.desktop" ] && sed -i "s/^Name=.*/Name=$dst/; s/^X-KDE-PluginInfo-Name=.*/X-KDE-PluginInfo-Name=$dst/" "$DATA/plasma/desktoptheme/$dst/metadata.desktop"
	echo "$DATA/plasma/desktoptheme/$dst" >>"$LOG"
done

# Icons: WhiteSur, copied by this script (the upstream installer is not run). Three sets, as upstream builds them:
#   WhiteSur       base set, light symbolic icons for dark panels. Used in dark mode.
#   WhiteSur-light base set with dark symbolic icons for light panels. Used in light mode.
#   WhiteSur-dark  dark-toned symbolic icons for dark toolbars. Used in dark mode.
# The KDE logo replaces the Apple logo (plasma/ folder of the repository).
I="$DATA/icons"; mkdir -p "$I"
atx() { # add the @2x links in a theme folder
	( cd "$1"; for n in actions animations apps categories devices emotes emblems mimes places preferences status; do [ -e "$n" ] && ln -sfn "$n" "$n@2x"; done )
}
T="$I/WhiteSur"; rm -rf "$T"; mkdir -p "$T/status"
cp "$ICO/src/index.theme" "$T/"
cp -r "$ICO"/src/{actions,animations,apps,categories,devices,emotes,emblems,mimes,places,preferences} "$T/"
cp -r "$ICO"/src/status/{16,22,24,32,symbolic} "$T/status/"
cp -r "$ICO"/plasma/* "$T/"
rm -rf "$T"/places/scalable/user-trash{,-full}-dark.svg
cp -r "$ICO"/links/{actions,apps,categories,devices,emotes,emblems,mimes,places,status,preferences} "$T/"
atx "$T"
echo "$T" >>"$LOG"

T="$I/WhiteSur-light"; rm -rf "$T"; mkdir -p "$T/status"
cp "$ICO/src/index.theme" "$T/"; sed -i "s/WhiteSur/WhiteSur-light/g" "$T/index.theme"
cp -r "$ICO"/src/status/{16,22,24,32} "$T/status/"
sed -i "s/#f2f2f2/#363636/g" "$T"/status/{16,22,24,32}/* || true
cp -r "$ICO"/links/status/{16,22,24,32} "$T/status/"
for n in actions animations apps categories devices emotes emblems mimes places preferences; do ln -sfn "../WhiteSur/$n" "$T/$n"; done
ln -sfn ../../WhiteSur/status/symbolic "$T/status/symbolic"
atx "$T"
echo "$T" >>"$LOG"

T="$I/WhiteSur-dark"; rm -rf "$T"; mkdir -p "$T"/{apps,categories,emblems,devices,mimes,places,status}
cp "$ICO/src/index.theme" "$T/"; sed -i "s/WhiteSur/WhiteSur-dark/g" "$T/index.theme"
cp -r "$ICO"/src/actions "$T/"
cp -r "$ICO"/src/apps/{16,22,32,symbolic} "$T/apps/"
cp -r "$ICO"/src/categories/{22,symbolic} "$T/categories/"
cp -r "$ICO"/src/emblems/symbolic "$T/emblems/"
cp -r "$ICO"/src/mimes/symbolic "$T/mimes/"
cp -r "$ICO"/src/devices/{16,22,24,32,symbolic} "$T/devices/"
cp -r "$ICO"/src/places/{16,22,24,scalable,symbolic} "$T/places/"
cp -r "$ICO"/src/status/symbolic "$T/status/"
cp -r "$ICO"/plasma/* "$T/"
mv -f "$T/places/scalable/user-trash-dark.svg" "$T/places/scalable/user-trash.svg"
mv -f "$T/places/scalable/user-trash-full-dark.svg" "$T/places/scalable/user-trash-full.svg"
sed -i "s/#363636/#dedede/g" "$T"/{actions,devices,places}/{16,22,24}/*.svg || true
sed -i "s/#363636/#dedede/g" "$T"/apps/{16,22,32}/*.svg "$T"/categories/22/*.svg || true
sed -i "s/#363636/#dedede/g" "$T"/{actions,devices}/32/*.svg || true
sed -i "s/#363636/#dedede/g" "$T"/{actions,apps,categories,emblems,devices,mimes,places,status}/symbolic/*.svg || true
cp -r "$ICO"/links/actions/{16,22,24,32,symbolic} "$T/actions/"
cp -r "$ICO"/links/devices/{16,22,24,32,symbolic} "$T/devices/"
cp -r "$ICO"/links/places/{16,22,24,scalable,symbolic} "$T/places/"
cp -r "$ICO"/links/apps/{16,22,32,symbolic} "$T/apps/"
cp -r "$ICO"/links/categories/{22,symbolic} "$T/categories/"
cp -r "$ICO"/links/emblems/symbolic "$T/emblems/"
cp -r "$ICO"/links/mimes/symbolic "$T/mimes/"
cp -r "$ICO"/links/status/symbolic "$T/status/"
for n in animations emotes preferences; do ln -sfn "../WhiteSur/$n" "$T/$n"; done
for p in categories/32 emblems/16 emblems/22 emblems/24 mimes/16 mimes/22 mimes/scalable apps/scalable devices/scalable status/16 status/22 status/24 status/32; do
	ln -sfn "../../WhiteSur/$p" "$T/$p"
done
atx "$T"
echo "$T" >>"$LOG"
for d in WhiteSur WhiteSur-light WhiteSur-dark; do gtk-update-icon-cache -q -f "$I/$d" 2>/dev/null || true; done

# Cursors: the built set from the repository (dist/)
rm -rf "$DATA/icons/WhiteSur-cursors"
mkdir -p "$DATA/icons/WhiteSur-cursors"
cp -r "$CUR/dist/." "$DATA/icons/WhiteSur-cursors/"
echo "$DATA/icons/WhiteSur-cursors" >>"$LOG"

say "Installed. List: $LOG"

# Undo script: removes only the folders this script installed. Switch the look back first (see the other undo scripts).
UNDO="${DESIGN_BACKUP_DIR:-$HOME/desktop-design-backups}/undo-10-themes.sh"
{ echo '#!/bin/bash'; echo '# Remove the WhiteSur files installed by 10-themes.sh. Run the appearance undo first.'; while read -r p; do printf 'rm -rf %q\n' "$p"; done <"$LOG"; } >"$UNDO"
chmod +x "$UNDO"
say "Undo: $UNDO"
