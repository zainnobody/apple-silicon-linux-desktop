# shellcheck shell=bash
# Fedora family: Fedora Asahi Remix and Fedora.
# shellcheck disable=SC2034  # the variables are read by lib/detect.sh
BACKEND_NAME=fedora
BACKEND_TOOLS="dnf dracut grub2-mkconfig"
BACKEND_KERNEL_TARGET=binrpm-pkg   # kernel make target for an .rpm
BACKEND_KERNEL_FORMAT=.rpm
BACKEND_FW_HOOK="dracut module from asahi-scripts (dracut-asahi)"

pkg_install_cmd() { printf 'dnf install -y %s' "$*"; }
initramfs_cmd() { printf 'dracut --force --kver %s' "$1"; }
boot_update_cmd() { printf 'grub2-mkconfig -o /boot/grub2/grub.cfg'; }
