# shellcheck shell=bash
# Command runner for the install steps.
#
# Dry run is the default: every command is printed with a "+ " prefix and nothing changes.
# AGX_APPLY=1 runs the commands. `agx` does not set it yet: the steps have only run as dry runs.

AGX_APPLY="${AGX_APPLY:-0}"

die() {
	echo "agx: $*" >&2
	exit 1
}

need_root() { [ "$AGX_APPLY" != 1 ] || [ "$(id -u)" = 0 ] || die "run with sudo"; }

run() {
	if [ "$AGX_APPLY" = 1 ]; then
		"$@"
	else
		printf '+ %s\n' "$*"
	fi
}

# Write stdin to a root-owned file. <path> <mode>
write_file() {
	if [ "$AGX_APPLY" = 1 ]; then
		local tmp
		tmp="$(mktemp)"
		cat > "$tmp"
		install -D -m "$2" -o root -g root "$tmp" "$1"
		rm -f "$tmp"
	else
		printf '+ write %s (mode %s):\n' "$1" "$2"
		sed 's/^/    | /'
	fi
}

# Append stdin to a file. <path>
append_file() {
	if [ "$AGX_APPLY" = 1 ]; then
		cat >> "$1"
	else
		printf '+ append to %s:\n' "$1"
		sed 's/^/    | /'
	fi
}

# A check on the result of an earlier step. A dry run of a whole plan cannot meet it,
# because the earlier step only printed its commands. <message> <command ...>
require_after() {
	local msg="$1"
	shift
	"$@" && return 0
	[ "$AGX_APPLY" = 1 ] && die "$msg"
	echo "  (dry run: assumes an earlier step did this: $msg)"
}

# Escape a string for the left and right side of a sed s/// command.
sed_left() { printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g'; }
sed_right() { printf '%s' "$1" | sed 's/[&/\]/\\&/g'; }
