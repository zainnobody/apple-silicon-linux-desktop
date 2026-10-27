# shellcheck shell=bash
# Fedora family: Fedora Asahi Remix and Fedora.
# shellcheck disable=SC2034  # the variables are read by lib/detect.sh and lib/install.sh
BACKEND_NAME=fedora
BACKEND_TOOLS="dnf dracut grub2-mkconfig"
BACKEND_KERNEL_TARGET=binrpm-pkg   # kernel make target for an .rpm
BACKEND_KERNEL_FORMAT=.rpm
BACKEND_FW_HOOK="dracut module from asahi-scripts (dracut-asahi)"
# Fedora's asahi-scripts package reads the sysconfig file and ships U-Boot in uboot-images-armv8.
BACKEND_M1N1_CONF=/etc/sysconfig/update-m1n1
BACKEND_UBOOT=/usr/share/uboot/apple_m1/u-boot-nodtb.bin
# Names read from the installed Fedora Asahi Remix 44 on the M3.
BACKEND_PLATFORM_PKGS="asahi-audio alsa-ucm-asahi speakersafetyd asahi-bless"
BLS_DIR=/boot/loader/entries

pkg_install_cmd() { printf 'dnf install -y %s' "$*"; }
initramfs_cmd() { printf 'dracut --force --kver %s' "$1"; }
boot_update_cmd() { printf 'grub2-mkconfig -o /boot/grub2/grub.cfg'; }

# Boot Loader Spec entry file (real path) whose linux line is /vmlinuz-$1.
bls_entry_of() {
	local f
	for f in "$(agx_path "$BLS_DIR")"/*.conf; do
		[ -f "$f" ] && grep -qxF "linux /vmlinuz-$1" "$f" && { printf '%s\n' "${f#"$AGX_ROOT"}"; return 0; }
	done
	return 0
}

bk_pkg_install() { run dnf install -y "$@"; }
bk_relabel() { run restorecon -RF "$@"; }
bk_initramfs() { run dracut --force --kver "$1" "/boot/initramfs-$1.img"; }
bk_backup_boot_config() {
	run cp -a "$BLS_DIR" "$1/loader-entries"
	run cp -a /boot/grub2/grubenv "$1/grubenv"
}

# The id of the entry for $1. Before the entry exists, the id that bk_boot_entry_add makes.
bk_boot_entry_id() {
	local f
	f="$(bls_entry_of "$1")"
	if [ -n "$f" ]; then
		basename "$f" .conf
		return 0
	fi
	f="$(bls_entry_of "$AGX_RUNNING_KREL")"
	[ -z "$f" ] || basename "$f" .conf | sed "s/$(sed_left "$AGX_RUNNING_KREL")/$(sed_right "$1")/"
}

# Copy the running kernel's entry and change only the version. The default entry stays.
bk_boot_entry_add() {
	local src id
	src="$(bls_entry_of "$AGX_RUNNING_KREL")"
	[ -n "$src" ] || die "no Boot Loader Spec entry for the running kernel $AGX_RUNNING_KREL"
	! grep -q '^devicetree' "$(agx_path "$src")" || die "$src has a devicetree line; review it by hand"
	id="$(bk_boot_entry_id "$1")"
	sed -e "s/$(sed_left "$AGX_RUNNING_KREL")/$(sed_right "$1")/g" \
		-e "s/^title .*/title agx GPU kernel ($(sed_right "$1"))/" "$(agx_path "$src")" \
		| write_file "$BLS_DIR/$id.conf" 0644
	bk_relabel "$BLS_DIR/$id.conf"
}
bk_boot_once() { run grub2-reboot "$1"; }
bk_set_default() { run grub2-set-default "$1"; }
bk_keep_default_on_update() { run sed -i 's/^UPDATEDEFAULT=yes$/UPDATEDEFAULT=no/' /etc/sysconfig/kernel; }
bk_show_menu() { run grub2-editenv - unset menu_auto_hide; }
bk_firmware_hook() {
	if [ -d "$(agx_path /usr/lib/dracut/modules.d/99asahi-firmware)" ]; then
		echo "  dracut-asahi from Fedora Asahi Remix loads it; nothing to do"
	else
		bk_pkg_install dracut-asahi asahi-scripts
	fi
}
