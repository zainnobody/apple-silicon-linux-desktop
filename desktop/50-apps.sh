#!/bin/bash
# Dolphin like Finder (global view settings, list view with Name, Date Modified, Size, Kind; icon-only toolbar; no in-window menu bar)
# and Konsole like Terminal.app (Basic and Pro look, Hack 11 pt, block cursor, tabs only when needed).
# Close Dolphin and Konsole before you run this, or they write their old settings back when they quit.
. "$(dirname "$0")/lib.sh"
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 50-apps
MONO_FONT="${MONO_FONT:-Hack}"

# ---- Dolphin
kwb dolphinrc GlobalViewProps true General
kwb dolphinrc EditableUrl false General
kwb dolphinrc ShowFullPath false General
kwb dolphinrc RememberOpenedTabs false General
kwb dolphinrc FilterBar false General
kw dolphinrc MenuBar Disabled MainWindow
# Global view: details list, folders first, sorted by name, previews on
GV="$DATA/dolphin/view_properties/global"; mkdir -p "$GV"
cat >"$GV/.directory" <<DIR
[Dolphin]
Timestamp=2026,10,30,0,0,0.000
Version=4
ViewMode=1
VisibleRoles=Details_text,Details_modificationtime,Details_size,Details_type
SortRole=text
SortOrder=0
SortFoldersFirst=true
PreviewsShown=true
DIR
# Toolbar: back and forward, view mode, split, search. Icons only (set in kdeglobals by 20-appearance.sh).
KX="$DATA/kxmlgui5/dolphin"; mkdir -p "$KX"
cat >"$KX/dolphinui.rc" <<'RC'
<!DOCTYPE gui SYSTEM "kpartgui.dtd">
<gui name="dolphin" version="9999">
 <ToolBar name="mainToolBar" noMerge="1">
  <text context="@title:menu">Main Toolbar</text>
  <Action name="go_back"/>
  <Action name="go_forward"/>
  <Action name="url_navigators"/>
  <Separator name="separator_0"/>
  <Action name="view_mode"/>
  <Action name="split_view"/>
  <Action name="show_preview"/>
  <Separator name="separator_1"/>
  <Action name="hamburger_menu"/>
 </ToolBar>
</gui>
RC

# ---- Konsole
KD="$DATA/konsole"; mkdir -p "$KD"
scheme() { # file description bg fg then 16 colours (normal 0-7, bright 0-7), each "r,g,b"
	local f=$1 desc=$2 bg=$3 fg=$4; shift 4
	{
		echo "[Background]"; echo "Color=$bg"; echo "[BackgroundIntense]"; echo "Color=$bg"
		echo "[Foreground]"; echo "Color=$fg"; echo "[ForegroundIntense]"; echo "Color=$fg"
		local i=0
		for c in "$@"; do
			if [ $i -lt 8 ]; then echo "[Color$i]"; else echo "[Color$((i - 8))Intense]"; fi
			echo "Color=$c"; i=$((i + 1))
		done
		echo "[General]"; echo "Blur=false"; echo "ColorRandomization=false"; echo "Description=$desc"; echo "Opacity=1"; echo "Wallpaper="
	} >"$KD/$f.colorscheme"
}
scheme AppleLight "Apple Basic" "255,255,255" "0,0,0" \
	"0,0,0" "153,0,0" "0,166,0" "153,153,0" "0,0,178" "178,0,178" "0,166,178" "191,191,191" \
	"102,102,102" "230,0,0" "0,217,0" "230,230,0" "0,0,255" "230,0,230" "0,230,230" "230,230,230"
scheme AppleDark "Apple Pro" "28,28,30" "242,242,242" \
	"0,0,0" "194,54,33" "37,188,36" "173,173,39" "73,46,225" "211,56,211" "51,187,200" "203,204,205" \
	"129,131,131" "252,57,31" "49,231,34" "234,236,35" "88,51,255" "249,53,248" "20,240,240" "233,235,235"
profile() { # file name scheme
	cat >"$KD/$1" <<PROF
[Appearance]
ColorScheme=$3
Font=$(font "$MONO_FONT" 11)
LineSpacing=0

[Cursor Options]
CursorShape=0

[General]
Name=$2
Parent=FALLBACK/
TerminalColumns=80
TerminalRows=24
TerminalMargin=8

[Scrolling]
HistoryMode=1
HistorySize=10000
ScrollBarPosition=2
PROF
}
profile AppleLight.profile "Apple Light" AppleLight
profile AppleDark.profile "Apple Dark" AppleDark
kw konsolerc DefaultProfile AppleLight.profile "Desktop Entry"
kwb konsolerc ShowMenuBarByDefault false KonsoleWindow
kw konsolerc TabBarVisibility ShowTabBarWhenNeeded TabBar
kw konsolerc MenuBar Disabled MainWindow
say "Dolphin and Konsole set. Open them again to see the change."
