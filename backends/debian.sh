# shellcheck shell=bash
# Debian family: Debian, Ubuntu, Kali and their derivatives.
# shellcheck disable=SC2034  # the variables are read by lib/detect.sh and lib/install.sh
BACKEND_NAME=debian
BACKEND_TOOLS="apt-get update-initramfs update-grub"
BACKEND_KERNEL_TARGET=bindeb-pkg   # kernel make target for a .deb
BACKEND_KERNEL_FORMAT=.deb
BACKEND_FW_HOOK="initramfs-tools hook from distro-pack (system/initramfs-tools)"
# asahi-scripts reads this file; it has no Debian patch for the path.
BACKEND_M1N1_CONF=/etc/default/update-m1n1
BACKEND_UBOOT=/usr/lib/asahi-boot/u-boot-nodtb.bin
# Package names are not verified on a Debian-family install yet.
BACKEND_PLATFORM_PKGS="asahi-audio alsa-ucm-conf-asahi speakersafetyd asahi-bless"

# shellcheck source=lib/grub.sh
. "$AGX_HOME/lib/grub.sh"

pkg_install_cmd() { printf 'apt-get install -y %s' "$*"; }
initramfs_cmd() { printf 'update-initramfs -u -k %s' "$1"; }
boot_update_cmd() { printf 'update-grub'; }

bk_pkg_install() { run apt-get install -y "$@"; }
bk_relabel() { :; }   # no SELinux labels by default
bk_backup_boot_config() { grub_backup "$1"; }
bk_stock_entry_id() { grub_entry_id "$AGX_RUNNING_KREL"; }
bk_boot_entry_id() { grub_entry_id "$1"; }

# Kernel package (make bindeb-pkg). linux-libc-dev and the debug package are not installed:
# linux-libc-dev would replace the distro's C library headers.
BACKEND_BUILD_DEPS="build-essential bc bison flex libssl-dev libelf-dev dwarves rsync cpio kmod dpkg-dev rustc rust-src bindgen clang lld (names not verified)"
# Make variables, one per line. builddeb strips the modules itself (INSTALL_MOD_STRIP=1).
bk_kernel_make_vars() { printf 'KDEB_PKGVERSION=%s-%s\n' "$1" "$AGX_PKG_REV"; }
bk_kernel_pkg_out() { printf "'%s'/../linux-image-[0-9]*.deb '%s'/../linux-headers-*.deb" "$1" "$1"; }
bk_kernel_pkg_file() { newest_file "$AGX_PKG_DIR" "linux-image-$1_*_arm64.deb"; }
bk_dtb_dir() { printf '/usr/lib/linux-image-%s' "$1"; }

# The package's own scripts build the initramfs (initramfs-tools, with the agx firmware hook) and
# run update-grub (zz-update-grub). update-grub makes the newest kernel the default, so a new kernel
# first pins the running one. A replace keeps the saved default as it is.
bk_kernel_pre_install() {
	local stock
	grub_use_saved
	[ "$1" = new ] || return 0
	stock="$(bk_stock_entry_id)"
	[ -n "$stock" ] || die "no GRUB entry for the running kernel $AGX_RUNNING_KREL in $GRUB_CFG"
	run grub-set-default "$stock"
}
# A newer package version of the same release replaces the installed one in place.
bk_kernel_pkg_install() { run apt-get install -y "$1"; }
bk_kernel_post_install() { :; }
bk_boot_once() { grub_use_saved; run grub-reboot "$1"; }
bk_set_default() { run grub-set-default "$1"; }
bk_keep_default_on_update() { grub_use_saved; }
bk_show_menu() { grub_show_menu; run update-grub; }
# asahi-scripts has no initramfs-tools hook, so distro-pack brings its own (system/initramfs-tools).
# Without one, the Apple firmware (Wi-Fi, Bluetooth, camera, trackpad) does not load at boot.
FW_HOOK_FILES="hooks/agx-asahi-firmware scripts/init-top/agx-asahi-firmware scripts/init-bottom/agx-asahi-firmware"

# A firmware hook from somewhere else (a distro package), if there is one.
fw_hook_other() {
	local d f
	for d in /usr/share/initramfs-tools /etc/initramfs-tools; do
		[ -d "$(agx_path "$d")" ] || continue
		f="$(grep -rlsF vendorfw "$(agx_path "$d")" | grep -v '/agx-asahi-firmware$' | head -n 1)"
		if [ -n "$f" ]; then
			printf '%s\n' "${f#"$AGX_ROOT"}"
			return
		fi
	done
}

bk_firmware_hook() {
	local other f
	other="$(fw_hook_other)"
	if [ -n "$other" ]; then
		echo "  $other loads it already; nothing to do"
		return
	fi
	for f in $FW_HOOK_FILES; do
		write_file "/etc/initramfs-tools/$f" 0755 < "$AGX_HOME/system/initramfs-tools/$f"
	done
	# The boot script mounts a tmpfs here. The root file system is read-only at that time.
	run mkdir -p /lib/firmware/vendor
	run update-initramfs -u -k all
}
