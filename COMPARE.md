# macOS against Linux on the same Mac

Status: plan (2026-10-26). The Linux side is measured. Most of the macOS side is not.

## 1. Why the same Mac

The hardware stays the same, so only the software changes. macOS with Metal is the target: it shows what the chip gives with Apple's own drivers. A different Mac or a virtual machine changes the hardware, so its numbers do not compare fairly.

## 2. Which systems to compare

| System | What it shows |
|---|---|
| macOS 15.6.1, Metal | The target: the chip with Apple's drivers |
| Fedora with our stack (`7.2.11-m3gpu+`, native Mesa, memory floor) | What distro-pack gives |
| Fedora with the stock Asahi kernel (`7.1.13`, in the GRUB menu) | What every M3 user gets today without the pack: no GPU, slow memory |

The distro does not change these numbers. Ubuntu or Kali with the same kernel and Mesa give the same results as Fedora. So one Linux system with our stack is enough for the comparison. The stock kernel is the right Linux baseline.

## 3. Tests

Each test uses the same source code or the same math on both systems.

| Area | Test | macOS | Linux |
|---|---|---|---|
| LLM, GPU | llama.cpp `llama-bench -p 512 -n 128 -r 3`, same commit, same GGUF files | Metal backend | Vulkan backend |
| LLM, CPU | Same, CPU-only build, 6 threads | CPU build | CPU build |
| GPU compute | Same xorshift math on 1024x1024, 600 s, every 10th frame checked | `tests/metal-stress.swift` | `tests/gles-stress.c` |
| CPU memory | `tests/cpu-bw.c` (same C source) | 1, 6 and 12 threads | 1, 6 and 12 threads, and P cores only |
| GPU memory | Large-buffer read shader | Metal version (to write) | `tests/vk-bandwidth.c` |
| CPU | 7-Zip benchmark (`7zz b`) | macOS arm64 build | Linux arm64 build |
| Storage | `fio`, sequential and random read and write | Homebrew build | Fedora package |

Optional: Geekbench 6 runs on both systems (CPU, and GPU compute with Metal or Vulkan). It uploads every result to its public website, and macOS on the M3 stays offline. Use it only if the user agrees.

## 4. Numbers so far

The "our stack" column is from the 22:49 run on the default boot (`STATUS.md`).

| Test | macOS | Linux, our stack | Linux, without the memory floor |
|---|---|---|---|
| CPU memory, 12 threads (GB/s) | 110.4 mean, 115.3 best | 108.6 mean, 113.7 best | 32.2 |
| CPU memory, 6 threads (GB/s) | 80.9 mean, 89.3 best (not pinned to P cores) | 126.2 mean (P cores) | 32.4 |
| GPU memory (GB/s) | Not measured | 131.4 mean | 31.1 |
| GPU compute (G pixel-iterations/s) | Not measured on the M3 (M5 host: 101.6) | 228.0 | Not measured |
| Llama 3.1 8B on the GPU, pp512 / tg128 (tokens/s) | Not measured | 149.97 / 22.72 | 124.97 / 5.76 |
| Llama 3.1 8B on the CPU, pp512 / tg128 (tokens/s) | Not measured | 71.40 / 24.50 | 66.58 / 6.59 |

The stock kernel has no GPU driver, so it has no GPU numbers. Its CPU memory speed is like the "without the memory floor" column, because it also sends no memory floor request.

## 5. Rules for a fair result

- Same source commit and same build options on both systems.
- Same model files. Compare the SHA-256 values in `~/llm-work/results/models.sha256`.
- Mac on power, lid open, nothing else running.
- Three runs for each test. Report the median.
- macOS stays offline.

## 6. Steps for the macOS run

1. On the M5 host, build the macOS programs: llama.cpp at the same commit with Metal and as a CPU-only build, `metal-stress`, `cpu-bw` and `7zz`. Set the macOS deployment target to 15.0.
2. In macOS on the M3, check the free space first. The partition work left macOS with a small margin. The two models need 6.9 GB, so copy and test one model at a time.
3. The coordinator session approves the restart: `sudo -n /usr/local/sbin/agx-os macos-once`, then reboot.
4. Copy the programs and models to the M3 over the local link. Run the tests.
5. Restart normally to go back to Fedora. Fedora stays the default.

Time: about 45 minutes, with two restarts.
