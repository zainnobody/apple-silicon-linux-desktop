# shellcheck shell=bash
# Install steps, ported from agx-linux-kit stages A to K. Each step calls the distro backend
# for packages, initramfs, boot entries and file labels, so the same step works on the
# Debian family, Fedora and Arch. All steps are dry runs (lib/run.sh).
#
# Stage map: A = backup, B = mesa + kernel, C/D/E = bootbin-build + bootbin-use + boot-once,
# F/H/I/J = kernel-replace (a rebuilt image), G = mesa-select, K = default, macOS switch =
# macos-switch. Stage L (two modules added to a running kernel) is not needed: the pack's
# kernel build has CONFIG_USB4_APPLE_SOC=m and the Bluetooth patch.

# Build output of `agx build` (later phase) or of agx-linux-kit: kernel-<release>/,
# mesa-stage/<prefix>, m1n1/m1n1.bin and the kernel-release file.
AGX_USER="${AGX_USER:-${SUDO_USER:-$(id -un)}}"
AGX_STAGE_DIR="${AGX_STAGE_DIR:-$HOME/agx-work/out}"
AGX_KREL="${AGX_KREL:-$(cat "$AGX_STAGE_DIR/kernel-release" 2>/dev/null || true)}"
AGX_M1N1_BIN="${AGX_M1N1_BIN:-$AGX_STAGE_DIR/m1n1/m1n1.bin}"
AGX_LOCALVERSION="${AGX_LOCALVERSION:--agx}"
MESA_PREFIX="${MESA_PREFIX:-/opt/mesa-agx}"
ESP_M1N1="${ESP_M1N1:-/boot/efi/m1n1}"

# Load the machine profile of this board. Exit 5 when the board has no profile yet.
load_profile() {
	[ "$AGX_PROFILE_NAME" != - ] || {
		echo "agx: apple,$AGX_BOARD has no machine profile yet. Copy machines/j516s.sh to machines/$AGX_BOARD.sh and set its values." >&2
		exit 5
	}
	# shellcheck source=/dev/null
	. "$AGX_HOME/machines/$AGX_PROFILE_NAME.sh"
}

# Paths of the plan that this user cannot read. A dry run as a normal user then shows
# placeholders. Prints the paths, space separated.
unreadable_paths() {
	local p d out=""
	for p in "$@"; do
		[ -n "$p" ] || continue
		d="$(agx_path "$p")"
		if [ -e "$d" ]; then
			[ -r "$d" ] || out="$out $p"
		elif [ -d "$(dirname "$d")" ] && [ ! -x "$(dirname "$d")" ]; then
			out="$out $p"
		fi
	done
	printf '%s' "${out# }"
}

note_unreadable() {
	local u
	[ "$AGX_APPLY" != 1 ] || return 0
	u="$(unreadable_paths "$ESP_M1N1" "${BLS_DIR:-}" "${GRUB_CFG:-}")"
	[ -z "$u" ] || echo "Note: this user cannot read $u. Run with sudo for an exact plan (it stays a dry run)."
}

need_kernel_build() {
	[ -n "$AGX_KREL" ] || die "no kernel release: set AGX_KREL or build the kernel first"
	[ -f "$AGX_STAGE_DIR/kernel-$AGX_KREL/boot/vmlinuz-$AGX_KREL" ] || die "no built kernel in $AGX_STAGE_DIR/kernel-$AGX_KREL"
}

step_backup() {
	local esp_bin="$ESP_M1N1/boot.bin" bk
	bk="/root/agx-backup/$(date +%Y%m%d-%H%M%S)"
	echo "== backup: copy the boot files, pause automatic boot.bin rebuilds"
	[ -e "$(agx_path "$esp_bin")" ] || die "no $esp_bin: install with the Asahi installer first"
	if [ -e "$(agx_path "$esp_bin.stock")" ]; then
		echo "  boot.bin.stock exists, kept as it is"
	else
		run cp --preserve=timestamps "$esp_bin" "$esp_bin.stock"
	fi
	run mkdir -p "$bk"
	run cp -a "$esp_bin" "$bk/boot.bin.stock"
	[ ! -e "$(agx_path /etc/m1n1.conf)" ] || run cp -a /etc/m1n1.conf "$bk/"
	[ ! -e "$(agx_path "$BACKEND_M1N1_CONF")" ] || run cp -a "$BACKEND_M1N1_CONF" "$bk/"
	bk_backup_boot_config "$bk"
	if grep -qs '^M1N1_UPDATE_DISABLED=' "$(agx_path "$BACKEND_M1N1_CONF")"; then
		echo "  automatic boot.bin rebuilds are already paused"
	else
		printf '# agx: pause automatic boot.bin rebuilds; a rebuild drops the GPU options\nM1N1_UPDATE_DISABLED=1\n' \
			| append_file "$BACKEND_M1N1_CONF"
	fi
}

step_platform() {
	echo "== platform: audio, speaker safety and boot volume tools"
	# shellcheck disable=SC2086  # one word per package
	bk_pkg_install $BACKEND_PLATFORM_PKGS
}

step_firmware() {
	echo "== firmware: load the Apple firmware from the EFI partition (vendorfw) at boot"
	bk_firmware_hook
}

step_mesa() {
	local src="$AGX_STAGE_DIR/mesa-stage$MESA_PREFIX"
	echo "== mesa: install the native Mesa into $MESA_PREFIX"
	[ -e "$src/lib64/libvulkan_asahi.so" ] || die "no built Mesa in $src"
	[ ! -e "$(agx_path "$MESA_PREFIX")" ] || die "$MESA_PREFIX exists already"
	run cp -a "$src" "$MESA_PREFIX"
	run chown -R root:root "$MESA_PREFIX"
	bk_relabel "$MESA_PREFIX"
}

# <new | replace>. New adds a boot entry. Replace backs up the installed kernel first.
step_kernel() {
	local mode="${1:-new}" k="$AGX_KREL" ks m
	need_kernel_build
	ks="$AGX_STAGE_DIR/kernel-$k"
	m="/usr/lib/modules/$k"
	echo "== kernel-$mode: kernel $k"
	[ "$AGX_RUNNING_KREL" != "$k" ] || die "boot the distro kernel before installing $k"
	if [ "$mode" = new ]; then
		[ ! -e "$(agx_path "$m")" ] || die "$m exists already (use the kernel-replace step)"
	else
		[ -e "$(agx_path "$m")" ] || die "no installed $k to replace (use the kernel step)"
		local bk
		bk="/root/agx-backup/$(date +%Y%m%d-%H%M%S)-pre-replace"
		run mkdir -p "$bk"
		run cp -a "/boot/vmlinuz-$k" "/boot/config-$k" "/boot/System.map-$k" "$m" "$bk/"
		run rm -rf "$m"
	fi
	run cp -a "$ks/lib/modules/$k" "$m"
	run chown -R root:root "$m"
	run rm -f "$m/build" "$m/source"
	run depmod -a "$k"
	run install -m 0755 "$ks/boot/vmlinuz-$k" "/boot/vmlinuz-$k"
	run install -m 0644 "$ks/boot/config-$k" "/boot/config-$k"
	run install -m 0644 "$ks/boot/System.map-$k" "/boot/System.map-$k"
	run mkdir -p "/boot/dtb-$k"
	run cp -a "$ks/dtb/apple" "/boot/dtb-$k/"
	bk_relabel "$m" "/boot/vmlinuz-$k" "/boot/config-$k" "/boot/System.map-$k" "/boot/dtb-$k"
	bk_initramfs "$k"
	[ "$mode" != new ] || bk_boot_entry_add "$k"
}

# <dtb | gpu>: m1n1 + the kernel's DTBs + U-Boot + options, as update-m1n1 builds it.
# dtb has no new options (GPU off). gpu adds the profile's GPU and display options.
step_bootbin_build() {
	local stage="$1" dtbs="/boot/dtb-$AGX_KREL/apple" target opts="" o
	target="$ESP_M1N1/boot.bin.$stage"
	case "$stage" in
	dtb) ;;
	gpu) opts="$AGX_M1N1_OPTIONS" ;;
	*) die "bootbin-build takes dtb or gpu" ;;
	esac
	for o in $opts; do
		printf '%s' "$o" | grep -qE '^chosen\.[A-Za-z0-9,._-]+=[^[:space:]]+$' || die "bad m1n1 option: $o"
	done
	echo "== bootbin-build $stage: $target"
	[ -f "$AGX_M1N1_BIN" ] || die "no m1n1 build at $AGX_M1N1_BIN"
	require_after "no $dtbs/$AGX_DTB_NAME (run the kernel step)" [ -e "$(agx_path "$dtbs/$AGX_DTB_NAME")" ]
	run sh -c "cat '$AGX_M1N1_BIN' $dtbs/t6*.dtb $dtbs/t81*.dtb > '$target.new'"
	run sh -c "gzip -c '$BACKEND_UBOOT' >> '$target.new'"
	run sh -c "grep -E '^(chosen\\.[^=]+|display|mitigations)=' /etc/m1n1.conf >> '$target.new' || true"
	[ -z "$opts" ] || run sh -c "printf '%s\\n' $opts >> '$target.new'"
	run mv -f "$target.new" "$target"
}

step_bootbin_use() {
	local src="$ESP_M1N1/boot.bin.$1" dst="$ESP_M1N1/boot.bin"
	echo "== bootbin-use $1: boot.bin becomes boot.bin.$1"
	require_after "no boot.bin.stock backup (run the backup step)" [ -e "$(agx_path "$ESP_M1N1/boot.bin.stock")" ]
	require_after "no $src (run bootbin-build $1)" [ -e "$(agx_path "$src")" ]
	run cp -f "$src" "$dst.new"
	run mv -f "$dst.new" "$dst"
}

step_boot_once() {
	local id
	id="$(bk_boot_entry_id "$AGX_KREL")"
	echo "== boot-once: the next boot only uses kernel $AGX_KREL; the default stays"
	if [ -z "$id" ]; then
		[ "$AGX_APPLY" != 1 ] || die "no boot entry for $AGX_KREL"
		id="<entry of $AGX_KREL>"
		echo "  (dry run: the entry exists after the kernel step)"
	fi
	bk_boot_once "$id"
}

step_mesa_select() {
	local f out
	echo "== mesa-select: desktop and login screen use $MESA_PREFIX only when the GPU driver is bound"
	for f in agx-mesa-select 60-agx-native-mesa; do
		out="$(sed -e "s|@MESA_PREFIX@|$MESA_PREFIX|g" -e "s|@AGX_GPU_DRIVER@|$AGX_GPU_DRIVER|g" \
			-e "s|@AGX_GPU_NODE@|$AGX_GPU_NODE|g" -e "s|@LOCALVERSION@|$AGX_LOCALVERSION|g" "$AGX_HOME/system/$f.in")"
		! printf '%s' "$out" | grep -q '@[A-Z0-9_]*@' || die "unfilled value in system/$f.in"
		printf '%s\n' "$out" | sh -n || die "system/$f.in is not a valid shell script"
		case "$f" in
		agx-mesa-select) printf '%s\n' "$out" | write_file /usr/local/sbin/agx-mesa-select 0755 ;;
		*) printf '%s\n' "$out" | write_file "/etc/systemd/user-environment-generators/$f" 0755 ;;
		esac
	done
	write_file /etc/systemd/system/agx-mesa-select.service 0644 < "$AGX_HOME/system/agx-mesa-select.service"
	bk_relabel /usr/local/sbin/agx-mesa-select /etc/systemd/system/agx-mesa-select.service /etc/systemd/user-environment-generators
	run systemctl daemon-reload
	run systemctl enable agx-mesa-select.service
}

# Stage K: the GPU kernel becomes the default boot. The distro kernel stays in the menu.
step_default() {
	local id
	id="$(bk_boot_entry_id "$AGX_KREL")"
	echo "== default: kernel $AGX_KREL with boot.bin.gpu becomes the default boot"
	require_after "automatic boot.bin rebuilds are not paused (run the backup step)" \
		grep -qs '^M1N1_UPDATE_DISABLED=1' "$(agx_path "$BACKEND_M1N1_CONF")"
	[ -n "$id" ] || { [ "$AGX_APPLY" != 1 ] || die "no boot entry for $AGX_KREL"; id="<entry of $AGX_KREL>"; }
	step_bootbin_use gpu
	bk_keep_default_on_update
	bk_set_default "$id"
	bk_show_menu
}

step_macos_switch() {
	echo "== macos-switch: start macOS once from Linux, without a password"
	bk_pkg_install asahi-bless
	write_file /usr/local/sbin/agx-os 0755 <<'EOF'
#!/usr/bin/env bash
# Boot volume control for one user without a password (installed by agx).
set -euo pipefail
case "${1:-}" in
status) echo "default: $(asahi-bless --get-boot)"; echo "next: $(asahi-bless --get-boot --next 2>&1 || true)" ;;
macos-once) asahi-bless --set-boot-macos --next --yes; echo "next boot: macOS (once)" ;;
clear-next) asahi-bless --clear-next ;;
*) echo "usage: agx-os status | macos-once | clear-next" >&2; exit 1 ;;
esac
EOF
	write_file /etc/sudoers.d/agx-os 0440 <<EOF
Cmnd_Alias AGX_OS = /usr/local/sbin/agx-os status, /usr/local/sbin/agx-os macos-once, /usr/local/sbin/agx-os clear-next
$AGX_USER ALL=(root) NOPASSWD: AGX_OS
EOF
	run visudo -c
}

# `agx step <name> [arg]`
agx_step() {
	local name="${1:-}"
	[ $# -eq 0 ] || shift
	detect_basics
	[ -n "$AGX_SOC" ] || { echo "agx: this is not Linux on an Apple silicon Mac." >&2; exit 3; }
	[ "$AGX_FAMILY" != unknown ] || { echo "agx: distro family not supported yet (ID=$AGX_DISTRO_ID)." >&2; exit 4; }
	need_root
	note_unreadable
	case "$name" in
	backup) step_backup ;;
	platform) step_platform ;;
	firmware) step_firmware ;;
	macos-switch) step_macos_switch ;;
	mesa | kernel | kernel-replace | bootbin-build | bootbin-use | boot-once | mesa-select | default)
		case "$AGX_STATUS" in
		tested | expected) ;;
		*) echo "agx: the $name step is for the M3 Pro GPU path; this Mac is $AGX_STATUS." >&2; exit 2 ;;
		esac
		load_profile
		case "$name" in
		mesa) step_mesa ;;
		kernel) step_kernel new ;;
		kernel-replace) step_kernel replace ;;
		bootbin-build) step_bootbin_build "${1:-}" ;;
		bootbin-use) step_bootbin_use "${1:-}" ;;
		boot-once) step_boot_once ;;
		mesa-select) step_mesa_select ;;
		default) step_default ;;
		esac
		;;
	*) die "unknown step '$name'. Steps: backup platform firmware mesa kernel kernel-replace bootbin-build bootbin-use boot-once mesa-select default macos-switch" ;;
	esac
}

# `agx plan-install`: dry run of every step for this Mac, in order, with the reboots.
agx_plan_install() {
	detect_basics
	[ -n "$AGX_SOC" ] || { echo "agx: this is not Linux on an Apple silicon Mac." >&2; exit 3; }
	[ "$AGX_FAMILY" != unknown ] || { echo "agx: distro family not supported yet (ID=$AGX_DISTRO_ID)." >&2; exit 4; }
	echo "Install plan for ${AGX_MODEL:-apple,$AGX_BOARD} on ${AGX_DISTRO_NAME:-$AGX_DISTRO_ID} ($AGX_FAMILY backend). Dry run: nothing changes."
	note_unreadable
	case "$AGX_STATUS" in
	unsupported | unknown)
		echo "agx: no Linux install path for this Mac yet ($AGX_SOC)." >&2
		exit 2
		;;
	upstream | base-only)
		echo "Part 1 of 1: the distro's Asahi kernel and Mesa cover this Mac (Fedora Asahi Remix, Ubuntu Asahi, Arch Linux ARM)."
		step_platform
		step_firmware
		step_macos_switch
		return 0
		;;
	esac
	load_profile
	echo
	echo "Part 1 of 4, no reboot:"
	step_backup
	step_platform
	step_firmware
	step_mesa
	step_kernel new
	step_bootbin_build dtb
	step_bootbin_build gpu
	step_mesa_select
	step_macos_switch
	echo
	echo "Part 2 of 4: start the new kernel once with the GPU off."
	step_bootbin_use dtb
	step_boot_once
	echo "+ reboot, then check: uname -r is $AGX_KREL, the system boots, keyboard and Wi-Fi work"
	echo
	echo "Part 3 of 4: start the new kernel once with the GPU on."
	step_bootbin_use gpu
	step_boot_once
	echo "+ reboot, then check: the $AGX_GPU_DRIVER driver is bound, /dev/dri/renderD128 exists, the readback test passes"
	echo
	if [ "$AGX_STATUS" = expected ]; then
		echo "Part 4 of 4 is skipped: this board is not tested yet. Make the GPU kernel the default only after part 3 passes."
		return 0
	fi
	echo "Part 4 of 4: make the GPU kernel the default. The distro kernel stays in the boot menu."
	step_default
}
