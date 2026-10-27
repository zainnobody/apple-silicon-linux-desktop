# Status: newest verified results on the reference Mac

Reference Mac: MacBook Pro 16-inch M3 Pro (Mac15,7, J516S, SoC T6030, chip revision B1), 18 GB, Fedora Asahi Remix 44.

Stack: kernel `7.2.11-m3gpu+` (SiliconForest `0e1f466` plus our patches), m1n1 `aca1258`, Mesa 26.3.0-devel (SiliconForest `7515336`) in `/opt/mesa-m3`.

Last update: 2026-10-26 22:10 (M3 time, PDT). All times below are PDT on 2026-10-26.

## 1. Check on the new default boot (22:09, read only)

At 21:59 the M3 started from the GPU kernel as the default boot for the first time (stage K). These checks read state only. They put no load on the GPU.

| Item | Result | How it was read |
|---|---|---|
| Kernel | `7.2.11-m3gpu+` | `uname -r` |
| OpenGL | 4.6 core profile, renderer "Apple M3 Pro (G15S B1)" | `eglinfo -B -p surfaceless` with the native Mesa |
| OpenGL ES | 3.2 | Same |
| Vulkan | 1.4.363, driver Honeykrisp, Mesa 26.3.0-devel (git-7515336b3d) | `vulkaninfo --summary` with `VK_DRIVER_FILES` set to the native driver |
| GPU render node | `/dev/dri/renderD128` is present | `ls /dev/dri` |
| Memory floor | Accepted on the first try: DVFS state `0x30200 -> 0x32204` | Kernel log of this boot |
| Stage L modules | `thunderbolt_apple.ko` and `hci_bcm4377.ko` are installed | `modinfo` |

Not run again on this boot yet: the readback test, the memory bandwidth test and llama.cpp. They wait for the coordinator session's health check, because other sessions also test on the M3.

## 2. GPU correctness and stability (earlier boots)

| Test | Result | Time |
|---|---|---|
| Readback test | 3 of 3 runs, then 20 of 20 runs pass. 0 of 4096 pixels wrong. | 13:06, 13:57 |
| Shader stress, 600 s | 543.7 frames/s, 228.0 G pixel-iterations/s, 0 wrong values in 32,621 checks | 13:47 |
| Idle soak, 60 min | Pass. Readback 3 of 3 after it. 0 kernel GPU or display problems. | 13:57 to 14:57 |
| Load soak, 60 min | 228.17 G pixel-iterations/s for the full hour, 0 wrong values in 195,843 checks | 14:57 to 15:57 |
| glmark2-es2-wayland, 1280x800 (partial run) | 3,266 to 3,562 FPS on the texture and shading scenes, no GPU errors | 13:41 |
| Vulkan compute (`tests/vk-compute.c`) | 50 dispatches over 16,777,216 values, 0 wrong | Afternoon |

## 3. Memory bandwidth (`tests/mem-shared.sh`, 20:42 boot)

| Reader | Before the floor patch (GB/s) | With the floor patch (GB/s) |
|---|---|---|
| P cores, 6 threads | 32.4 | 123.5 (best 127.1) |
| E cores, 6 threads | 29.8 | 65.1 |
| All 12 cores | 32.2 | 109.7 |
| GPU | 31.1 | 130.1 (best 133.6) |
| P cores and GPU at the same time | 19.0 + 17.8 | 123.2 + 131.2 |

Reference: macOS on the same Mac reads 115.3 GB/s (best, 12 threads).

## 4. llama.cpp

llama.cpp `63b4b303`, `llama-bench -p 512 -n 128 -r 3`, bartowski GGUF models, Q4_K_M. GPU runs use Vulkan with `-ngl 99` on the native Mesa. CPU runs use a CPU-only build with 6 threads.

| Model | Backend | Mesa | pp512 (tokens/s) | tg128 (tokens/s) | Time |
|---|---|---|---|---|---|
| Llama 3.2 3B | GPU, `-fa 0` | Installed (`/opt/mesa-m3`) | 356.30 | 48.06 | 20:43 |
| Llama 3.2 3B | CPU | n/a | 169.02 | 55.74 | 20:43 |
| Llama 3.1 8B | GPU, `-fa 0` | Installed | 149.89 | 22.66 | 20:43 |
| Llama 3.1 8B | CPU | n/a | 70.59 | 25.07 | 20:43 |
| Llama 3.2 3B | GPU, `-fa 1` | Build folder with the flash attention patch | 357.06 | 47.44 | 21:30 |
| Llama 3.1 8B | GPU, `-fa 1` | Build folder with the flash attention patch | 150.07 | 22.78 | 21:30 |

- GPU and CPU give the same text for the same prompt at temperature 0 (`CHECK_SAME`).
- `test-backend-ops -o FLASH_ATTN_EXT`: 5368 of 5368 pass on the GPU.
- The installed Mesa does not have the flash attention patch yet. Use `-fa 0` with it.
- The GPU is 2.1 times faster than the CPU for prompts (8B). The CPU is still a little faster for token generation (25.1 against 22.7 tokens/s).
- Before the memory floor patch, the 8B model made 5.8 tokens/s on the GPU.

## 5. Open items that can change these numbers

- Run the readback test, the memory test and llama.cpp again on the default boot.
- Install the flash attention patch in `/opt/mesa-m3`.
- Run the full desktop glmark2 test (needs a desktop login).
- Run the same tests in macOS with Metal for a fair comparison.

## Sources

- `agx-linux-kit/docs/performance.md` (agx-linux-kit commit `643891f`)
- `ane-linux/docs/llm-baseline.md` (ane-linux commit `083e8e9`)
- `agx-linux-kit/log/overview.html` (run order and stage results)
- Read-only commands on the M3 at 22:09
