# shellcheck shell=bash
# `agx build-kernel`: the agx kernel as a distro package (.deb, .rpm or Arch package), built with
# the kernel's own package targets (bindeb-pkg, binrpm-pkg, pacman-pkg). Every driver of the M3
# stack is in this package: the GPU driver (built in), USB4, Bluetooth, fan and memory floor.
#
# The build runs in a normal user's work folder and needs no root. It is a dry run unless --build
# is given; --build builds the packages and installs nothing (the install steps stay dry runs).
# The input checks are real: patch hashes, config, and (with --src, always with --build) that
# every patch applies on KERNEL_COMMIT.

AGX_KERNEL_DIR="${AGX_KERNEL_DIR:-$AGX_HOME/kernel}"
AGX_WORK="${AGX_WORK:-$HOME/agx-work}"
# AGX_PKG_DIR (lib/install.sh): where the packages go.
AGX_PKG_REV="${AGX_PKG_REV:-1}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

# Patch files of kernel/series, in order.
series_files() { grep -v '^#' "$AGX_KERNEL_DIR/series" | awk 'NF == 2 { print $2 }'; }

# Each patch must match its hash in kernel/series.
check_series() {
	local sum file n=0
	[ -f "$AGX_KERNEL_DIR/series" ] || die "no $AGX_KERNEL_DIR/series"
	while read -r sum file; do
		[ -f "$AGX_KERNEL_DIR/patches/$file" ] || die "patch missing: kernel/patches/$file"
		[ "$(sha256_file "$AGX_KERNEL_DIR/patches/$file")" = "$sum" ] \
			|| die "patch differs from its hash in kernel/series: $file (run tools/sync-kit-patches.sh)"
		n=$((n + 1))
	done < <(grep -v '^#' "$AGX_KERNEL_DIR/series" | awk 'NF == 2')
	[ "$n" -gt 0 ] || die "kernel/series lists no patches"
	echo "  patches: $n, hashes match kernel/series"
}

# With a kernel git clone: the commit exists, and every patch applies on it in order. The patches
# go one by one into a temporary index (git apply with several files does not chain changes to one
# file), so the clone's work tree and index stay as they are.
check_source() {
	local src="$1" idx f out
	git -C "$src" rev-parse --git-dir > /dev/null 2>&1 || die "$src is not a git clone of the kernel"
	git -C "$src" cat-file -e "$KERNEL_COMMIT^{commit}" 2> /dev/null \
		|| die "commit $KERNEL_COMMIT is not in $src (git -C $src fetch $KERNEL_REPO)"
	idx="$(mktemp)"
	out="$(GIT_INDEX_FILE="$idx" git -C "$src" read-tree "$KERNEL_COMMIT" 2>&1)" || { rm -f "$idx"; die "git read-tree failed: $out"; }
	for f in $(series_files); do
		if ! out="$(GIT_INDEX_FILE="$idx" git -C "$src" apply --cached "$AGX_KERNEL_DIR/patches/$f" 2>&1)"; then
			rm -f "$idx"
			die "the patches do not apply on ${KERNEL_COMMIT:0:12}: $f: $out"
		fi
	done
	rm -f "$idx"
	echo "  source: all $(series_files | wc -l | tr -d ' ') patches apply on ${KERNEL_COMMIT:0:12} in $src"
}

# NAME=value lines of kernel/config/required.conf.
required_settings() { grep -v '^#' "$AGX_KERNEL_DIR/config/required.conf" | grep '='; }

# scripts/config commands for the required settings, then the checks after olddefconfig.
config_commands() {
	local tree="$1" line name val
	run "$tree/scripts/config" --file "$tree/.config" --set-str LOCALVERSION "$AGX_LOCALVERSION"
	while IFS= read -r line; do
		name="${line%%=*}"
		val="${line#*=}"
		case "$val" in
		y) run "$tree/scripts/config" --file "$tree/.config" --enable "$name" ;;
		m) run "$tree/scripts/config" --file "$tree/.config" --module "$name" ;;
		n) run "$tree/scripts/config" --file "$tree/.config" --disable "$name" ;;
		\"*\") run "$tree/scripts/config" --file "$tree/.config" --set-str "$name" "$(printf '%s' "$val" | sed 's/^"//; s/"$//')" ;;
		*) die "bad line in kernel/config/required.conf: $line" ;;
		esac
	done < <(required_settings)
}

# After olddefconfig: each required setting must still hold (Kconfig can turn options back).
check_config() {
	local cfg="$1" line name val bad=0
	[ -f "$cfg" ] || die "no kernel config $cfg"
	while IFS= read -r line; do
		name="${line%%=*}"
		val="${line#*=}"
		if [ "$val" = n ]; then
			! grep -qE "^CONFIG_$name=(y|m)$" "$cfg" || { echo "CONFIG CHECK FAILED: CONFIG_$name is on" >&2; bad=1; }
		else
			grep -qxF "CONFIG_$name=$val" "$cfg" || { echo "CONFIG CHECK FAILED: wanted CONFIG_$name=$val" >&2; bad=1; }
		fi
	done < <(required_settings)
	grep -qxF "CONFIG_LOCALVERSION=\"$AGX_LOCALVERSION\"" "$cfg" || { echo "CONFIG CHECK FAILED: LOCALVERSION" >&2; bad=1; }
	[ "$bad" = 0 ] || die "the kernel config lost a required setting"
	echo "  config check: $(required_settings | wc -l | tr -d ' ') required settings and LOCALVERSION hold in $cfg"
}

# `agx build-kernel [--src DIR] [--family debian|fedora|arch] [--check-config FILE] [--build]`
agx_build_kernel() {
	local src="" family="" check_only="" build=0 tree krel cfg got t0
	while [ $# -gt 0 ]; do
		case "$1" in
		--src) src="${2:-}"; shift 2 ;;
		--family) family="${2:-}"; shift 2 ;;
		--check-config) check_only="${2:-}"; shift 2 ;;
		--build) build=1; shift ;;
		*) die "build-kernel takes --src DIR, --family debian|fedora|arch, --check-config FILE and --build" ;;
		esac
	done
	# Only the required-settings check, on a config that exists (for example after olddefconfig).
	if [ -n "$check_only" ]; then
		check_config "$check_only"
		return 0
	fi
	# The build host needs no Apple hardware: the family comes from os-release or --family.
	[ -n "$family" ] || family="$(distro_family "$(osr_get ID)" "$(osr_get ID_LIKE)")"
	case "$family" in
	debian | fedora | arch) ;;
	*) die "unknown package family '$family': use --family debian, fedora or arch" ;;
	esac
	# shellcheck source=/dev/null
	. "$AGX_HOME/backends/$family.sh"
	# shellcheck source=kernel/source.conf
	. "$AGX_KERNEL_DIR/source.conf"
	# shellcheck source=/dev/null
	. "$AGX_HOME/machines/${AGX_PROFILE:-j516s}.sh"
	cfg="$AGX_KERNEL_DIR/config/$AGX_KERNEL_CONFIG"
	krel="$KERNEL_BASE$AGX_LOCALVERSION"
	tree="$AGX_WORK/kbuild/linux"

	echo "== build-kernel: kernel $krel as $BACKEND_KERNEL_FORMAT ($BACKEND_KERNEL_TARGET), SiliconForest ${KERNEL_COMMIT:0:12} + kernel/series"
	check_series
	[ -f "$cfg" ] || die "no kernel config $cfg (machine profile ${AGX_PROFILE:-j516s})"
	required_settings > /dev/null || die "no settings in kernel/config/required.conf"
	echo "  config: kernel/config/$AGX_KERNEL_CONFIG plus $(required_settings | wc -l | tr -d ' ') settings from kernel/config/required.conf"
	if [ "$build" = 1 ]; then
		# A real build: never as root, and only on a source where every patch applies.
		[ "$(id -u)" != 0 ] || die "build as a normal user, not as root"
		check_source "${src:=$AGX_WORK/src/linux}"
		AGX_APPLY=1
		t0="$(date +%s)"
		echo "  real build (no install), started $(date '+%Y-%m-%d %H:%M:%S')"
	elif [ -n "$src" ]; then
		check_source "$src"
	else
		src="$AGX_WORK/src/linux"
		echo "  (no --src: the patch check on the source is skipped)"
	fi

	echo "  build tools: $BACKEND_BUILD_DEPS"
	[ -z "${BACKEND_KERNEL_NOTE:-}" ] || echo "  note: $BACKEND_KERNEL_NOTE"
	# An exported tree, not a checkout: a git tree with changes adds "+" to the release name.
	run rm -rf "$tree"
	run mkdir -p "$tree"
	run sh -c "git -C '$src' archive --format=tar $KERNEL_COMMIT | tar -x -C '$tree'"
	# One patch at a time, in order. GIT_CEILING_DIRECTORIES: inside another git repository, git
	# apply would skip the patches.
	run sh -c "cd '$tree' && export GIT_CEILING_DIRECTORIES='$(dirname "$tree")' && for p in $(series_files | sed "s|^|$AGX_KERNEL_DIR/patches/|" | tr '\n' ' '); do git apply \"\$p\" || exit 1; done"
	[ "$AGX_APPLY" != 1 ] || [ -x "$tree/scripts/config" ] || die "no scripts/config in the exported tree: is $src a kernel clone?"
	run cp "$cfg" "$tree/.config"
	config_commands "$tree"
	run make -C "$tree" olddefconfig
	if [ "$AGX_APPLY" = 1 ]; then
		check_config "$tree/.config"
		got="$(make -C "$tree" -s kernelrelease)"
		[ "$got" = "$krel" ] || die "the kernel release is $got, not $krel"
	else
		echo "+ check $tree/.config: $(required_settings | wc -l | tr -d ' ') required settings and CONFIG_LOCALVERSION=\"$AGX_LOCALVERSION\""
		echo "+ check: make -C $tree -s kernelrelease prints $krel"
	fi
	# shellcheck disable=SC2046  # one word per make variable
	run make -C "$tree" -j"$JOBS" $(bk_kernel_make_vars "$krel") "$BACKEND_KERNEL_TARGET"
	run mkdir -p "$AGX_PKG_DIR"
	run sh -c "cp $(bk_kernel_pkg_out "$tree") '$AGX_PKG_DIR/'"
	run sh -c "echo $krel > '$AGX_PKG_DIR/kernel-release'"
	if [ "$build" = 1 ]; then
		echo "  built in $(( $(date +%s) - t0 )) s:"
		(cd "$AGX_PKG_DIR" && ls -l && sha256sum ./*"$BACKEND_KERNEL_FORMAT")
	fi
	echo "  install it with: agx step kernel (AGX_PKG_DIR=$AGX_PKG_DIR)"
}
