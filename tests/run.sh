#!/usr/bin/env bash
# Tests for `agx detect`. Each case builds a fake root file system (device tree, os-release,
# tools) and checks the exit code and the JSON fields. Runs on Linux and macOS, bash 3.2+.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
AGX="$HERE/../agx"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

FEDORA=$'NAME="Fedora Linux Asahi Remix"\nID=fedora-asahi-remix\nID_LIKE=fedora\nVERSION_ID=44\nPRETTY_NAME="Fedora Linux Asahi Remix 44 (KDE Plasma Desktop Edition)"'
UBUNTU=$'NAME="Ubuntu"\nID=ubuntu\nID_LIKE=debian\nVERSION_ID="26.04"\nPRETTY_NAME="Ubuntu 26.04 LTS"'
KALI=$'NAME="Kali GNU/Linux"\nID=kali\nID_LIKE=debian\nVERSION_ID="2026.3"\nPRETTY_NAME="Kali GNU/Linux Rolling"'
DEBIAN=$'NAME="Debian GNU/Linux"\nID=debian\nVERSION_ID="13"\nPRETTY_NAME="Debian GNU/Linux 13 (trixie)"'
ARCH=$'NAME="Arch Linux ARM"\nID=archarm\nID_LIKE=arch\nPRETTY_NAME="Arch Linux ARM"'
GENTOO=$'NAME=Gentoo\nID=gentoo\nPRETTY_NAME="Gentoo Linux"'

# make_root <name> <compatible entries> <model> <os-release text> [tool ...]
make_root() {
	local r="$TMP/$1" c
	mkdir -p "$r/proc/device-tree/chosen" "$r/etc" "$r/usr/bin" "$r/usr/lib/firmware/vendor"
	: > "$r/proc/device-tree/compatible"
	for c in $2; do printf '%s\0' "$c" >> "$r/proc/device-tree/compatible"; done
	printf '%s\0' "$3" > "$r/proc/device-tree/model"
	printf '%s\n' "$4" > "$r/etc/os-release"
	shift 4
	for c in "$@"; do : > "$r/usr/bin/$c"; done
}

# The J516S state as read on the M3: firmware versions, bound GPU driver, native Mesa.
add_m3_state() {
	local r="$TMP/$1"
	printf '15.6\0' > "$r/proc/device-tree/chosen/asahi,system-fw-version"
	printf '%s\0' "${2:-14.7}" > "$r/proc/device-tree/chosen/asahi,os-fw-version"
	printf 'v1.6.1\0' > "$r/proc/device-tree/chosen/asahi,m1n1-stage1-version"
	printf 'aca1258\0' > "$r/proc/device-tree/chosen/asahi,m1n1-stage2-version"
	mkdir -p "$r/sys/bus/platform/devices/292400000.gpu" "$r/dev/dri" \
		"$r/opt/mesa-m3/share/vulkan/icd.d" "$r/sys/module/pmp_report/parameters"
	ln -s ../../../../bus/platform/drivers/asahi-g15 "$r/sys/bus/platform/devices/292400000.gpu/driver"
	: > "$r/dev/dri/renderD128"
	: > "$r/opt/mesa-m3/share/vulkan/icd.d/asahi_icd.aarch64.json"
	echo Y > "$r/sys/module/pmp_report/parameters/memory_floor"
}

# check <name> <expected exit code> <page size> <fixed string expected in the JSON> ...
check() {
	local name="$1" want="$2" page="$3" out got s ok=1
	shift 3
	out="$(AGX_ROOT="$TMP/$name" AGX_UNAME_R=7.2.11-m3gpu+ AGX_PAGESIZE="$page" "$AGX" detect --json)"
	got=$?
	[ "$got" = "$want" ] || { echo "FAIL $name: exit $got, want $want"; ok=0; }
	for s in "$@"; do
		printf '%s' "$out" | grep -qF -- "$s" || { echo "FAIL $name: missing $s"; ok=0; }
	done
	if [ "$ok" = 1 ]; then
		pass=$((pass + 1))
		echo "ok   $name"
	else
		fail=$((fail + 1))
		echo "     output: $out"
	fi
}

make_root m3pro-fedora "apple,j516s apple,t6030 apple,arm-platform" "Apple MacBook Pro (16-inch, M3 Pro, Nov 2023)" "$FEDORA" dnf dracut grub2-mkconfig
add_m3_state m3pro-fedora
check m3pro-fedora 0 16384 '"status": "tested"' '"family": "fedora"' '"missing_tools": ""' \
	'"gpu_driver": "asahi-g15"' '"native_mesa": "/opt/mesa-m3"' '"memory_floor": "Y"' '"os_fw": "14.7"' '"warnings": []'

make_root m3pro-ubuntu "apple,j516s apple,t6030 apple,arm-platform" "Apple MacBook Pro (16-inch, M3 Pro, Nov 2023)" "$UBUNTU" apt-get update-initramfs update-grub
check m3pro-ubuntu 0 16384 '"status": "tested"' '"family": "debian"' '"distro_id": "ubuntu"' '"missing_tools": ""'

make_root m3pro14-kali "apple,j514s apple,t6030 apple,arm-platform" "Apple MacBook Pro (14-inch, M3 Pro, Nov 2023)" "$KALI" apt-get update-initramfs update-grub
check m3pro14-kali 0 16384 '"status": "expected"' '"family": "debian"' '"profile": "-"' 'First install on this board'

make_root m1air-arch "apple,j313 apple,t8103 apple,arm-platform" "Apple MacBook Air (M1, 2020)" "$ARCH" pacman mkinitcpio grub-mkconfig
check m1air-arch 0 16384 '"status": "upstream"' '"family": "arch"' '"chip": "M1"' '"missing_tools": ""'

make_root m3max-debian "apple,j514c apple,t6031 apple,arm-platform" "Apple MacBook Pro (14-inch, M3 Max, 16 CPU cores, Nov 2023)" "$DEBIAN" apt-get update-initramfs update-grub
check m3max-debian 0 16384 '"status": "base-only"' '"family": "debian"' '"chip": "M3 Max (16 CPU cores)"'

make_root m4-ubuntu "apple,j604 apple,t8132 apple,arm-platform" "Apple MacBook Pro (14-inch, M4, 2024)" "$UBUNTU" apt-get update-initramfs update-grub
check m4-ubuntu 2 16384 '"status": "unsupported"' '"chip": "M4"'

make_root raspberrypi "raspberrypi,4-model-b brcm,bcm2711" "Raspberry Pi 4 Model B" "$DEBIAN" apt-get
check raspberrypi 3 4096 '"error": "not Linux on Apple silicon"'

make_root m3pro-gentoo "apple,j516s apple,t6030 apple,arm-platform" "Apple MacBook Pro (16-inch, M3 Pro, Nov 2023)" "$GENTOO"
check m3pro-gentoo 4 16384 '"family": "unknown"' 'Distro family not supported yet'

make_root ubuntu-missing "apple,j516s apple,t6030 apple,arm-platform" "Apple MacBook Pro (16-inch, M3 Pro, Nov 2023)" "$UBUNTU" apt-get
check ubuntu-missing 0 16384 '"missing_tools": "update-initramfs update-grub"' 'Missing tools for the debian backend'

make_root m3pro-newfw "apple,j516s apple,t6030 apple,arm-platform" "Apple MacBook Pro (16-inch, M3 Pro, Nov 2023)" "$FEDORA" dnf dracut grub2-mkconfig
add_m3_state m3pro-newfw 15.0
check m3pro-newfw 0 16384 '"os_fw": "15.0"' 'OS firmware 15.0 is not tested'

check m3pro-fedora 0 4096 'Asahi kernels use 16K pages. This kernel uses 4096.'

# Human output of the reference machine.
human="$(AGX_ROOT="$TMP/m3pro-fedora" AGX_UNAME_R=7.2.11-m3gpu+ AGX_PAGESIZE=16384 "$AGX" detect)"
if printf '%s' "$human" | grep -qF "Plan for 'agx install'" && printf '%s' "$human" | grep -qF "machines/j516s.sh"; then
	pass=$((pass + 1))
	echo "ok   human output"
else
	fail=$((fail + 1))
	echo "FAIL human output"
	printf '%s\n' "$human"
fi

echo "pass $pass, fail $fail"
[ "$fail" = 0 ]
