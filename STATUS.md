# Status: newest verified results on the reference Mac

Reference Mac: MacBook Pro 16-inch M3 Pro (Mac15,7, J516S, SoC T6030, chip revision B1), 18 GB, Fedora Asahi Remix 44.

Stack: kernel `7.2.11-m3gpu+` (SiliconForest `0e1f466` plus our patches), m1n1 `aca1258`, Mesa 26.3.0-devel (SiliconForest `7515336`) in `/opt/mesa-m3`.

Last update: 2026-10-26 22:55 (M3 time, PDT). All times below are PDT on 2026-10-26.

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

## 3. Memory: before and after the floor patch

| Reader | Before the patch (GB/s) | With the patch, 22:49 (GB/s) | macOS, same Mac (GB/s) |
|---|---|---|---|
| P cores, 6 threads | 32.4 | 126.2 | Not pinned; 6 threads: 80.9 mean |
| E cores, 6 threads | 29.8 | 65.1 | Not measured |
| All 12 cores | 32.2 | 108.6 | 110.4 mean, 115.3 best |
| GPU | 31.1 | 131.4 | Not measured |

## 4. llama.cpp history

| Run | 8B GPU pp512 / tg128 | 8B CPU pp512 / tg128 | Note |
|---|---|---|---|
| Afternoon, before the floor patch | 124.97 / 5.76 | 66.58 / 6.59 | Memory at about 32 GB/s |
| 20:43 | 149.89 / 22.66 | 70.59 / 25.07 | First boot with the floor patch |
| 21:30, `-fa 1` | 150.07 / 22.78 | n/a | Mesa build folder with the flash attention patch |
| 22:49 | 149.97 / 22.72 | 71.40 / 24.50 | Default boot |

- `test-backend-ops -o FLASH_ATTN_EXT`: 5368 of 5368 pass on the GPU (21:30).
- The installed Mesa does not have the flash attention patch yet. Use `-fa 0` with it.
- The GPU is 2.1 times faster than the CPU for prompts (8B). For token generation, the CPU is still a little faster (24.5 against 22.7 tokens/s).

## 5. Open items that can change these numbers

- Install the flash attention patch in `/opt/mesa-m3`.
- Run the full desktop glmark2 test (needs a desktop login).
- Run the same tests in macOS (see `COMPARE.md`).

## Sources

- Run of 22:49 on the M3: `~/distro-pack-check/20261026-2249/run.log` and `~/llm-work/results/bench-20261026-2249/`
- `agx-linux-kit/docs/performance.md` (agx-linux-kit commit `643891f`)
- `ane-linux/docs/llm-baseline.md` (ane-linux commit `083e8e9`)
- `agx-linux-kit/log/overview.html` (run order and stage results)
- The coordinator session's health check of the 21:59 boot
