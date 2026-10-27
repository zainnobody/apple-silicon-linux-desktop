# macOS against Linux on the same Mac

Status (2026-10-27 13:20): memory and GPU compute are measured on both systems. The clean 600 s GPU compute run is in. llama.cpp way B is done: Linux writes text at 98 % of the public macOS figure and reads prompts at 53 % (63 % with a tuned tile). 7-Zip is measured on Linux only. llama.cpp is not measured in macOS yet.

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

### CPU memory read: same test on both systems

`tests/cpu-bw.c`, pthreads build, 1 GiB array, 5 runs.

- macOS: clang build of the old source, final macOS visit (2026-10-26 22:20 to 22:40). The old source sums with one add chain, but clang splits that chain into several chains. So the macOS values measure memory. They cannot be measured again with the new source, because the macOS visits are over.
- Linux: gcc 16.2.1 build of the new source with four add chains (agx-linux-kit commit `3fa1a67`). Run at 23:02 on the default boot.

| Threads | macOS best / mean (GB/s) | Linux best / mean (GB/s) | Linux as a share of macOS (mean) |
|---|---|---|---|
| 1, not pinned | 83.1 / 60.7 | 65.2 / 55.7 | 92 % |
| 6, not pinned | 125.1 / 121.0 | 107.6 / 105.8 | 87 % |
| 12 | 116.9 / 115.9 | 108.7 / 106.7 | 92 % |

More Linux runs with the new source:

| Run | Linux best / mean (GB/s) |
|---|---|
| 1 thread on P core 7 (this run) | 65.3 / 59.0 (97 % of the macOS mean) |
| 6 threads on the P cores (this run) | 117.5 / 96.8 |
| 1 thread on a P core (GPU session) | 60.2 / 52.0 |
| 6 threads on the P cores (GPU session) | 117.0 / 107.9 |
| 12 threads (GPU session) | 109.6 / 101.7 |

Other sessions were active during this run (load average 1.2). The means change by about 10 % from run to run.

**Correction.** An earlier version of this file said that one thread reads memory 3 times slower on Linux (20 GB/s). That was a fault in the test, not in Linux. gcc kept the old sum loop as one chain of dependent adds, and the add time limited one thread to about 20 GB/s.

**Remaining gap:** with one thread, the Linux mean is 3 to 14 % below macOS, depending on the run. The best value is about 20 % lower (65 against 83 GB/s).

The clock and the memory path of one core are not the limit. The GPU session ran several threads on one P core: it read 82.5 to 82.8 GB/s (mean) with the `schedutil` governor and with the `performance` governor (agx-linux-kit commit `7f52748`). That equals the macOS one-thread best (83.1 GB/s). So the gap comes from how one thread issues its reads. A true one-thread run with the `performance` governor was not done.

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

Do not read this as "Linux is 1.7 times faster". The two programs use different GPU paths: a compute kernel on macOS and a fragment shader on Linux.

**Same shader type (fair pair).** The GPU session wrote `tests/vk-stress.c`: the Metal kernel as a Vulkan compute shader, with the same math, 16x16 groups and checks (agx-linux-kit commits `de0203a` and `5ab61ed`).

| System | Program | Run | Frames/s | G pixel-iterations/s | Share of macOS | Wrong values |
|---|---|---|---|---|---|---|
| macOS | Metal compute | 0 to 450 s of a 600 s run | 316.9 | 132.9 | 100 % | 0 in 14,831 checks |
| Linux | Vulkan compute | 10 s, desktop idle | 250.0 | 104.9 | 79 % | 0 in 251 checks |
| Linux | Vulkan compute | 600 s, desktop in use: first 30 s | 201.7 | 84.6 | 64 % | 0 |
| Linux | Vulkan compute | 600 s, desktop in use: 30 to 600 s | 104.9 | 44.0 | 33 % | 0 in 6,587 checks (whole run) |
| Linux | Vulkan compute | 600 s, desktop idle, no other GPU program: first 30 s | 233.0 | 97.7 | 74 % | 0 |
| Linux | Vulkan compute | 600 s, desktop idle, no other GPU program: whole run | 113.2 | 47.5 | 36 % | 0 in 6,790 checks |

**Result: with the same test pattern, Linux gives 74 to 79 % of the macOS speed for the first 30 s, and 36 % over 600 s.** The clean 600 s run (2026-10-27 00:35, GPU session) had no other GPU program and an idle desktop. The speed still dropped after 30 s, from 233 to about 105 frames/s. So other programs did not cause the drop.

**Cause: the GPU clock, not the GPU speed.** The test stops the GPU on every 10th frame and checks 21,904 values on the CPU (17 to 27 ms). Between these bursts, the firmware lowers the GPU clock to 338 to 796 MHz instead of 1380 MHz. The driver gives the firmware the same clock controller values that macOS gives. With no stop (`VK_STRESS_CHECK_EVERY=0`, 60 s), Linux computes 255.5 G, and the GPU stays at 1380 MHz (agx-linux-kit commit `956cbf0`, `docs/performance.md`, "What limits this test").

Do not read 255.5 G as "Linux is 1.9 times faster". macOS ran only the version with stops. A fair peak comparison needs `metal-stress` with no checks in macOS, and that needs a macOS boot. What the data shows: the GPU hardware is not the limit on Linux. Under a stop-and-go load, the Linux clock control keeps the GPU slower than macOS does. A test boot with `asahi.g15_idle_standby_us=100000` (GPU session, stage M) can change this.

During the clean run, one failed suspend try happened (00:38:59). The speed was the same before and after it. The full log is in the GPU session; agx-linux-kit does not have it yet.

**History of this figure.** A first version of this file said one third of the macOS speed, from the 600 s run with the desktop in use. A second version called that wrong and gave 79 %, from the 10 s run, because it blamed the other GPU programs for the drop. The clean run of 2026-10-27 shows that both figures are correct for their run length: about 75 % for short runs and about one third for 600 s runs. The other programs did not cause the drop. The GPU clock state did. The desktop GPU fault at 23:22:53 came after the drop (23:22:08), so it did not cause the drop either.

The macOS run slowed down after 450 s (19.7 frames/s from 450 s to 740 s), probably because other macOS tests ran at that time. Its full-run average of 84.0 G is not used.

### 7-Zip benchmark (Linux only)

`7z b`, 7-Zip 26.04, 2026-10-26 23:32, on the M3 in Linux (agx-linux-kit commit `eef73e1`). There is no macOS value, because the macOS visits are over.

| Threads | Compress (MIPS) | Decompress (MIPS) | Total rating (MIPS) |
|---|---|---|---|
| All 12 | 90,284 | 51,495 | 70,889 |
| 1 | 9,321 | 6,463 | 7,892 |

### llama.cpp

| Model | macOS, Metal | Linux, Vulkan (22:49) | Linux, CPU (22:49) |
|---|---|---|---|
| Llama 3.2 3B Q4_K_M, pp512 / tg128 (tokens/s) | Not measured | 357.37 / 47.90 | 170.59 / 55.88 |
| Llama 3.1 8B Q4_K_M, pp512 / tg128 (tokens/s) | Not measured | 149.97 / 22.72 | 71.40 / 24.50 |

Public reference (not this Mac, not this model): the llama.cpp Apple silicon table lists the M3 Pro with 18 GPU cores at 341.67 / 30.74 tokens/s for Llama 2 7B Q4_0 with Metal (llama.cpp build `8e672ef`, November 2023). Llama 2 7B Q4_0 is 3.56 GiB, and our 8B Q4_K_M is 4.58 GiB. Token generation scales roughly with the model size, so macOS would give about 24 tokens/s for our 8B. Our Linux GPU gives 22.7. Prompt processing on Linux is probably about half the macOS speed. These are estimates, not measurements.

Rerun after the combined reboot (2026-10-27 07:34, GPU session, flash attention Mesa, `-fa 1`): 8B 150.13 / 22.69, 3B 357.65 / 47.60 tokens/s. This is the same as 22:49 within 1 %.

#### Way B: the public reference model (2026-10-27 13:06)

Llama 2 7B Q4_0 (`Llama-2-7B-Q4_0.gguf`, SHA-256 checked), `llama-bench -p 512 -n 128 -ngl 99 -fa 0`, 5 repetitions, llama.cpp `63b4b303b`, kernel `7.2.11-m3gpu+`, Mesa in `/opt/mesa-m3`, charger in (battery Full), nothing else on the GPU. The coordinator session ran it with the commands from this session. Results: `~/llm-work/results/wayb-20261027-1306/` on the M3.

| System | pp512 (tokens/s) | tg128 (tokens/s) | pp512 share of macOS | tg128 share of macOS |
|---|---|---|---|---|
| macOS, Metal (public table: M3 Pro 18-core GPU, llama.cpp `8e672ef`, November 2023) | 341.67 | 30.74 | 100 % | 100 % |
| Linux, Vulkan, default settings | 181.21 ± 0.04 | 30.02 ± 0.05 | 53.0 % | 97.7 % |
| Linux, Vulkan, tuned matrix tile (test switch) | 215.29 ± 0.07 | 29.98 ± 0.04 | 63.0 % | 97.5 % |
| Linux, CPU, 6 threads | 110.87 ± 0.45 | 31.36 ± 0.03 | 32.4 % | 102.0 % |

- **Token generation (writing text): Linux equals macOS.** 30.0 against 30.7 tokens/s. Memory speed limits this part, and the memory floor patch brought Linux to the macOS level.
- **Prompt processing (reading text): Linux gives about half.** 181 against 342 tokens/s. GPU matrix math limits this part. The Linux Vulkan path is slower than Metal here.
- **Tuned tile: 19 % faster prompts** (215 against 181). The GPU session found the tile. It is a test switch (`GGML_VK_HK_MWARP=128,128,64,16,64,32,2,4,4,1,32`) in a local change to `ggml-vulkan.cpp`, not in upstream llama.cpp. With no switch set, the local build runs like upstream `63b4b303b`, so the default row is an upstream result.
- The CPU writes text a little faster than the GPU (31.4 against 30.0), as with the 8B model.
- Both earlier estimates hold: prompts at about half of macOS, writing close to macOS.
- Limits of this pair: the macOS row is a different M3 Pro and a 2023 llama.cpp. The model file is a newer conversion (3.53 GiB against 3.56 GiB in the table). Metal in llama.cpp is faster today, so the real prompt gap can be larger.
- The run's boot (12:42 to 13:10) has no GPU fault lines in the kernel log after 13:05. It ended with a normal shutdown for the next reboot window.

## 4. What is still missing

| Test | Why it is missing |
|---|---|
| llama.cpp with Metal on the same models, on this Mac | macOS on the M3 has no developer tools, so it cannot build llama.cpp. Way B (section 3) gives a close pair from the public table. |
| 7-Zip benchmark in macOS | The macOS visits are over. Linux has a value (section 3). |
| GPU compute with no checks in macOS (`metal-stress`, no stops) | Needs a macOS boot. It gives the fair peak pair for the Linux 255.5 G. |
| GPU memory read in macOS | Needs a Metal version of `vk-bandwidth` |

The user said the macOS visit at 22:20 was probably the last one. macOS has about 26 GB free.

Two ways to measure llama.cpp:

| Way | What it needs | Result |
|---|---|---|
| A. One more macOS boot | Build llama.cpp (same commit, Metal) and `7zz` on the M5 host. Copy them and one model at a time over the local link. Two restarts, about 30 minutes. | Exact: same Mac, same models, same llama.cpp commit |
| B. No macOS boot | Download the reference model (`ggml-org/Llama-2-7B-GGUF`, file `Llama-2-7B-Q4_0.gguf`, 3,792,015,872 bytes, SHA-256 starts `5b929e9c`, Llama 2 Community License) to `/data/models` on Linux. Run `llama-bench -p 512 -n 128 -ngl 99`. | Close: same model and settings as the public M3 Pro table, but a different Mac and an older macOS llama.cpp |

Way B ran on 2026-10-27 at 13:06 (results in section 3). The file is 3.53 GiB. The public table lists 3.56 GiB, so it is a newer conversion of the same model, not the same file.

Way A is exact. Way B needs no restart, but the public table uses a llama.cpp build from 2023. Metal in llama.cpp is faster today, so the real gap can be larger than way B shows.

## 5. Rules for a fair result

- Same source commit and same build options on both systems.
- Same model files. Compare the SHA-256 values in `~/llm-work/results/models.sha256`.
- Mac on power, lid open, nothing else running.
- Three runs for each test. Report the median.
- macOS stays offline.

## Sources

- macOS logs: `private-dumps/macos-final-2026-10-27/` on the host (`cpu-bw.log`, `metal-600s.log`, `macos-tests.log`). Private folder, never shared.
- The same macOS numbers in `agx-linux-kit/docs/performance.md` (agx-linux-kit commit `c0e917a`). That file still lists the Linux one-thread value as "not measured". The value is in section 3 above.
- Linux: `STATUS.md` (22:49 run) and the four-chain `cpu-bw` runs at 23:02 (source SHA-256 starts `d212af6c`)
- [llama.cpp: Performance of llama.cpp on Apple Silicon M-series](https://github.com/ggml-org/llama.cpp/discussions/4167)
