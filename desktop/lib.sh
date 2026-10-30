#!/bin/bash
# Shared helpers for the desktop design scripts (KDE Plasma 6). Source this file. User level only: no root.
# Test without touching the real desktop:  HOME=/tmp/fakehome DESIGN_DRY=1 ./20-appearance.sh
set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DL="${DESIGN_DOWNLOADS:-$HOME/design-downloads}"
# Pinned upstream sources (GPL-3.0, github.com/vinceliuice). The scripts check these commits.
WHITESUR_KDE=cf4df59ce91004f7ea39358b1b8ff917d5c329f7
WHITESUR_ICONS=73d8040da51a9ed74e47c7366e7e9ff437601a5c
WHITESUR_CURSORS=e190baf618ed95ee217d2fd45589bd309b37672b

# kw FILE KEY VALUE [GROUP...]   write one key (nested groups allowed)
kw() {
	local file=$1 key=$2 val=$3; shift 3
	local args=(--file "$file")
	local g
	for g in "$@"; do args+=(--group "$g"); done
	kwriteconfig6 "${args[@]}" --key "$key" "$val"
}
kwb() { # kw for booleans
	local file=$1 key=$2 val=$3; shift 3
	local args=(--file "$file")
	local g
	for g in "$@"; do args+=(--group "$g"); done
	kwriteconfig6 "${args[@]}" --key "$key" --type bool "$val"
}

# Qt6 font string: font "Adwaita Sans" 10 [weight]
font() { printf '%s,%s,-1,5,%s,0,0,0,0,0,0,0,0,0,0,1' "$1" "$2" "${3:-400}"; }

# Join the running user session (needed for live changes). Returns 1 when no desktop runs.
session_up() {
	local uid; uid=$(id -u)
	export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
	export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
	[ -S "$XDG_RUNTIME_DIR/wayland-0" ] && export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
	pgrep -u "$uid" -x plasmashell >/dev/null 2>&1
}

notify_change() { # KGlobalSettings change: 0 palette, 1 font, 2 style, 4 icons, 5 cursor, 6 toolbar style
	session_up && dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange "int32:$1" "int32:${2:-0}" || true
}
reload_kwin() { session_up && busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true; }
restart_shell() { session_up && systemctl --user restart plasma-plasmashell.service || true; }

# Make a dated backup and an undo script before a change set. Label names the change set.
backup() { "$HERE/backup.sh" "$1"; }

say() { printf '%s\n' "$*"; }
