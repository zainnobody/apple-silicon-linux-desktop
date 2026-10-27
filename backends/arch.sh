# shellcheck shell=bash
# Arch family: Arch Linux ARM (asahi-alarm) and its derivatives.
# shellcheck disable=SC2034  # the variables are read by lib/detect.sh
BACKEND_NAME=arch
BACKEND_TOOLS="pacman mkinitcpio grub-mkconfig"
BACKEND_KERNEL_TARGET=pacman-pkg   # kernel make target for an Arch package
BACKEND_KERNEL_FORMAT=.pkg.tar.zst
BACKEND_FW_HOOK="mkinitcpio hook from asahi-scripts (initcpio)"

pkg_install_cmd() { printf 'pacman -S --needed --noconfirm %s' "$*"; }
initramfs_cmd() { printf 'mkinitcpio -k %s -g /boot/initramfs-%s.img' "$1" "$1"; }
boot_update_cmd() { printf 'grub-mkconfig -o /boot/grub/grub.cfg'; }
