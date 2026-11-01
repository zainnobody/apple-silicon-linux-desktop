#!/bin/bash
# Look: colour scheme, Plasma theme, icons, cursor, window buttons on the left, fonts. Light or dark.
# Usage: 20-appearance.sh [light|dark]   (default light). Needs 10-themes.sh first.
# Fonts: Adwaita Sans (an Inter-based open font that Fedora ships) for the interface and Hack (a DejaVu-based mono font) for code.
# SF Pro cannot be redistributed, so it is never used. Inter works too: change UI_FONT below.
# No blur, no translucency: window decoration and Plasma theme are the opaque variants.
. "$(dirname "$0")/lib.sh"
mode="${1:-light}"
UI_FONT="${UI_FONT:-Adwaita Sans}"; MONO_FONT="${MONO_FONT:-Hack}"
# Icons and cursors are the KDE Breeze sets (original art, installed with Plasma). The WhiteSur icon and cursor sets copy Apple artwork,
# so this pack does not use them. Override with ICON_LIGHT, ICON_DARK and CURSORS only for a set you may use.
CURSORS="${CURSORS:-breeze_cursors}"
case "$mode" in
light) SCHEME=WhiteSur; PTHEME=WhiteSur-solid; ICONS=${ICON_LIGHT:-breeze}; DECO=WhiteSur-opaque; PROFILE=M3Light.profile ;;
dark) SCHEME=WhiteSurDark; PTHEME=WhiteSur-solid-dark; ICONS=${ICON_DARK:-breeze-dark}; DECO=WhiteSur-dark-opaque; PROFILE=M3Dark.profile ;;
*) say "usage: $0 [light|dark]"; exit 2 ;;
esac
[ -d "$DATA/aurorae/themes/$DECO" ] || { say "Run 10-themes.sh first."; exit 1; }
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup "20-appearance-$mode"

# Fonts. Title bars use a semibold weight.
kw kdeglobals font "$(font "$UI_FONT" 10)" General
kw kdeglobals menuFont "$(font "$UI_FONT" 10)" General
kw kdeglobals toolBarFont "$(font "$UI_FONT" 10)" General
kw kdeglobals smallestReadableFont "$(font "$UI_FONT" 8)" General
kw kdeglobals fixed "$(font "$MONO_FONT" 10)" General
kw kdeglobals activeFont "$(font "$UI_FONT" 10 600)" WM
kw kdeglobals inactiveFont "$(font "$UI_FONT" 10 600)" WM

# Icons and toolbar style (icon only)
kw kdeglobals Theme "$ICONS" Icons
kw kdeglobals ToolButtonStyle NoText "Toolbar style"
kw kdeglobals ToolButtonStyleOtherToolbars NoText "Toolbar style"

# Window decoration: close, minimize, zoom on the left (X I A). Nothing on the right.
kw kwinrc library org.kde.kwin.aurorae org.kde.kdecoration2
kw kwinrc theme "__aurorae__svg__$DECO" org.kde.kdecoration2
kw kwinrc ButtonsOnLeft XIA org.kde.kdecoration2
kw kwinrc ButtonsOnRight "" org.kde.kdecoration2
kw kwinrc BorderSize Normal org.kde.kdecoration2
kwb kwinrc NoPlugin false org.kde.kdecoration2

# Konsole follows the mode
kw konsolerc DefaultProfile "$PROFILE" "Desktop Entry"

# Colours, Plasma theme and cursor. These tools also work when no desktop runs, with the offscreen Qt platform.
if ! session_up; then export QT_QPA_PLATFORM=offscreen; fi
plasma-apply-colorscheme "$SCHEME" || say "colour scheme not applied"
plasma-apply-desktoptheme "$PTHEME" || say "Plasma theme not applied"
plasma-apply-cursortheme "$CURSORS" || say "cursor not applied"
notify_change 1; notify_change 4; notify_change 6
reload_kwin
say "Appearance: $mode"
