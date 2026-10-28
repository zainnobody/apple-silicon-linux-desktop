# Status: newest verified results on the reference Mac

Reference Mac: MacBook Pro 16-inch M3 Pro (Mac15,7, J516S, SoC T6030, chip revision B1), 18 GB, Fedora Asahi Remix 44.

Stack: kernel `7.2.11-m3gpu+` (SiliconForest `0e1f466` plus our patches), m1n1 `aca1258`, Mesa 26.3.0-devel (SiliconForest `7515336`) in `/opt/mesa-m3`.

Last update: 2026-10-28 02:45 (M3 time, PDT). Times below are PDT on 2026-10-26, unless a row says 2026-10-27.

## 1. Full check on the default boot (22:49 to 22:52)

The M3 started at 22:44 from the default boot entry, after the partition work. The tests ran in the user shell, one after another, with no other GPU work on the Mac. Script: `~/distro-pack-check/run.sh` on the M3. Log: `~/distro-pack-check/20261026-2249/run.log`.

| Test | Result |
|---|---|
| Kernel, GPU | `7.2.11-m3gpu+`, "Apple M3 Pro (G15S B1)", Vulkan 1.4.363, Mesa 26.3.0-devel (git-7515336b3d) |
| Readback test | 3 of 3 pass |
| Vulkan compute, small | 65,536 values, 1 dispatch, 0 wrong |
| Vulkan compute, large | 16,777,216 values, 50 dispatches, 0 wrong |
| Memory, P cores (6 threads) | 126.2 GB/s mean, 127.0 best |
| Memory, E cores (6 threads) | 65.1 GB/s mean |
| Memory, all 12 cores | 108.6 GB/s mean, 113.7 best |
| Memory, GPU | 131.4 GB/s mean, 134.1 best |
| P cores and GPU at the same time | 123.6 + 131.7 GB/s |
| P cores and E cores at the same time | 64.5 + 56.4 GB/s |
| Same text on GPU and CPU (3B, temperature 0, `-c 2048`) | `CHECK_SAME` |
| Kernel log of this boot | 0 lines with a GPU fault, refused submit, firmware halt or out-of-memory event |
| Lowest available memory during the run | 6.2 GB of 18 GB |
| Temperatures at the end (thermal zones 0 to 2) | 25.9, 64.2, 73.5 C |

### llama.cpp (22:49)

llama.cpp `63b4b303`, `llama-bench -p 512 -n 128 -r 3`, bartowski GGUF, Q4_K_M. GPU: Vulkan, `-ngl 99 -fa 0`, installed Mesa. CPU: CPU-only build, 6 threads. Results: `~/llm-work/results/bench-20261026-2249/`. No failed GPU submits.

| Model | Backend | pp512 (tokens/s) | tg128 (tokens/s) |
|---|---|---|---|
| Llama 3.2 3B | GPU | 357.37 ± 0.31 | 47.90 ± 0.37 |
| Llama 3.2 3B | CPU | 170.59 ± 0.28 | 55.88 ± 0.04 |
| Llama 3.1 8B | GPU | 149.97 ± 0.03 | 22.72 ± 0.06 |
| Llama 3.1 8B | CPU | 71.40 ± 0.59 | 24.50 ± 0.87 |

All numbers are within 3% of the 20:43 run on an earlier boot. So the memory floor and the GPU speed stay the same from boot to boot.

The coordinator session's health check on the 21:59 boot gave the same memory speeds: P cores 126.4 GB/s mean, GPU 131.7 GB/s mean.

## 2. GPU correctness and stability (earlier boots)

| Test | Result | Time |
|---|---|---|
| Readback test | 3 of 3 runs, then 20 of 20 runs pass. 0 of 4096 pixels wrong. | 13:06, 13:57 |
| Shader stress, 600 s | 543.7 frames/s, 228.0 G pixel-iterations/s, 0 wrong values in 32,621 checks | 13:47 |
| Idle soak, 60 min | Pass. Readback 3 of 3 after it. 0 kernel GPU or display problems. | 13:57 to 14:57 |
| Load soak, 60 min | 228.17 G pixel-iterations/s for the full hour, 0 wrong values in 195,843 checks | 14:57 to 15:57 |
| glmark2-es2-wayland, 1280x800 (partial run) | 3,266 to 3,562 FPS on the texture and shading scenes, no GPU errors | 13:41 |
| Vulkan compute stress (`tests/vk-stress.c`), 10 s, desktop idle | Pass: 0 wrong values in 251 checks. 104.9 G pixel-iterations/s (79 % of macOS Metal). | Before 23:21 |
| Vulkan compute stress, 600 s, desktop in use | Pass: 0 wrong values in 6,587 checks. 46.0 G pixel-iterations/s: the speed dropped at 30 s while other programs used the GPU. Not a speed reference. | 23:21 to 23:31 |
| **GPU fault** during that run | A desktop render job (plasmashell) read an unmapped GPU address at 23:22:53. The kernel recovered. Then Mesa crashed in `agx_batch_init` instead of reporting a lost context, so the desktop shell died. The first GPU fault in 8 GPU boots. The GPU session owns the fix. | 23:22 |
| Vulkan compute stress, 600 s, desktop idle, no other GPU program (2026-10-27, GPU session) | Pass: 0 wrong values in 6,790 checks. 113.2 frames/s, 47.5 G pixel-iterations/s. 233 frames/s for the first 30 s, then about 105. The cause is the GPU clock state between the CPU checks (see `COMPARE.md`). | 00:35 to 00:45 |
| GPU suite, desktop idle (2026-10-27, agx-linux-kit commit `956cbf0`) | Vulkan compute with no stops: 255.5 G. Fragment shader: 226.1 G, 0 wrong. GPU memory read: 133.6 best, 126.6 mean GB/s. `glmark2-wayland` 1920x1080 window: score 3192. 0 kernel GPU faults. | 00:12 |

## 3. Memory: before and after the floor patch

| Reader | Before the patch (GB/s) | With the patch, 22:49 (GB/s) | macOS, same Mac (GB/s) |
|---|---|---|---|
| P cores, 6 threads | 32.4 | 126.2 | 6 threads, not pinned: 121.0 mean |
| E cores, 6 threads | 29.8 | 65.1 | Not measured |
| All 12 cores | 32.2 | 108.6 | 115.9 mean, 116.9 best |
| GPU | 31.1 | 131.4 | Not measured |

macOS values: final macOS visit, 22:20 to 22:40. The fair comparison with the same test on both systems is in `COMPARE.md`. With the corrected test (four add chains, 23:02), one thread reads 55.7 GB/s (mean) on Linux and 60.7 GB/s in macOS.

The "with the patch" column comes from `tests/mem-shared.sh` with the OpenMP build of the old `cpu-bw.c`. In that build each thread has its own add chain, so the one-chain fault did not affect it. The GPU session ran it again with the four-chain OpenMP build (agx-linux-kit commit `d48bc6c`): P cores 125.1, E cores 64.6, all 12 cores 110.8, GPU 129.9 GB/s (mean). These values match, so the column stays valid. The pthreads build gives lower 6-thread means (96.8 to 107.9 GB/s).

## 4. llama.cpp history

| Run | 8B GPU pp512 / tg128 | 8B CPU pp512 / tg128 | Note |
|---|---|---|---|
| Afternoon, before the floor patch | 124.97 / 5.76 | 66.58 / 6.59 | Memory at about 32 GB/s |
| 20:43 | 149.89 / 22.66 | 70.59 / 25.07 | First boot with the floor patch |
| 21:30, `-fa 1` | 150.07 / 22.78 | n/a | Mesa build folder with the flash attention patch |
| 22:49 | 149.97 / 22.72 | 71.40 / 24.50 | Default boot |
| 2026-10-27 07:34, `-fa 0` | 149.98 / 22.79 | n/a | After the combined reboot. Installed Mesa with the flash attention fix (GPU session) |
| 2026-10-27 07:34, `-fa 1` | 150.13 / 22.69 | n/a | Same run |

- `test-backend-ops -o FLASH_ATTN_EXT`: 5368 of 5368 pass on the GPU (21:30).
- Since the combined reboot (2026-10-27), `/opt/mesa-m3` has the flash attention fix: its `libvulkan_asahi.so` has the same SHA-256 as the patched build in `~/m3gpu/build-mesa`. `-fa 1` and `-fa 0` give the same speed within 1 %.
- 3B at 07:34: pp512 / tg128 357.65 / 47.60 (`-fa 1`), 357.11 / 47.97 (`-fa 0`) tokens/s.
- Text check at 07:34 (`results/fa-20261027-0734/textcheck`): the old and the new Mesa give the same text on 4 of 4 checks. GPU and CPU give the same text on 3 of 4. The 8B gives a different text on GPU and CPU for prompt 1 ("Paris, which is..." on the CPU, "a city of grandeur..." on the GPU). The 22:49 check used the 3B and gave the same text.
- The GPU is 2.1 times faster than the CPU for prompts (8B). For token generation, the CPU is still a little faster (24.5 against 22.7 tokens/s).

### Llama 2 7B Q4_0 against the public M3 Pro table (way B, 2026-10-27 13:06)

`llama-bench -p 512 -n 128 -ngl 99 -fa 0`, llama.cpp `63b4b303b`, charger in. Public macOS Metal figure: 341.67 / 30.74 tokens/s.

| Backend | pp512 (tokens/s) | tg128 (tokens/s) |
|---|---|---|
| Vulkan, default | 181.21 ± 0.04 (53 %) | 30.02 ± 0.05 (98 %) |
| Vulkan, tuned tile (test switch) | 215.29 ± 0.07 (63 %) | 29.98 ± 0.04 (98 %) |
| CPU, 6 threads | 110.87 ± 0.45 | 31.36 ± 0.03 |

Details and limits of this pair: `COMPARE.md`, section 3.

## 5. CPU: 7-Zip

`7z b`, 7-Zip 26.04, 23:32 (agx-linux-kit commit `eef73e1`).

| Threads | Compress (MIPS) | Decompress (MIPS) | Total rating (MIPS) |
|---|---|---|---|
| All 12 | 90,284 | 51,495 | 70,889 |
| 1 | 9,321 | 6,463 | 7,892 |

## 6. Kernel package build (2026-10-28, first real build and stripped rebuild)

`agx build-kernel --build --family fedora` on the M3 (distro-pack `ec37120`), as a normal user, `nice -n 19`, idle IO, in `/data/work/agx-build`, charger in. Nothing was installed. Log: `/data/work/agx-build/build.log` on the M3.

| Item | Result |
|---|---|
| Patch check on the real kernel clone | All 4 patches apply on `0e1f46661376` |
| Build time | 01:49:42 to 02:30:43, 2,461 s (41 min), exit 0 |
| `kernel-7.2.11_agx-1.fc44.aarch64.rpm` | 1,318,309,522 bytes, SHA-256 `37d2d3abfa2cabb91055397972b61a6a9ac0eb85eb209c3711d0196d66090d18` |
| `kernel-devel-7.2.11_agx-1.fc44.aarch64.rpm` | 10,506,762 bytes, SHA-256 `0dbc067a5c7e520b8f5c862c6fa24dcecf523a08dc097f1c34b623ac8e855f77` (not used) |
| `kernel-headers-7.2.11_agx-1.fc44.aarch64.rpm` | 1,641,227 bytes, SHA-256 `85fa7325209b532b76b703ff2a7022f58c2ecb8a748a2687703980be0aa625ff` (never install: it belongs to the C library) |
| Contents | 10,175 files, 5,645 modules. `vmlinuz`, `dtb/apple/t6030-j516s.dtb`, `thunderbolt_apple.ko`, `hci_bcm4377.ko`, `macsmc-hwmon.ko` |
| Kernel image | `vmlinuz` is an EFI zboot PE file (`CONFIG_EFI_ZBOOT=y`), the same format as the stock Fedora Asahi kernels. The raw `Image` of the build has the recovery fix (4 "recovery step" strings) and the `g15_perf_tgt_util` parameter. The running M3 kernel boots from a raw `Image` that the kit copied by hand. |
| Config | Equal to the installed `7.2.11-m3gpu+` config except `CONFIG_LOCALVERSION` |
| Package scripts | `%post` runs `kernel-install add`, copies `vmlinuz`, `System.map`, `config` and the DTBs to `/boot`, and runs `depmod` |
| **Fault: module size** | The modules are not stripped and not compressed: 7.4 GB unpacked. `hci_bcm4377.ko` is 1,064,584 bytes, against 83,624 bytes in the running kernel. |

Cause of the module size: the config has `CONFIG_MODULE_COMPRESS=y` (xz) without `MODULE_COMPRESS_ALL`. The kernel's spec generator then turns off both debuginfo modes (the debuginfo tool needs uncompressed modules), and the spec defines `install_mod_strip` only in its manual debuginfo block. So nothing stripped the modules. bindeb-pkg and pacman-pkg always strip. Fix (distro-pack `1311abb`): the Fedora backend passes `RPMOPTS=--define='install_mod_strip 1'`.

### Stripped rebuild (02:37 to 02:55)

The same command and rules, with distro-pack `e443ed3` (it has `1311abb`). Log: `/data/work/agx-build/build.log` on the M3; the first build's log is now `build-try3.log`. Nothing was installed.

| Item | Result |
|---|---|
| Build time | 02:37:05 to 02:54:45, 1,060 s (18 min), exit 0. The first build also packed 7.4 GB of modules; the cause of the shorter time is not measured. |
| `kernel-7.2.11_agx-1.fc44.aarch64.rpm` | 95,451,458 bytes, SHA-256 `e82119093c0892bfbb44c5927c68e65b105094479818c512fd11f609fef31a4e`. Installed size 537,075,840 bytes. |
| `kernel-devel-7.2.11_agx-1.fc44.aarch64.rpm` | 10,505,401 bytes, SHA-256 `7acc79ae8fe8a48130863dba0c2d3ed6f5a3cdf7662f9bb8053b3880a387dfa8` (not used) |
| `kernel-headers-7.2.11_agx-1.fc44.aarch64.rpm` | 1,641,227 bytes, SHA-256 `042188f988620b1e1f528c8e2148dd09da211648c57a310904db0647f6a5e395` (never install) |
| Contents | 10,175 files, 5,645 modules, with the same files as the first build checks above |
| Kernel image | `vmlinuz` (SHA-256 `4fa6b4ee3f52d7287cce19d6e138ab2e20b55549bf06904851a7cf36434f106e`) is the build tree's `vmlinuz.efi`. The tree's raw `Image` has 4 "recovery step" strings and 1 `tgt_util` string. |
| Module stripping | 0 of 5,645 `.ko` files have a `debug_info` section. All 5,645 are also in the running `7.2.11-m3gpu+` `kernel/` tree: 402,936,528 bytes in the package, 403,515,488 bytes running. 5,644 are within 1 % in size; `cypress_firmware.ko` differs by 96 bytes. `hci_bcm4377.ko`: 83,528 bytes, against 83,624 bytes running. |
| Config | Equal to the installed config except `CONFIG_LOCALVERSION` |

The running kernel also has test modules outside `kernel/` (`touchid-test/apple-sep*.ko`, `ftst-test/` and `updates/macsmc-hwmon.ko`, `ane-test/ane_t6030_probe.ko`). They are not part of the package.

After these checks, the first build's three unstripped RPMs (the hashes in the first table) and their `kernel-release` file were removed from the M3. The stripped packages are in `/data/work/agx-build/out/packages` and `kbuild/linux/rpmbuild/RPMS/aarch64`.

Two early stops before this build, both fixed: the config check rejected the absent `SYSTEM_REVOCATION_KEYS` (its dependency is off; `57a3710`), and rpmbuild wanted `elfutils-devel`, which this config does not use (`ec37120`, build run with `AGX_RPM_NODEPS=1`).

## 7. Open items that can change these numbers

- Run `metal-stress` with no checks in macOS, for a fair peak GPU compute pair (needs a macOS boot).
- Test boot with `asahi.g15_idle_standby_us=100000` (GPU session, stage M): it can change the GPU clock under stop-and-go loads.
- Fix the GPU render fault and the Mesa crash after a lost context (GPU session).
- Install the flash attention patch in `/opt/mesa-m3`.
- Run the full desktop glmark2 test (needs a desktop login).
- Run the same tests in macOS (see `COMPARE.md`).

## Sources

- Run of 22:49 on the M3: `~/distro-pack-check/20261026-2249/run.log` and `~/llm-work/results/bench-20261026-2249/`
- `agx-linux-kit/docs/performance.md` (agx-linux-kit commit `643891f`)
- `ane-linux/docs/llm-baseline.md` (ane-linux commit `083e8e9`)
- Way B on the M3: `~/llm-work/results/wayb-20261027-1306/` (`system.txt`, `vulkan.md`, `vulkan-tiles.md`, `cpu.md`) and `/data/models/download.log` (checksum OK)
- `agx-linux-kit/log/overview.html` (run order and stage results)
- The coordinator session's health check of the 21:59 boot
