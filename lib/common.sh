# shellcheck shell=bash
# Shared helpers. Works with bash 3.2 or newer.
#
# AGX_ROOT points at a fake root file system for the tests. It is empty on a real system.
# AGX_UNAME_R and AGX_PAGESIZE replace `uname -r` and `getconf PAGESIZE` in the tests.

AGX_ROOT="${AGX_ROOT:-}"

agx_path() { printf '%s%s' "$AGX_ROOT" "$1"; }

# Device tree string property. NUL separators become spaces.
dt_read() {
	local f
	f="$(agx_path "/proc/device-tree/$1")"
	[ -r "$f" ] || return 1
	tr '\0' ' ' < "$f" | sed 's/ *$//'
}

# True when the tool exists in one of the system program folders.
has_tool() {
	local d
	for d in /usr/bin /usr/sbin /bin /sbin; do
		[ -e "$(agx_path "$d/$1")" ] && return 0
	done
	return 1
}

# One value from os-release, without quotes. The file is parsed, never sourced.
osr_get() {
	local f
	f="$(agx_path /etc/os-release)"
	[ -r "$f" ] || f="$(agx_path /usr/lib/os-release)"
	[ -r "$f" ] || return 0
	awk -v k="$1" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2); gsub(/^"|"$/, "", v); print v; exit }' "$f"
}

# Field 2..n of the first line in a TSV file whose field 1 equals $2. Comment lines are skipped.
tsv_lookup() {
	awk -F '\t' -v k="$2" '$1 == k && $1 !~ /^#/ { print; exit }' "$1"
}

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
