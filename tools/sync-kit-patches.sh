#!/usr/bin/env bash
# Copy the kernel patches and the kernel config of the tested M3 stack from agx-linux-kit into
# kernel/, and write kernel/series with their SHA-256 values.
#   tools/sync-kit-patches.sh [KIT]          copy and write kernel/series
#   tools/sync-kit-patches.sh --check [KIT]  only compare; exit 1 when a file differs
# KIT defaults to ../agx-linux-kit next to this repository.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

check=0
if [ "${1:-}" = --check ]; then
	check=1
	shift
fi
KIT="${1:-$HERE/../agx-linux-kit}"
[ -d "$KIT/patches" ] || { echo "no agx-linux-kit at $KIT" >&2; exit 2; }

# The tested default boot (stage O plus the fan fix), in apply order. Touch ID stays out: it is in
# test boots only, and the safe config turns APPLE_SEP off.
PATCHES="m3-kernel-tree-2026-10-26.patch g15-perf-tgt-util.patch g15-recovery-drain-halt.patch macsmc-hwmon-ftst-unlock.patch"
# Kit config with CONFIG_USB4_APPLE_SOC=m (stage L), the config of the installed image.
CONFIG_SRC="m3-legacy/kernel/config-7.2.11-m3gpu+-usb4"
CONFIG_DST="config/t6030.config"

# Text that must never leave the reference Mac (README.md, "Never in this repository").
private_check() {
	if grep -nE '/home/|user|100\.72\.' "$1"; then
		echo "private text in $1; not copied" >&2
		exit 1
	fi
}

diffs=0
copy_one() {
	local src="$KIT/$1" dst="$HERE/kernel/$2"
	[ -f "$src" ] || { echo "missing in the kit: $1" >&2; exit 2; }
	private_check "$src"
	if [ "$check" = 1 ]; then
		cmp -s "$src" "$dst" || { echo "differs from the kit: kernel/$2"; diffs=$((diffs + 1)); }
	else
		cp "$src" "$dst"
	fi
}

for p in $PATCHES; do
	copy_one "patches/$p" "patches/$p"
done
copy_one "$CONFIG_SRC" "$CONFIG_DST"

if [ "$check" = 1 ]; then
	# The hashes in kernel/series must match the files too.
	while read -r sum file; do
		[ "$(sha256_file "$HERE/kernel/patches/$file")" = "$sum" ] || { echo "hash differs: kernel/patches/$file"; diffs=$((diffs + 1)); }
	done < <(grep -v '^#' "$HERE/kernel/series" | grep .)
	[ "$diffs" = 0 ] && echo "kernel/ matches the kit ($KIT)"
	[ "$diffs" = 0 ]
	exit
fi

{
	echo "# Kernel patches, applied in this order on KERNEL_COMMIT (kernel/source.conf)."
	echo "# Format: <sha256>  <file in kernel/patches/>. Written by tools/sync-kit-patches.sh from"
	echo "# agx-linux-kit commit $(git -C "$KIT" rev-parse --short HEAD 2>/dev/null || echo unknown)."
	for p in $PATCHES; do
		printf '%s  %s\n' "$(sha256_file "$HERE/kernel/patches/$p")" "$p"
	done
} > "$HERE/kernel/series"
echo "copied $(echo "$PATCHES" | wc -w | tr -d ' ') patches and $CONFIG_DST; wrote kernel/series"
