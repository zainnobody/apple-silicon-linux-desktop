#!/usr/bin/env bash
# Tests for `agx build-kernel` (dry runs). The real kernel/ folder gives the plan of each package
# family. A fake kernel git clone with a fake series tests the real checks: patch hashes, that the
# patches apply in order on KERNEL_COMMIT, and that the check leaves the clone as it was.
# Runs on Linux and macOS, bash 3.2+. Needs git.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
AGX="$HERE/../agx"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0
COMMIT=0e1f466613761fecbe71ba8ca25f8b3598577062

# A fake root with only os-release: the build host needs no Apple hardware.
osr() {
	mkdir -p "$TMP/$1/etc"
	printf '%s\n' "$2" > "$TMP/$1/etc/os-release"
}
osr kali $'ID=kali\nID_LIKE=debian'
osr fedora $'ID=fedora-asahi-remix\nID_LIKE=fedora'
osr arch $'ID=archarm\nID_LIKE=arch'
mkdir -p "$TMP/macos"

# check <name> <expected exit> <fake root> [VAR=value ...] -- <agx args> -- <must contain ...> [! <must not contain> ...]
check() {
	local name="$1" want="$2" root="$3" out got s ok=1 neg=0 envs=() args=()
	shift 3
	while [ $# -gt 0 ] && [ "$1" != -- ]; do envs+=("$1"); shift; done
	shift
	while [ $# -gt 0 ] && [ "$1" != -- ]; do args+=("$1"); shift; done
	[ $# -eq 0 ] || shift
	out="$(env AGX_ROOT="$TMP/$root" AGX_WORK="$TMP/work" AGX_STAGE_DIR="$TMP/out" JOBS=8 \
		${envs[@]+"${envs[@]}"} "$AGX" "${args[@]}" 2>&1)"
	got=$?
	[ "$got" = "$want" ] || { echo "FAIL $name: exit $got, want $want"; ok=0; }
	for s in "$@"; do
		if [ "$s" = '!' ]; then neg=1; continue; fi
		if [ "$neg" = 1 ]; then
			! printf '%s' "$out" | grep -qF -- "$s" || { echo "FAIL $name: must not contain: $s"; ok=0; }
		else
			printf '%s' "$out" | grep -qF -- "$s" || { echo "FAIL $name: missing: $s"; ok=0; }
		fi
	done
	if [ "$ok" = 1 ]; then
		pass=$((pass + 1))
		echo "ok   $name"
	else
		fail=$((fail + 1))
		printf '%s\n' "$out" | sed 's/^/     | /' | head -60
	fi
}

# expect <name> <command ...>
expect() {
	local name="$1"
	shift
	if "$@"; then
		pass=$((pass + 1))
		echo "ok   $name"
	else
		fail=$((fail + 1))
		echo "FAIL $name"
	fi
}

# The plan for each package family, from the real kernel/ folder.
check debian 0 kali -- build-kernel -- \
	"kernel 7.2.11-agx as .deb (bindeb-pkg)" "patches: 4, hashes match kernel/series" \
	"archive --format=tar $COMMIT" "GIT_CEILING_DIRECTORIES=" "m3-kernel-tree-2026-10-26.patch" "macsmc-hwmon-ftst-unlock.patch" \
	"kernel/config/t6030.config" "--set-str LOCALVERSION -agx" "--disable APPLE_SEP" "--module USB4_APPLE_SOC" \
	"--disable LOCALVERSION_AUTO" "olddefconfig" "kernelrelease prints 7.2.11-agx" \
	"-j8 KDEB_PKGVERSION=7.2.11-agx-1 INSTALL_MOD_STRIP=1 bindeb-pkg" "linux-image-[0-9]*.deb" \
	"echo 7.2.11-agx > '$TMP/out/packages/kernel-release'" \
	! "linux-libc-dev" "binrpm-pkg" "pacman-pkg"
check fedora 0 fedora -- build-kernel -- \
	"as .rpm (binrpm-pkg)" "rpmbuild/RPMS/aarch64/kernel-[0-9]*.rpm" "note: binrpm-pkg takes the package release" \
	"rpm-build" ! "KDEB_PKGVERSION" "pacman-pkg"
check arch 0 arch -- build-kernel -- \
	"as .pkg.tar.zst (pacman-pkg)" "PACMAN_PKGBASE=linux-agx PACMAN_EXTRAPACKAGES=headers INSTALL_MOD_STRIP=1 pacman-pkg" \
	"linux-agx-[0-9]*.pkg.tar.zst" "linux-agx-headers-*.pkg.tar.zst" ! "bindeb-pkg"
check family-flag 0 macos -- build-kernel --family arch -- "pacman-pkg"
check no-family 1 macos -- build-kernel -- "unknown package family"
check bad-arg 1 kali -- build-kernel --fast -- "build-kernel takes --src DIR"
check pkg-rev 0 kali AGX_PKG_REV=3 -- build-kernel -- "KDEB_PKGVERSION=7.2.11-agx-3"

# A dry run creates no file.
expect "dry run creates no file" [ ! -e "$TMP/work" ] && [ ! -e "$TMP/out" ]

# A changed or missing patch stops the build.
cp -R "$HERE/../kernel" "$TMP/kbad"
echo "# changed" >> "$TMP/kbad/patches/g15-perf-tgt-util.patch"
check changed-patch 1 kali AGX_KERNEL_DIR="$TMP/kbad" -- build-kernel -- \
	"patch differs from its hash in kernel/series: g15-perf-tgt-util.patch"
rm "$TMP/kbad/patches/g15-perf-tgt-util.patch"
check missing-patch 1 kali AGX_KERNEL_DIR="$TMP/kbad" -- build-kernel -- "patch missing: kernel/patches/g15-perf-tgt-util.patch"
cp -R "$HERE/../kernel" "$TMP/kbadcfg"
echo "USB4_APPLE_SOC=maybe" >> "$TMP/kbadcfg/config/required.conf"
check bad-required 1 kali AGX_KERNEL_DIR="$TMP/kbadcfg" -- build-kernel -- "bad line in kernel/config/required.conf: USB4_APPLE_SOC=maybe"

# A fake kernel clone and a fake series: patch 2 changes a line that patch 1 adds.
G="$TMP/linux"
git init -q "$G"
mkdir -p "$G/drivers"
printf 'int a;\nint b;\n' > "$G/drivers/x.c"
git -C "$G" add -A
git -C "$G" -c user.name=t -c user.email=t@t commit -q -m base
FAKE_COMMIT="$(git -C "$G" rev-parse HEAD)"
K="$TMP/kfake"
mkdir -p "$K/patches" "$K/config"
cp "$HERE/../kernel/config/required.conf" "$K/config/"
: > "$K/config/t6030.config"
printf 'KERNEL_REPO=https://example.invalid/linux.git\nKERNEL_COMMIT=%s\nKERNEL_BASE=7.2.11\n' "$FAKE_COMMIT" > "$K/source.conf"
printf 'int a;\nint b;\nint c;\n' > "$G/drivers/x.c"
git -C "$G" diff > "$K/patches/p1.patch"
# p2 is the change from the p1 state to the final state.
printf 'int a;\nint b;\nint c;\n' > "$TMP/x.p1"
printf 'int a;\nint b;\nint c2;\n' > "$TMP/x.p2"
(cd "$TMP" && diff -u x.p1 x.p2 | sed -e '1s|.*|--- a/drivers/x.c|' -e '2s|.*|+++ b/drivers/x.c|') > "$K/patches/p2.patch"
git -C "$G" checkout -q -- drivers/x.c
sum() {
	if command -v sha256sum > /dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}
series() {
	{
		echo "# fake series"
		for f in "$@"; do printf '%s  %s\n' "$(sum "$K/patches/$f")" "$f"; done
	} > "$K/series"
}
series p1.patch p2.patch
before="$(git -C "$G" status --porcelain; git -C "$G" ls-files -s; git -C "$G" rev-parse HEAD)"
check src-ok 0 kali AGX_KERNEL_DIR="$K" -- build-kernel --src "$G" -- "source: all 2 patches apply on ${FAKE_COMMIT:0:12}"
after="$(git -C "$G" status --porcelain; git -C "$G" ls-files -s; git -C "$G" rev-parse HEAD)"
expect "patch check leaves the clone as it was" [ "$before" = "$after" ]
series p2.patch
check src-order 1 kali AGX_KERNEL_DIR="$K" -- build-kernel --src "$G" -- "the patches do not apply on ${FAKE_COMMIT:0:12}: p2.patch"
series p1.patch p2.patch
sed -i.bak "s/^KERNEL_COMMIT=.*/KERNEL_COMMIT=1111111111111111111111111111111111111111/" "$K/source.conf"
check src-commit 1 kali AGX_KERNEL_DIR="$K" -- build-kernel --src "$G" -- "commit 1111111111111111111111111111111111111111 is not in"
check src-notgit 1 kali AGX_KERNEL_DIR="$K" -- build-kernel --src "$TMP/macos" -- "is not a git clone of the kernel"
mv "$K/source.conf.bak" "$K/source.conf"

# Run the printed source steps for real: export the tree, then apply the patches one by one.
# The work folder is inside another git repository, where a plain git apply skips the patches.
OUTER="$TMP/outer"
git init -q "$OUTER"
plan="$(AGX_ROOT="$TMP/kali" AGX_WORK="$OUTER/work" AGX_KERNEL_DIR="$K" "$AGX" build-kernel --src "$G" 2>&1)"
mkdir -p "$OUTER/work/kbuild/linux"
printf '%s\n' "$plan" | grep -E '^\+ sh -c (git -C|cd )' | sed 's/^+ sh -c //' > "$TMP/steps"
(while IFS= read -r line; do sh -c "$line" || exit 1; done < "$TMP/steps") > "$TMP/steps.out" 2>&1
expect "printed source steps run: 2 steps" [ "$(wc -l < "$TMP/steps" | tr -d ' ')" = 2 ]
expect "patches applied in order inside another git repo" \
	[ "$(cat "$OUTER/work/kbuild/linux/drivers/x.c" 2> /dev/null)" = "$(printf 'int a;\nint b;\nint c2;')" ]

# --build runs for real: never without a source clone where the patches apply.
check build-nosrc 1 kali -- build-kernel --build -- "is not a git clone of the kernel" ! "real build"
# With the fake clone: the export and the patches run for real, then the build stops, because the
# fake tree has no kernel scripts/config.
check build-fake 1 kali AGX_KERNEL_DIR="$K" AGX_WORK="$TMP/realwork" -- build-kernel --build --src "$G" -- \
	"source: all 2 patches apply" "real build (no install), started" "+ sh -c cd '$TMP/realwork/kbuild/linux'" \
	"no scripts/config in the exported tree: is $G a kernel clone?" ! "make -C"
expect "build-fake: the patches are in the real tree" \
	[ "$(cat "$TMP/realwork/kbuild/linux/drivers/x.c" 2> /dev/null)" = "$(printf 'int a;\nint b;\nint c2;')" ]

# The config check after olddefconfig.
good="$TMP/good.config"
{
	grep -v '^#' "$HERE/../kernel/config/required.conf" | grep '=' | while IFS= read -r l; do
		case "$l" in
		*=n) echo "# CONFIG_${l%=n} is not set" ;;
		*) echo "CONFIG_$l" ;;
		esac
	done
	echo 'CONFIG_LOCALVERSION="-agx"'
} > "$good"
check config-good 0 kali -- build-kernel --check-config "$good" -- "config check: 18 required settings and LOCALVERSION hold"
sed 's/^# CONFIG_APPLE_SEP is not set$/CONFIG_APPLE_SEP=y/' "$good" > "$TMP/sep.config"
check config-sep 1 kali -- build-kernel --check-config "$TMP/sep.config" -- "CONFIG CHECK FAILED: CONFIG_APPLE_SEP is on" "lost a required setting"
grep -v USB4_APPLE_SOC "$good" > "$TMP/nousb4.config"
check config-usb4 1 kali -- build-kernel --check-config "$TMP/nousb4.config" -- "CONFIG CHECK FAILED: wanted CONFIG_USB4_APPLE_SOC=m"
sed 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-m3gpu"/' "$good" > "$TMP/lv.config"
check config-localversion 1 kali -- build-kernel --check-config "$TMP/lv.config" -- "CONFIG CHECK FAILED: LOCALVERSION"
check config-missing 1 kali -- build-kernel --check-config "$TMP/none.config" -- "no kernel config"
# An empty string setting may be absent (its dependency is off), but must not name a file.
grep -v SYSTEM_REVOCATION_KEYS "$good" > "$TMP/norev.config"
check config-absent-empty 0 kali -- build-kernel --check-config "$TMP/norev.config" -- "config check: 18 required settings"
sed 's/^CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS="certs\/revoked.pem"/' "$good" > "$TMP/rev.config"
check config-key-file 1 kali -- build-kernel --check-config "$TMP/rev.config" -- 'CONFIG CHECK FAILED: wanted CONFIG_SYSTEM_REVOCATION_KEYS=""'

# kernel/ must match the patches and config in agx-linux-kit, when the kit is next to this repo.
if [ -d "$HERE/../../agx-linux-kit/patches" ]; then
	expect "kernel/ matches agx-linux-kit" "$HERE/../tools/sync-kit-patches.sh" --check > /dev/null
else
	echo "skip kernel/ matches agx-linux-kit (no kit next to this repo)"
fi

echo "pass $pass, fail $fail"
[ "$fail" = 0 ]
