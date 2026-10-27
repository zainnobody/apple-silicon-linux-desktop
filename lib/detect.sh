# shellcheck shell=bash
# shellcheck disable=SC2153  # AGX_HOME is set by agx before it sources this file
# agx detect: read the Mac and the distro, then print what `agx install` will do.
# It only reads files. It changes nothing and needs no root.
# Exit codes: 0 ready, 2 unsupported Mac, 3 not Linux on Apple silicon, 4 unknown distro family.

status_text() {
	case "$1" in
	tested) echo "GPU, memory floor and desktop verified on this board" ;;
	expected) echo "same SoC and GPU driver as a tested board, not tested on this board yet" ;;
	upstream) echo "Asahi supports this Mac, including the GPU" ;;
	base-only) echo "Asahi supports the base hardware, no GPU acceleration yet (2D desktop)" ;;
	unsupported) echo "no Linux install path for this Mac yet" ;;
	*) echo "chip not in the pack's table" ;;
	esac
}

# $1 = ID, $2 = ID_LIKE from os-release
distro_family() {
	local w
	for w in $1 $2; do
		case "$w" in
		debian | ubuntu | kali) echo debian; return ;;
		fedora | fedora-asahi-remix) echo fedora; return ;;
		arch | archarm) echo arch; return ;;
		esac
	done
	echo unknown
}

# Sets the AGX_* machine and distro globals and loads the distro backend.
# Used by `agx detect` and by the install steps.
detect_basics() {
	local compat w line
	AGX_MODEL="$(dt_read model || true)"
	AGX_BOARD="" AGX_SOC="" AGX_CHIP="" AGX_STATUS=unknown AGX_GPU_PATH="" AGX_PROFILE_NAME=- AGX_NOTE=""
	compat="$(dt_read compatible || true)"
	for w in $compat; do
		case "$w" in
		apple,arm-platform) ;;
		apple,t[0-9]*) [ -n "$AGX_SOC" ] || AGX_SOC="${w#apple,}" ;;
		apple,*) [ -n "$AGX_BOARD" ] || AGX_BOARD="${w#apple,}" ;;
		esac
	done
	if [ -n "$AGX_SOC" ]; then
		line="$(tsv_lookup "$AGX_HOME/data/socs.tsv" "$AGX_SOC")"
		if [ -n "$line" ]; then
			AGX_CHIP="$(printf '%s' "$line" | cut -f2)"
			AGX_STATUS="$(printf '%s' "$line" | cut -f3)"
			AGX_GPU_PATH="$(printf '%s' "$line" | cut -f4)"
		fi
		line="$(tsv_lookup "$AGX_HOME/data/boards.tsv" "$AGX_BOARD")"
		if [ -n "$line" ]; then
			AGX_STATUS="$(printf '%s' "$line" | cut -f2)"
			AGX_PROFILE_NAME="$(printf '%s' "$line" | cut -f3)"
			AGX_NOTE="$(printf '%s' "$line" | cut -f4)"
		fi
	fi
	AGX_DISTRO_ID="$(osr_get ID)"
	AGX_DISTRO_LIKE="$(osr_get ID_LIKE)"
	AGX_DISTRO_NAME="$(osr_get PRETTY_NAME)"
	AGX_FAMILY="$(distro_family "$AGX_DISTRO_ID" "$AGX_DISTRO_LIKE")"
	BACKEND_TOOLS="" BACKEND_KERNEL_TARGET="" BACKEND_KERNEL_FORMAT="" BACKEND_FW_HOOK=""
	if [ "$AGX_FAMILY" != unknown ]; then
		# shellcheck source=/dev/null
		. "$AGX_HOME/backends/$AGX_FAMILY.sh"
	fi
	AGX_RUNNING_KREL="${AGX_UNAME_R:-$(uname -r)}"
}

agx_detect() {
	local json=0
	[ "${1:-}" = "--json" ] && json=1
	local warnings="" rc=0
	add_warning() { warnings="${warnings}$1"$'\n'; }

	detect_basics
	local model="$AGX_MODEL" board="$AGX_BOARD" soc="$AGX_SOC"
	if [ -z "$soc" ]; then
		if [ "$json" = 1 ]; then
			printf '{"exit_code": 3, "error": "not Linux on Apple silicon"}\n'
		else
			echo "agx: this is not Linux on an Apple silicon Mac (no Apple device tree found)." >&2
		fi
		return 3
	fi

	local chip="$AGX_CHIP" status="$AGX_STATUS" gpu_path="$AGX_GPU_PATH" profile="$AGX_PROFILE_NAME" note="$AGX_NOTE"
	case "$status" in
	unsupported | unknown) rc=2 ;;
	esac

	local sys_fw os_fw m1n1_1 m1n1_2
	sys_fw="$(dt_read chosen/asahi,system-fw-version || true)"
	os_fw="$(dt_read chosen/asahi,os-fw-version || true)"
	m1n1_1="$(dt_read chosen/asahi,m1n1-stage1-version || true)"
	m1n1_2="$(dt_read chosen/asahi,m1n1-stage2-version || true)"

	# Distro and its backend.
	local d_id="$AGX_DISTRO_ID" d_like="$AGX_DISTRO_LIKE" d_name="$AGX_DISTRO_NAME" family="$AGX_FAMILY" missing="" t
	if [ "$family" != unknown ]; then
		for t in $BACKEND_TOOLS; do
			has_tool "$t" || missing="${missing:+$missing }$t"
		done
		[ -z "$missing" ] || add_warning "Missing tools for the $family backend: $missing"
	else
		add_warning "Distro family not supported yet (ID=$d_id, ID_LIKE=$d_like). Supported: Debian, Ubuntu, Kali, Fedora, Arch."
		[ "$rc" != 0 ] || rc=4
	fi

	# Running state.
	local kernel page gpu_driver="none" dev render=no mesa="none" p vendor_fw=no floor="n/a" f
	kernel="$AGX_RUNNING_KREL"
	page="${AGX_PAGESIZE:-$(getconf PAGESIZE 2>/dev/null || echo unknown)}"
	for dev in "$(agx_path /sys/bus/platform/devices)"/*.gpu; do
		[ -L "$dev/driver" ] && gpu_driver="$(basename "$(readlink "$dev/driver")")"
	done
	[ -e "$(agx_path /dev/dri/renderD128)" ] && render=yes
	for p in /opt/mesa-agx /opt/mesa-m3; do
		[ -e "$(agx_path "$p/share/vulkan/icd.d/asahi_icd.aarch64.json")" ] && { mesa="$p"; break; }
	done
	{ [ -d "$(agx_path /usr/lib/firmware/vendor)" ] || [ -d "$(agx_path /lib/firmware/vendor)" ]; } && vendor_fw=yes
	f="$(agx_path /sys/module/pmp_report/parameters/memory_floor)"
	[ -r "$f" ] && floor="$(cat "$f")"

	[ "$page" = 16384 ] || add_warning "Asahi kernels use 16K pages. This kernel uses $page."
	[ "$vendor_fw" = yes ] || add_warning "Apple firmware not found in /usr/lib/firmware/vendor. Install with the Asahi installer from macOS first."
	if [ "$soc" = t6030 ] && [ -n "$os_fw" ] && [ "$os_fw" != 14.7 ]; then
		add_warning "GPU firmware from OS firmware $os_fw is not tested. The G15 driver can refuse it."
	fi
	[ "$status" != expected ] || add_warning "First install on this board: agx install will boot the GPU kernel once, not as the default."

	# Plan for `agx install` (phase 1 and later build it).
	local plan="" kpkg="${BACKEND_KERNEL_FORMAT:-package}"
	case "$status" in
	tested | expected)
		plan="Boot: boot.bin with m1n1 aca1258 and the T6030 GPU and display options
Kernel: 7.2.11-m3gpu+ with the J516S firmware identity and the T6030 memory floor, as a $kpkg (make ${BACKEND_KERNEL_TARGET:-?}); the distro kernel stays as the fallback
Firmware loader: ${BACKEND_FW_HOOK:-none}
Platform: asahi-audio, alsa-ucm-conf-asahi, speakersafetyd, asahi-bless
GPU: build the SiliconForest Mesa on this Mac into /opt/mesa-agx (agx build-mesa)
Profile: $([ "$profile" = - ] && echo "new profile needed (copy machines/j516s.sh)" || echo "machines/$profile.sh")" ;;
	upstream)
		plan="Boot: keep the Asahi boot.bin (m1n1 and U-Boot)
Kernel: the Asahi kernel as a $kpkg
Firmware loader: ${BACKEND_FW_HOOK:-none}
Platform: asahi-audio, alsa-ucm-conf-asahi, speakersafetyd, asahi-bless
GPU: the distro's Mesa (Asahi driver)" ;;
	base-only)
		plan="Boot: keep the Asahi boot.bin (m1n1 and U-Boot)
Kernel: the Asahi kernel as a $kpkg (no GPU driver for this chip yet)
Firmware loader: ${BACKEND_FW_HOOK:-none}
Platform: asahi-audio, alsa-ucm-conf-asahi, speakersafetyd, asahi-bless
GPU: none, 2D desktop" ;;
	esac

	if [ "$json" = 1 ]; then
		local wj="" first=1
		while IFS= read -r w; do
			[ -n "$w" ] || continue
			[ "$first" = 1 ] || wj="$wj, "
			wj="$wj\"$(json_escape "$w")\""
			first=0
		done <<EOF
$warnings
EOF
		printf '{"exit_code": %s, "model": "%s", "board": "%s", "soc": "%s", "chip": "%s", ' \
			"$rc" "$(json_escape "$model")" "$board" "$soc" "$(json_escape "$chip")"
		printf '"status": "%s", "profile": "%s", "gpu_path": "%s", ' "$status" "$profile" "$(json_escape "$gpu_path")"
		printf '"system_fw": "%s", "os_fw": "%s", "m1n1_stage1": "%s", "m1n1_stage2": "%s", ' "$sys_fw" "$os_fw" "$m1n1_1" "$m1n1_2"
		printf '"distro_id": "%s", "distro_name": "%s", "family": "%s", "missing_tools": "%s", ' \
			"$(json_escape "$d_id")" "$(json_escape "$d_name")" "$family" "$missing"
		printf '"kernel": "%s", "page_size": "%s", "gpu_driver": "%s", "render_node": "%s", ' "$kernel" "$page" "$gpu_driver" "$render"
		printf '"native_mesa": "%s", "vendor_firmware": "%s", "memory_floor": "%s", "warnings": [%s]}\n' \
			"$mesa" "$vendor_fw" "$floor" "$wj"
		return "$rc"
	fi

	printf '%-10s %s\n' "Mac" "${model:-unknown}"
	printf '%-10s %s\n' "Board" "apple,$board (SoC apple,$soc, ${chip:-unknown chip})"
	printf '%-10s %s\n' "Support" "$status: $(status_text "$status")"
	[ -z "$note" ] || printf '%-10s %s\n' "" "$note"
	printf '%-10s %s\n' "GPU path" "${gpu_path:-unknown}"
	printf '%-10s %s\n' "Firmware" "system ${sys_fw:-?}, OS ${os_fw:-?}, m1n1 ${m1n1_1:-?} / ${m1n1_2:-?}"
	printf '%-10s %s\n' "Distro" "${d_name:-unknown} (family $family)"
	[ "$family" = unknown ] || printf '%-10s %s\n' "Tools" "$BACKEND_TOOLS${missing:+ (missing: $missing)}"
	printf '%-10s %s\n' "Kernel" "$kernel, page size $page"
	printf '%-10s %s\n' "GPU now" "driver $gpu_driver, render node $render, native Mesa $mesa"
	printf '%-10s %s\n' "Apple fw" "$vendor_fw"
	printf '%-10s %s\n' "Mem floor" "$floor"
	if [ -n "$plan" ]; then
		echo
		echo "Plan for 'agx install' (not built yet):"
		printf '%s\n' "$plan" | sed 's/^/  - /'
	fi
	if [ -n "$warnings" ]; then
		echo
		echo "Warnings:"
		printf '%s' "$warnings" | sed 's/^/  - /'
	fi
	return "$rc"
}
