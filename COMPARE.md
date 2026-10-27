# macOS against Linux on the same Mac

Status (2026-10-26 23:00): memory and GPU compute are measured on both systems. llama.cpp and 7-Zip are not measured in macOS yet.

## 1. Why the same Mac

The hardware stays the same, so only the software changes. macOS is the target: it shows what the chip gives with Apple's own drivers. A different Mac or a virtual machine changes the hardware, so its numbers do not compare fairly.

## 2. Which systems to compare

| System | What it shows |
|---|---|
| macOS 15.6.1, Metal | The target: the chip with Apple's drivers |
| Fedora with our stack (`7.2.11-m3gpu+`, native Mesa, memory floor) | What distro-pack gives |
| Fedora with the stock Asahi kernel (`7.1.13`, in the GRUB menu) | What every M3 user gets today without the pack: no GPU, slow memory |

The distro does not change these numbers. Ubuntu or Kali with the same kernel and Mesa give the same results as Fedora. So one Linux system with our stack is enough. The stock kernel is the right Linux baseline.

## 3. Results

### CPU memory read: same program on both systems

`tests/cpu-bw.c`, pthreads build, 1 GiB array, 5 runs, threads not pinned. macOS: final macOS visit, 2026-10-26 22:20 to 22:40. Linux: 2026-10-26 22:54, default boot.

| Threads | macOS best / mean (GB/s) | Linux best / mean (GB/s) | Linux as a share of macOS (mean) |
|---|---|---|---|
| 1 | 83.1 / 60.7 | 20.2 / 20.1 | 33 % |
| 6 | 125.1 / 121.0 | 97.4 / 97.0 | 80 % |
| 12 | 116.9 / 115.9 | 109.3 / 107.1 | 92 % |

Extra Linux runs (same program): one thread on a P core 18.7 mean, one thread on an E core 15.0 mean, six threads on the P cores 105.7 mean.

**Finding: one thread reads memory 3 times slower on Linux.** Pinning the thread to a P core does not help. Many threads together almost reach macOS, because the memory floor raised the shared limit. The cause of the one-thread limit is not known yet. Candidates: no per-cluster memory performance vote from the CPU frequency driver, or different hardware prefetch settings than macOS uses.

Before the memory floor patch, Linux read about 32 GB/s with 6 or 12 threads.

### GPU memory read

| macOS | Linux |
|---|---|
| Not measured. A Metal version of the test does not exist yet. | 131.4 GB/s mean (`tests/vk-bandwidth.c`) |

### GPU compute: same math, different shader type

Each pixel of 1024x1024 runs 400 xorshift steps. Every 10th frame is checked against the CPU.

| System | Program | Frames/s | G pixel-iterations/s | Wrong values |
|---|---|---|---|---|
| macOS | `tests/metal-stress.swift` (compute kernel), steady part 0 to 450 s | 316.9 | 132.9 | 0 in 14,831 checks |
| Linux | `tests/gles-stress.c` (fragment shader), 600 s | 543.7 | 228.0 | 0 in 32,621 checks |

Do not read this as "Linux is 1.7 times faster". The two programs use different GPU paths: a compute kernel on macOS and a fragment shader on Linux. A fair pair needs the same shader type on both. The macOS run also slowed down after 450 s (19.7 frames/s from 450 s to 740 s), probably because other macOS tests ran at that time. The full-run average of 84.0 G is therefore not used.

### llama.cpp

| Model | macOS, Metal | Linux, Vulkan (22:49) | Linux, CPU (22:49) |
|---|---|---|---|
| Llama 3.2 3B Q4_K_M, pp512 / tg128 (tokens/s) | Not measured | 357.37 / 47.90 | 170.59 / 55.88 |
| Llama 3.1 8B Q4_K_M, pp512 / tg128 (tokens/s) | Not measured | 149.97 / 22.72 | 71.40 / 24.50 |

Public reference (not this Mac, not this model): the llama.cpp Apple silicon table lists the M3 Pro with 18 GPU cores at 341.67 / 30.74 tokens/s for Llama 2 7B Q4_0 with Metal (llama.cpp build `8e672ef`, November 2023). Llama 2 7B Q4_0 is 3.56 GiB, and our 8B Q4_K_M is 4.58 GiB. Token generation scales roughly with the model size, so macOS would give about 24 tokens/s for our 8B. Our Linux GPU gives 22.7. Prompt processing on Linux is probably about half the macOS speed. These are estimates, not measurements.

## 4. What is still missing

| Test | Why it is missing |
|---|---|
| llama.cpp with Metal on the same models | macOS on the M3 has no developer tools, so it cannot build llama.cpp. |
| 7-Zip benchmark (`7zz b`) | Not run on either system |
| Same shader type for GPU compute | Needs a Vulkan compute version of the xorshift test on Linux, or a fragment version on macOS |
| GPU memory read in macOS | Needs a Metal version of `vk-bandwidth` |

The user said the macOS visit at 22:20 was probably the last one. macOS has about 26 GB free.

Two ways to measure llama.cpp:

| Way | What it needs | Result |
|---|---|---|
| A. One more macOS boot | Build llama.cpp (same commit, Metal) and `7zz` on the M5 host. Copy them and one model at a time over the local link. Two restarts, about 30 minutes. | Exact: same Mac, same models, same llama.cpp commit |
| B. No macOS boot | Download the reference model (`ggml-org/Llama-2-7B-GGUF`, Q4_0, about 3.8 GB) to `/data/models` on Linux. Run `llama-bench -p 512 -n 128 -ngl 99`. | Close: same model and settings as the public M3 Pro table, but a different Mac and an older macOS llama.cpp |

Way A is exact. Way B needs no restart, but the public table uses a llama.cpp build from 2023. Metal in llama.cpp is faster today, so the real gap can be larger than way B shows.

## 5. Rules for a fair result

- Same source commit and same build options on both systems.
- Same model files. Compare the SHA-256 values in `~/llm-work/results/models.sha256`.
- Mac on power, lid open, nothing else running.
- Three runs for each test. Report the median.
- macOS stays offline.

## Sources

- macOS logs: `private-dumps/macos-final-2026-10-27/` on the host (`cpu-bw.log`, `metal-600s.log`, `macos-tests.log`). Private folder, never shared.
- Linux: `STATUS.md` (22:49 run) and the `cpu-bw-pt` runs at 22:54
- [llama.cpp: Performance of llama.cpp on Apple Silicon M-series](https://github.com/ggml-org/llama.cpp/discussions/4167)
