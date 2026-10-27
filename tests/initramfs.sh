#!/usr/bin/env bash
# Tests for the initramfs-tools firmware hook and boot scripts (system/initramfs-tools).
# Each case builds a fake initramfs root and a fake EFI partition. Stubs for modprobe, blkid,
# mount, umount and sleep come first in PATH and log their arguments. The real tr, cpio and cp
# do the work. The scripts run under dash when it exists (like /bin/sh on Debian).
# Runs on Linux and macOS, bash 3.2+.
# shellcheck disable=SC2016  # the stubs are written with literal $ signs
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../system/initramfs-tools"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SH="${AGXFW_SH:-$(command -v dash || echo sh)}"
pass=0
fail=0
UUID_DT=A1B2C3D4-0000-4000-8000-00000000E5F0   # as m1n1 may give it
UUID=a1b2c3d4-0000-4000-8000-00000000e5f0      # as blkid shows it

STUBS="$TMP/stubs"
mkdir -p "$STUBS"
for c in modprobe sleep umount; do
	printf '#!/bin/sh\necho "%s $*" >> "$LOG"\n' "$c" > "$STUBS/$c"
done
# umount also empties the mount point.
echo 'find "$1" -mindepth 1 -delete' >> "$STUBS/umount"
# blkid finds the partition after $BLKID_DELAY tries, if the case has a disk with that PARTUUID.
cat > "$STUBS/blkid" <<'EOF'
#!/bin/sh
echo "blkid $*" >> "$LOG"
n=$(cat "$CASE/blkid-tries" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$CASE/blkid-tries"
[ "$n" -gt "${BLKID_DELAY:-0}" ] || exit 2
for a in "$@"; do
	case "$a" in PARTUUID=*) u="${a#PARTUUID=}" ;; esac
done
[ -d "$CASE/disks/$u" ] || exit 2
echo "/dev/disk-$u"
EOF
# mount copies the fake disk into the mount point. A tmpfs mount only logs.
cat > "$STUBS/mount" <<'EOF'
#!/bin/sh
echo "mount $*" >> "$LOG"
for a in "$@"; do
	prev="${last:-}"
	last="$a"
done
case " $* " in
*" -t ${FAIL_MOUNT:-none} "*) exit 32 ;;
*" -t vfat "*) cp -R "$CASE/disks/${prev#/dev/disk-}/." "$last/" ;;
esac
EOF
chmod +x "$STUBS"/*

# The Apple firmware archive, as the Asahi installer writes it.
mkdir -p "$TMP/fw/vendorfw/brcm" "$TMP/fw/vendorfw/apple"
echo wifi > "$TMP/fw/vendorfw/brcm/brcmfmac-test.bin"
echo trackpad > "$TMP/fw/vendorfw/apple/tpmtfw-test.bin"
echo manifest > "$TMP/fw/vendorfw/.vendorfw.manifest"
(cd "$TMP/fw" && find vendorfw | cpio -o -H newc > "$TMP/firmware.cpio" 2> /dev/null)

# new_case <name> [disk|disk-empty] [mac|notmac]: a fake initramfs root at $TMP/<name>/initrd
new_case() {
	C="$1"
	R="$TMP/$C/initrd"
	mkdir -p "$R/scripts/init-top" "$R/scripts/init-bottom" "$R/proc/device-tree/chosen" "$R/run" \
		"$R/root/lib/firmware/vendor"
	printf 'log_success_msg() { echo "Success: $*"; }\nlog_warning_msg() { echo "Warning: $*"; }\n' \
		> "$R/scripts/functions"
	cp "$SRC/scripts/init-top/agx-asahi-firmware" "$R/scripts/init-top/"
	cp "$SRC/scripts/init-bottom/agx-asahi-firmware" "$R/scripts/init-bottom/"
	chmod +x "$R"/scripts/*/agx-asahi-firmware
	[ "${3:-mac}" = notmac ] || printf '%s\0' "$UUID_DT" > "$R/proc/device-tree/chosen/asahi,efi-system-partition"
	case "${2:-disk}" in
	disk)
		mkdir -p "$TMP/$C/disks/$UUID/vendorfw"
		cp "$TMP/firmware.cpio" "$TMP/$C/disks/$UUID/vendorfw/"
		;;
	disk-empty) mkdir -p "$TMP/$C/disks/$UUID/EFI" ;;
	esac
	: > "$TMP/$C/log"
}

# run <script: init-top|init-bottom|hooks> [VAR=value ...]: sets OUT and RC
run() {
	local s="$1" path
	shift
	case "$s" in
	hooks) path="$SRC/hooks/agx-asahi-firmware" ;;
	*) path="$R/scripts/$s/agx-asahi-firmware" ;;
	esac
	OUT="$(env "$@" PATH="$STUBS:$PATH" LOG="$TMP/$C/log" CASE="$TMP/$C" AGXFW_TEST_ROOT="$R" \
		rootmnt=/root "$SH" "$path" 2>&1)"
	RC=$?
}

has() { printf '%s' "$OUT" | grep -qF -- "$1"; }
logged() { grep -qF -- "$1" "$TMP/$C/log"; }
count() { grep -cF -- "$1" "$TMP/$C/log"; }
not() { ! "$@"; }
same() { [ "$(cat "$1" 2> /dev/null)" = "$2" ]; }

# expect <label> <command ...>
expect() {
	local label="$1"
	shift
	if "$@"; then
		pass=$((pass + 1))
		echo "ok   $C: $label"
	else
		fail=$((fail + 1))
		echo "FAIL $C: $label"
		printf '%s\n' "$OUT" | sed 's/^/     | /'
		sed 's/^/     log| /' "$TMP/$C/log" | head -n 12
	fi
}

echo "shell: $SH"

new_case unpack
run init-top
expect "exit 0" [ "$RC" = 0 ]
expect "unpacked" has "Success: Apple firmware: unpacked from /dev/disk-$UUID"
expect "NVMe modules" logged "modprobe -q nvme-apple"
expect "lower-case PARTUUID" logged "blkid -c /dev/null -l -o device -t PARTUUID=$UUID"
expect "EFI partition mounted read-only" logged "mount -t vfat -o ro /dev/disk-$UUID $R/run/agx-esp"
expect "EFI partition unmounted" logged "umount $R/run/agx-esp"
expect "Wi-Fi file" same "$R/vendorfw/brcm/brcmfmac-test.bin" wifi
expect "trackpad file" same "$R/vendorfw/apple/tpmtfw-test.bin" trackpad
expect "manifest" same "$R/vendorfw/.vendorfw.manifest" manifest
expect "no wait" [ "$(count 'sleep')" = 0 ]
run init-bottom
expect "copied" has "Success: Apple firmware: copied to /lib/firmware/vendor"
expect "tmpfs" logged "mount -t tmpfs -o mode=0755 vendorfw $R/root/lib/firmware/vendor"
expect "Wi-Fi file on the root" same "$R/root/lib/firmware/vendor/brcm/brcmfmac-test.bin" wifi
expect "manifest on the root" same "$R/root/lib/firmware/vendor/.vendorfw.manifest" manifest
expect "init-bottom does not unpack again" [ "$(count 'modprobe -q nvme-apple')" = 1 ]

new_case slow
run init-top BLKID_DELAY=30
expect "unpacked after 30 tries" has "unpacked from /dev/disk-$UUID"
expect "30 waits" [ "$(count 'sleep 0.1')" = 30 ]

new_case nodisk none
run init-top
expect "exit 0" [ "$RC" = 0 ]
expect "warning after 10 s" has "Warning: Apple firmware: no partition with PARTUUID $UUID after 10 s"
expect "100 tries" [ "$(count 'blkid ')" = 100 ]
expect "no /vendorfw" [ ! -e "$R/vendorfw" ]
expect "no mount" not logged "mount "

new_case nocpio disk-empty
run init-top
expect "warning" has "Warning: Apple firmware: no vendorfw/firmware.cpio on /dev/disk-$UUID"
expect "unmounted" logged "umount $R/run/agx-esp"
run init-bottom
expect "no tmpfs without firmware" not logged "-t tmpfs"

new_case badmount
run init-top FAIL_MOUNT=vfat
expect "warning" has "Warning: Apple firmware: cannot mount the EFI partition /dev/disk-$UUID"
expect "no /vendorfw" [ ! -e "$R/vendorfw" ]

new_case bootloader
mkdir -p "$R/vendorfw"
run init-top
expect "boot loader note" has "Success: Apple firmware: loaded by the boot loader"
expect "no modprobe" not logged "modprobe"

new_case notmac disk notmac
run init-top
expect "exit 0, no output" [ "$RC:$OUT" = "0:" ]
expect "nothing run" [ ! -s "$TMP/$C/log" ]

new_case retry
run init-bottom
expect "second try unpacks" has "Success: Apple firmware: unpacked from /dev/disk-$UUID"
expect "then copies" same "$R/root/lib/firmware/vendor/apple/tpmtfw-test.bin" trackpad

new_case noroot
rmdir "$R/root/lib/firmware/vendor"
run init-top
run init-bottom
expect "warning" has "Warning: Apple firmware: no /root/lib/firmware/vendor folder on the root file system"
expect "no tmpfs" not logged "-t tmpfs"

new_case badtmpfs
run init-top
run init-bottom FAIL_MOUNT=tmpfs
expect "warning" has "Warning: Apple firmware: cannot mount a tmpfs at /root/lib/firmware/vendor"
expect "nothing copied" [ ! -e "$R/root/lib/firmware/vendor/brcm" ]

new_case prereqs
for s in init-top init-bottom; do
	OUT="$(env AGXFW_TEST_ROOT="$R" "$SH" "$R/scripts/$s/agx-asahi-firmware" prereqs 2>&1)"
	RC=$?
	expect "$s prereqs: exit 0, no output" [ "$RC:$OUT" = "0:" ]
done
OUT="$("$SH" "$SRC/hooks/agx-asahi-firmware" prereqs 2>&1)"
RC=$?
expect "hook prereqs: exit 0, no output" [ "$RC:$OUT" = "0:" ]

# The hook, with stubs for the initramfs-tools helpers.
new_case hook
mkdir -p "$R/usr/share/initramfs-tools" "$R/usr/sbin" "$R/usr/bin" "$R/bin" "$TMP/$C/dest"
printf 'manual_add_modules() { echo "modules $*" >> "$LOG"; }\ncopy_exec() { echo "copy_exec $*" >> "$LOG"; }\n' \
	> "$R/usr/share/initramfs-tools/hook-functions"
for t in usr/sbin/blkid usr/bin/cpio usr/bin/tr bin/cp; do
	: > "$R/$t"
	chmod +x "$R/$t"
done
run hooks DESTDIR="$TMP/$C/dest"
expect "exit 0" [ "$RC" = 0 ]
expect "modules" logged "modules apple-mailbox nvme-apple vfat nls_cp437 nls_iso8859_1 nls_ascii"
expect "blkid" logged "copy_exec /usr/sbin/blkid"
expect "cpio" logged "copy_exec /usr/bin/cpio"
expect "tr" logged "copy_exec /usr/bin/tr"
expect "cp" logged "copy_exec /bin/cp"
expect "firmware link" [ "$(readlink "$TMP/$C/dest/lib/firmware/vendor")" = /vendorfw ]
expect "no firmware file in the initramfs" [ -z "$(find "$TMP/$C/dest" -type f)" ]
rm "$R/bin/cp"
run hooks DESTDIR="$TMP/$C/dest"
expect "second run, exit 0" [ "$RC" = 0 ]
expect "missing tool warning" has "W: agx-asahi-firmware: no cp on this system"
expect "link kept" [ "$(readlink "$TMP/$C/dest/lib/firmware/vendor")" = /vendorfw ]

echo "pass $pass, fail $fail"
[ "$fail" = 0 ]
