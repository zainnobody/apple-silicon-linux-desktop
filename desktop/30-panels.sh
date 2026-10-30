#!/bin/bash
# Top bar (launcher, global menu, tray, clock) and a centred floating dock at the bottom (icons only, Trash at the end).
# Needs a running Plasma session. The new panels are made first, then the old ones are removed, so a script error never leaves no panel.
# Undo: the backup made here holds the old panel layout (plasma-org.kde.plasma.desktop-appletsrc). Restore it, then restart plasmashell.
. "$(dirname "$0")/lib.sh"
session_up || { say "No Plasma session. Log in on the desktop, then run this again."; exit 1; }
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 30-panels
TOP_HEIGHT="${TOP_HEIGHT:-30}"; DOCK_HEIGHT="${DOCK_HEIGHT:-56}"

# Pin only apps that exist.
pins=""
for id in org.kde.dolphin org.mozilla.firefox org.kde.konsole systemsettings org.kde.discover org.kde.spectacle; do
	for d in /usr/share/applications "$DATA/applications" /var/lib/flatpak/exports/share/applications; do
		[ -f "$d/$id.desktop" ] && { pins="$pins\"applications:$id.desktop\","; break; }
	done
done
pins="[${pins%,}]"

JS=$(cat <<JSEOF
var oldPanels = panels();

var top = new Panel();
top.location = "top";
top.height = $TOP_HEIGHT;
top.floating = false;
top.hiding = "none";
top.lengthMode = "fill";
var launcher = top.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "start-here");
launcher.reloadConfig();
top.addWidget("org.kde.plasma.appmenu");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");
var clock = top.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");
clock.writeConfig("showSeconds", 0);
clock.reloadConfig();
try { top.opacity = "opaque"; } catch (e) {}

var dock = new Panel();
dock.location = "bottom";
dock.height = $DOCK_HEIGHT;
dock.floating = true;
dock.hiding = "none";
dock.alignment = "center";
dock.lengthMode = "fit";
try { dock.opacity = "opaque"; } catch (e) {}
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", $pins);
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.writeConfig("maxStripes", 1);
tasks.reloadConfig();
dock.addWidget("org.kde.plasma.marginsseparator");
dock.addWidget("org.kde.plasma.trash");

for (var i = 0; i < oldPanels.length; i++) { oldPanels[i].remove(); }
"panels now: " + panels().length;
JSEOF
)
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "$JS"
