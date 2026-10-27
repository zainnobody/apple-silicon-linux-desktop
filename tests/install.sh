#!/usr/bin/env bash
# Tests for the install steps (dry runs). Each case builds a fake root file system and a fake
# build folder, runs `agx plan-install` or `agx step`, and checks the printed commands.
# The last check proves that a dry run changes no file. Runs on Linux and macOS, bash 3.2+.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
AGX="$HERE/../agx"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0
NEW=7.2.11-agx
UUID=1a2b3c4d-0000-4000-8000-000000000001

FEDORA=$'ID=fedora-asahi-remix\nID_LIKE=fedora\nPRETTY_NAME="Fedora Linux Asahi Remix 44"'
UBUNTU=$'ID=ubuntu\nID_LIKE=debian\nPRETTY_NAME="Ubuntu 26.04 LTS"'
KALI=$'ID=kali\nID_LIKE=debian\nPRETTY_NAME="Kali GNU/Linux Rolling"'
ARCH=$'ID=archarm\nID_LIKE=arch\nPRETTY_NAME="Arch Linux ARM"'

# make_root <name> <board> <soc> <os-release> <tool ...>
make_root() {
	local r="$TMP/$1" t
	mkdir -p "$r/proc/device-tree" "$r/etc/default" "$r/etc/sysconfig" "$r/usr/bin" "$r/boot/efi/m1n1"
	printf 'apple,%s\0apple,%s\0apple,arm-platform\0' "$2" "$3" > "$r/proc/device-tree/compatible"
	printf 'Test Mac (%s)\0' "$2" > "$r/proc/device-tree/model"
	printf '%s\n' "$4" > "$r/etc/os-release"
	printf 'chosen.asahi,efi-system-partition=x\n' > "$r/etc/m1n1.conf"
	: > "$r/boot/efi/m1n1/boot.bin"
	shift 4
	for t in "$@"; do : > "$r/usr/bin/$t"; done
}

# A Boot Loader Spec entry for kernel $2 (Fedora).
add_bls() {
	mkdir -p "$TMP/$1/boot/loader/entries"
	printf 'title Fedora (%s)\nversion %s\nlinux /vmlinuz-%s\ninitrd /initramfs-%s.img\noptions root=UUID=x ro\n' \
		"$2" "$2" "$2" "$2" > "$TMP/$1/boot/loader/entries/abc-$2.conf"
	printf 'UPDATEDEFAULT=yes\n' > "$TMP/$1/etc/sysconfig/kernel"
}

# A grub.cfg with one submenu entry per kernel name (Debian family and Arch).
add_grub() {
	local r="$TMP/$1" k
	shift
	mkdir -p "$r/boot/grub"
	printf 'GRUB_DEFAULT=0\nGRUB_TIMEOUT_STYLE=hidden\nGRUB_TIMEOUT=0\n' > "$r/etc/default/grub"
	{
		echo "menuentry 'Linux' \$menuentry_id_option 'gnulinux-simple-$UUID' {"
		echo "}"
		echo "submenu 'Advanced options' \$menuentry_id_option 'gnulinux-advanced-$UUID' {"
		for k in "$@"; do
			printf "\tmenuentry 'Linux, with %s' \$menuentry_id_option 'gnulinux-%s-advanced-%s' {\n\t}\n" "$k" "$k" "$UUID"
		done
		echo "}"
	} > "$r/boot/grub/grub.cfg"
}

# The build output that the install steps read.
STAGE="$TMP/stage"
mkdir -p "$STAGE/kernel-$NEW/boot" "$STAGE/kernel-$NEW/lib/modules/$NEW" "$STAGE/kernel-$NEW/dtb/apple" \
	"$STAGE/mesa-stage/opt/mesa-agx/lib64" "$STAGE/m1n1"
for f in "boot/vmlinuz-$NEW" "boot/config-$NEW" "boot/System.map-$NEW" dtb/apple/t6030-j516s.dtb; do
	: > "$STAGE/kernel-$NEW/$f"
done
: > "$STAGE/mesa-stage/opt/mesa-agx/lib64/libvulkan_asahi.so"
: > "$STAGE/m1n1/m1n1.bin"
echo "$NEW" > "$STAGE/kernel-release"

# check <name> <expected exit> <running kernel> <agx args> -- <must contain ...> [! <must not contain> ...]
check() {
	local name="$1" want="$2" krel="$3" out got s ok=1 neg=0 args=()
	shift 3
	while [ $# -gt 0 ] && [ "$1" != -- ]; do args+=("$1"); shift; done
	[ $# -eq 0 ] || shift
	out="$(AGX_ROOT="$TMP/$name" AGX_UNAME_R="$krel" AGX_PAGESIZE=16384 AGX_STAGE_DIR="$STAGE" "$AGX" "${args[@]}" 2>&1)"
	got=$?
	[ "$got" = "$want" ] || { echo "FAIL $name: exit $got, want $want"; ok=0; }
	for s in "$@"; do
		if [ "$s" = '!' ]; then neg=1; continue; fi
		if [ "$neg" = 1 ]; then
			! printf '%s' "$out" | grep -qF -- "$s" || { echo "FAIL $name: must not contain: $s"; ok=0; }
		else
			printf '%s' "$out" | grep -qF -- "$s" || { echo "FAIL $name: missing: $s"; ok=0; }
		fi
	done
	if [ "$ok" = 1 ]; then
		pass=$((pass + 1))
		echo "ok   $name ${args[*]}"
	else
		fail=$((fail + 1))
		printf '%s\n' "$out" | sed 's/^/     | /' | head -80
	fi
}

STOCK_F=7.1.13-402.asahi.fc44.aarch64+16k
STOCK_D=7.1.13-stock

make_root fedora j516s t6030 "$FEDORA" dnf dracut grub2-mkconfig
add_bls fedora "$STOCK_F"
check fedora 0 "$STOCK_F" plan-install -- \
	"append to /etc/sysconfig/update-m1n1" "M1N1_UPDATE_DISABLED=1" "dnf install -y dracut-asahi asahi-scripts" \
	"dnf install -y asahi-audio alsa-ucm-asahi speakersafetyd asahi-bless" \
	"cp -a $STAGE/mesa-stage/opt/mesa-agx /opt/mesa-agx" "restorecon -RF /opt/mesa-agx" \
	"depmod -a $NEW" "dracut --force --kver $NEW /boot/initramfs-$NEW.img" \
	"write /boot/loader/entries/abc-$NEW.conf" "title agx GPU kernel ($NEW)" "linux /vmlinuz-$NEW" \
	"/usr/share/uboot/apple_m1/u-boot-nodtb.bin" "chosen.asahi,t6030-gpu=1" \
	"write /usr/local/sbin/agx-mesa-select" "grub2-reboot abc-$NEW" \
	"UPDATEDEFAULT=no" "grub2-set-default abc-$NEW" "grub2-editenv - unset menu_auto_hide" \
	! "update-grub" "grub-reboot " "apt-get" "@MESA_PREFIX@"

make_root kali j516s t6030 "$KALI" apt-get update-initramfs update-grub
add_grub kali "$NEW" "$STOCK_D"
check kali 0 "$STOCK_D" plan-install -- \
	"append to /etc/default/update-m1n1" "apt-get install -y asahi-audio" \
	"update-initramfs -c -k $NEW" "sed -i s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/ /etc/default/grub" \
	"grub-set-default gnulinux-advanced-$UUID>gnulinux-$STOCK_D-advanced-$UUID" "update-grub" \
	"grub-reboot gnulinux-advanced-$UUID>gnulinux-$NEW-advanced-$UUID" \
	"/usr/lib/asahi-boot/u-boot-nodtb.bin" "grub-set-default gnulinux-advanced-$UUID>gnulinux-$NEW-advanced-$UUID" \
	"GRUB_TIMEOUT_STYLE=menu" "write /etc/initramfs-tools/hooks/agx-asahi-firmware (mode 0755)" \
	"write /etc/initramfs-tools/scripts/init-top/agx-asahi-firmware" "cpio -i -d" \
	"write /etc/initramfs-tools/scripts/init-bottom/agx-asahi-firmware" "mount -t tmpfs -o mode=0755 vendorfw" \
	"mkdir -p /lib/firmware/vendor" "update-initramfs -u -k all" \
	! "restorecon" "dracut --force" "grub2-" "dnf " "NOT BUILT"

make_root ubuntu14 j514s t6030 "$UBUNTU" apt-get update-initramfs update-grub
check ubuntu14 5 "$STOCK_D" plan-install -- "has no machine profile yet"

make_root arch j516s t6030 "$ARCH" pacman mkinitcpio grub-mkconfig
add_grub arch "$NEW" linux-asahi
check arch 0 "6.99.0-asahi-ARCH" plan-install -- \
	"pacman -S --needed --noconfirm asahi-audio" "pacman -S --needed --noconfirm asahi-scripts" "mkinitcpio -k $NEW -g /boot/initramfs-$NEW.img" \
	"grub-set-default gnulinux-advanced-$UUID>gnulinux-linux-asahi-advanced-$UUID" \
	"grub-mkconfig -o /boot/grub/grub.cfg" "grub-reboot gnulinux-advanced-$UUID>gnulinux-$NEW-advanced-$UUID" \
	! "restorecon" "dracut" "update-initramfs"

make_root m1arch j313 t8103 "$ARCH" pacman mkinitcpio grub-mkconfig
check m1arch 0 "6.99.0-asahi-ARCH" plan-install -- \
	"the distro's Asahi kernel and Mesa cover this Mac" "pacman -S --needed --noconfirm asahi-audio" \
	! "mkinitcpio -k" "mesa-agx"

make_root m4 j604 t8132 "$UBUNTU" apt-get update-initramfs update-grub
check m4 2 "$STOCK_D" plan-install -- "no Linux install path for this Mac yet"

check fedora 64 "$STOCK_F" step backup --apply -- "--apply is not enabled yet"

make_root fedora-fw j516s t6030 "$FEDORA" dnf dracut grub2-mkconfig
mkdir -p "$TMP/fedora-fw/usr/lib/dracut/modules.d/99asahi-firmware"
check fedora-fw 0 "$STOCK_F" step firmware -- "dracut-asahi from Fedora Asahi Remix loads it" ! "dnf install"

# A firmware hook from a distro package wins. The agx hook from an earlier run does not count.
make_root kali-fw j516s t6030 "$KALI" apt-get update-initramfs update-grub
mkdir -p "$TMP/kali-fw/etc/initramfs-tools/hooks" "$TMP/kali-fw/usr/share/initramfs-tools/scripts/init-top"
# shellcheck disable=SC2016  # literal $DESTDIR in the fake hook
echo 'ln -s /vendorfw "$DESTDIR/lib/firmware/vendor"' > "$TMP/kali-fw/etc/initramfs-tools/hooks/agx-asahi-firmware"
check kali-fw 0 "$STOCK_D" step firmware -- "write /etc/initramfs-tools/hooks/agx-asahi-firmware"
echo 'cpio -i < /run/esp/vendorfw/firmware.cpio' > "$TMP/kali-fw/usr/share/initramfs-tools/scripts/init-top/asahi"
check kali-fw 0 "$STOCK_D" step firmware -- \
	"/usr/share/initramfs-tools/scripts/init-top/asahi loads it already; nothing to do" ! "write " "update-initramfs"

# Kernel step safety checks.
check fedora 1 "$NEW" step kernel -- "boot the distro kernel before installing $NEW"
make_root fedora-installed j516s t6030 "$FEDORA" dnf dracut grub2-mkconfig
add_bls fedora-installed "$STOCK_F"
mkdir -p "$TMP/fedora-installed/usr/lib/modules/$NEW"
check fedora-installed 1 "$STOCK_F" step kernel -- "exists already (use the kernel-replace step)"
check fedora-installed 0 "$STOCK_F" step kernel-replace -- "pre-replace" "dracut --force --kver $NEW" \
	! "write /boot/loader/entries"
make_root kali-noentry j516s t6030 "$KALI" apt-get update-initramfs update-grub
add_grub kali-noentry "$NEW"
check kali-noentry 1 "$STOCK_D" step kernel -- "no GRUB entry for the running kernel $STOCK_D"
check fedora 1 "$STOCK_F" step bootbin-build blue -- "bootbin-build takes dtb or gpu"
check m1arch 2 "6.99.0-asahi-ARCH" step kernel -- "is for the M3 Pro GPU path"
check fedora 0 "$STOCK_F" step default -- "(dry run: assumes an earlier step did this: automatic boot.bin rebuilds are not paused"

# A folder this user cannot read gives a note, not a wrong plan.
make_root fedora-locked j516s t6030 "$FEDORA" dnf dracut grub2-mkconfig
add_bls fedora-locked "$STOCK_F"
chmod 000 "$TMP/fedora-locked/boot/loader/entries"
check fedora-locked 0 "$STOCK_F" step boot-once -- "this user cannot read /boot/loader/entries. Run with sudo"
chmod 755 "$TMP/fedora-locked/boot/loader/entries"

# A dry run must not change the fake root.
before="$(cd "$TMP/fedora" && find . -type f -exec cksum {} + | sort)"
AGX_ROOT="$TMP/fedora" AGX_UNAME_R="$STOCK_F" AGX_STAGE_DIR="$STAGE" "$AGX" plan-install > /dev/null 2>&1
after="$(cd "$TMP/fedora" && find . -type f -exec cksum {} + | sort)"
if [ "$before" = "$after" ]; then
	pass=$((pass + 1))
	echo "ok   dry run changes no file"
else
	fail=$((fail + 1))
	echo "FAIL dry run changed files"
fi

echo "pass $pass, fail $fail"
[ "$fail" = 0 ]
