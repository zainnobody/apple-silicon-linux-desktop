# shellcheck shell=bash
# Debian family: Debian, Ubuntu, Kali and their derivatives.
# shellcheck disable=SC2034  # the variables are read by lib/detect.sh
BACKEND_NAME=debian
BACKEND_TOOLS="apt-get update-initramfs update-grub"
BACKEND_KERNEL_TARGET=bindeb-pkg   # kernel make target for a .deb
BACKEND_KERNEL_FORMAT=.deb
BACKEND_FW_HOOK="new initramfs-tools hook (asahi-scripts has no initramfs-tools hook)"

pkg_install_cmd() { printf 'apt-get install -y %s' "$*"; }
initramfs_cmd() { printf 'update-initramfs -u -k %s' "$1"; }
boot_update_cmd() { printf 'update-grub'; }
