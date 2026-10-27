# shellcheck shell=bash
# Arch family: Arch Linux ARM (asahi-alarm) and its derivatives.
# shellcheck disable=SC2034  # the variables are read by lib/detect.sh and lib/install.sh
BACKEND_NAME=arch
BACKEND_TOOLS="pacman mkinitcpio grub-mkconfig"
BACKEND_KERNEL_TARGET=pacman-pkg   # kernel make target for an Arch package
BACKEND_KERNEL_FORMAT=.pkg.tar.zst
BACKEND_FW_HOOK="mkinitcpio hook from asahi-scripts (initcpio)"
BACKEND_M1N1_CONF=/etc/default/update-m1n1
BACKEND_UBOOT=/usr/lib/asahi-boot/u-boot-nodtb.bin
# Package names are not verified on an Arch install yet.
BACKEND_PLATFORM_PKGS="asahi-audio alsa-ucm-conf-asahi speakersafetyd asahi-bless"
# Arch names the distro kernel file vmlinuz-<package>, not vmlinuz-<release>.
AGX_STOCK_KNAME="${AGX_STOCK_KNAME:-linux-asahi}"

# shellcheck source=lib/grub.sh
. "$AGX_HOME/lib/grub.sh"

pkg_install_cmd() { printf 'pacman -S --needed --noconfirm %s' "$*"; }
initramfs_cmd() { printf 'mkinitcpio -k %s -g /boot/initramfs-%s.img' "$1" "$1"; }
boot_update_cmd() { printf 'grub-mkconfig -o /boot/grub/grub.cfg'; }

bk_pkg_install() { run pacman -S --needed --noconfirm "$@"; }
bk_relabel() { :; }
bk_initramfs() { run mkinitcpio -k "$1" -g "/boot/initramfs-$1.img"; }
bk_backup_boot_config() { grub_backup "$1"; }
bk_stock_entry_id() { grub_entry_id "$AGX_STOCK_KNAME"; }
bk_boot_entry_id() { grub_entry_id "$1"; }

# grub-mkconfig sorts the newest kernel first. Pin the distro kernel first, as on Debian.
bk_boot_entry_add() {
	local stock
	stock="$(bk_stock_entry_id)"
	[ -n "$stock" ] || die "no GRUB entry for the distro kernel vmlinuz-$AGX_STOCK_KNAME in $GRUB_CFG"
	grub_use_saved
	run grub-set-default "$stock"
	run grub-mkconfig -o "$GRUB_CFG"
}
bk_boot_once() { grub_use_saved; run grub-reboot "$1"; }
bk_set_default() { run grub-set-default "$1"; }
bk_keep_default_on_update() { grub_use_saved; }
bk_show_menu() { grub_show_menu; run grub-mkconfig -o "$GRUB_CFG"; }
bk_firmware_hook() {
	bk_pkg_install asahi-scripts
	echo "  Then add the asahi hook to HOOKS in /etc/mkinitcpio.conf (not automated yet)."
}
