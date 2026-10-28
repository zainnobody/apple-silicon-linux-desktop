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
bk_backup_boot_config() {
	run cp -a "$BLS_DIR" "$1/loader-entries"
	run cp -a /boot/grub2/grubenv "$1/grubenv"
}

# The id of the entry for $1. Before the entry exists, the id that kernel-install gives it
# (<machine id>-<release>, the running kernel's entry name with the new release).
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

# Kernel package (make binrpm-pkg). Only the kernel package is installed, not kernel-headers or
# kernel-devel: the distro's kernel-headers package belongs to the C library.
BACKEND_BUILD_DEPS="gcc make flex bison bc perl rsync kmod cpio dwarves elfutils-libelf-devel elfutils-devel openssl-devel rpm-build rust rust-src bindgen-cli clang lld"
# Make variables, one per line. The spec strips the modules only when it makes a debuginfo
# package, and compressed modules (CONFIG_MODULE_COMPRESS) turn that off: the first M3 build gave a
# 1.3 GB package with 7.4 GB of modules. install_mod_strip strips them, as bindeb-pkg and
# pacman-pkg always do. AGX_RPM_NODEPS=1 also skips rpmbuild's BuildRequires check, on a host where
# the build user cannot install packages: the spec asks for elfutils-devel, which only BTF and
# gendwarfksyms use (both off in the M3 config). A tool that is really missing still stops the compile.
bk_kernel_make_vars() {
	if [ "${AGX_RPM_NODEPS:-0}" = 1 ]; then
		printf '%s\n' "RPMOPTS=--nodeps --define='install_mod_strip 1'"
	else
		printf '%s\n' "RPMOPTS=--define='install_mod_strip 1'"
	fi
}
bk_kernel_pkg_out() { printf "'%s'/rpmbuild/RPMS/aarch64/kernel-[0-9]*.rpm" "$1"; }
bk_kernel_pkg_file() { newest_file "$AGX_PKG_DIR" "kernel-$(printf '%s' "$1" | tr - _)-*.aarch64.rpm"; }
bk_dtb_dir() { printf '/usr/lib/modules/%s/dtb' "$1"; }
BACKEND_KERNEL_NOTE="binrpm-pkg takes the package release from the kernel build counter, and agx sets install_mod_strip (the spec does not strip compressed-module builds)"

# The package's %post runs kernel-install: dracut builds the initramfs (with dracut-asahi) and the
# Boot Loader Spec entry is written. With UPDATEDEFAULT=no the default entry stays.
# binrpm-pkg names the package "kernel". The Fedora repositories have an unrelated "kernel" package
# (4K pages, no Apple support; Fedora Asahi Remix uses kernel-16k), so dnf must not offer it.
bk_kernel_pre_install() {
	run dnf config-manager setopt fedora.excludepkgs=kernel updates.excludepkgs=kernel updates-testing.excludepkgs=kernel
	bk_keep_default_on_update
}
# rpm installs kernels side by side, and two builds of one release share their files. So a
# replace removes the installed build first. The running kernel is the distro kernel.
bk_kernel_pkg_install() {
	[ "$2" != replace ] || run dnf remove -y "kernel-$(printf '%s' "$AGX_KREL" | tr - _)"
	run dnf install -y "$1"
}
bk_kernel_post_install() {
	require_after "no Boot Loader Spec entry for $1 after the package install" [ -n "$(bls_entry_of "$1")" ]
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
