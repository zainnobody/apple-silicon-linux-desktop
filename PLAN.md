# distro-pack: Apple silicon drivers for any Linux distro

Status: plan only (2026-10-26). Nothing is built yet. Nothing on the M3 was changed.

Code home: this repository. Phase 0 brings the stages, machine profiles, patches and tests from the sibling repository `agx-linux-kit` here.

## 1. Goal

- A person installs Ubuntu, Debian, Kali, Fedora or Arch on an Apple silicon Mac.
- They run one command. The pack installs the boot parts, the kernel, the drivers, the GPU stack and an optional Mac-like desktop.
- The same pack works on every distro family.
- The GPU is ready for heavy work: Vulkan compute, local LLMs, 3D.

## 2. Hard limits

This project cannot change these limits. The pack must say them clearly and refuse when they apply.

| Limit | Cause | Effect on the pack |
|---|---|---|
| Every install starts in macOS | Only macOS can make the stub partition and get Apple's signature for the boot entry | A USB stick on a bare Mac does not boot Linux. Step 1 is always the Asahi installer in macOS. |
| No M4 or M5 | The M4 boot environment changed. Asahi has no installer, no GPU driver and no date. | Refuse. The M5 host can run Linux only in a virtual machine. |
| No M3 Ultra (Mac Studio) | Asahi excludes it | Refuse. |
| Firmware cannot be shipped | It is Apple's code. The Asahi installer copies it from macOS to `/boot/efi/vendorfw`. | The pack only loads it. It never copies or uploads it. |
| The M3 Mesa cannot be shipped as binaries | The SiliconForest Mesa holds instruction tables from Apple's LLVM encoder. Their license is unclear. | The pack builds Mesa on the user's own Mac. |
| GPU firmware identity per machine | The M3 GPU driver admits only firmware builds that it knows | Each new board needs a test and a profile before the GPU turns on. An untested board gets a 2D desktop. |
| No sleep, Touch ID, iCloud, iMessage or AirDrop | No driver or no Linux version | Same on every distro. |

## 3. Chip coverage

| Chips | Base support | GPU | What the pack adds |
|---|---|---|---|
| M1 and M2 families | Asahi upstream (Fedora official, Ubuntu Asahi and Arch community) | Upstream Mesa, conformant OpenGL and Vulkan | Debian-family packages, the same desktop profile, the same `agx` tool |
| M3 Pro 16-inch (J516S) | Asahi, no GPU | SiliconForest kernel and Mesa plus our patches. Tested 2026-10-26. | Everything. This is the reference machine. |
| M3 Pro 14-inch (J514S) | Asahi, no GPU | The G15 driver names J514S. linux-aurora PR 202 fixed its GPU start. We did not test it. | A profile and one tester |
| M3 Max (T6031, T6034) | Asahi, no GPU | The G15 driver has a T6031 path (GPU data from the device tree). It has no T6034 path. Not tested. | Research first. 2D desktop until then. |
| M3 (T8122) | Asahi, no GPU | The G15 driver does not cover T8122 | Research first. 2D desktop until then. |
| M3 Ultra, M4, M5 | None | None | Refuse with a clear message |

The full table, one line per chip, is `data/socs.tsv`. Board lines that override it are in `data/boards.tsv`. `agx detect` reads both.

### Why one pack covers a chip family

Apple uses the same hardware blocks in many Macs. One Linux driver serves each block in every Mac that has it: the SSD controller, keyboard and trackpad, Wi-Fi and Bluetooth, speaker amplifiers, the system management controller and USB. Each Mac has its own device tree, which tells the kernel which blocks it has and where they are. The SiliconForest kernel tree has device trees for 44 Mac models, from the first M1 Macs to the M5 MacBook Air.

Some parts change with each chip generation:

- The GPU: M1, M2 and M3 each have a new GPU generation. M3 uses G15, and our GPU driver is for G15.
- The display controller firmware and the power management coprocessor.
- The boot environment. It changed with M4, so the Asahi installer cannot install Linux on M4 yet.

Some parts change from Mac to Mac in one generation:

- The device tree.
- The GPU firmware build. The driver admits only builds that it knows.
- The GPU board data: core count, memory areas, power states.

So the M3 Pro 14-inch is very close to the tested 16-inch: same SoC, same GPU firmware family. The M3 Max and M3 have the same GPU generation, but a different GPU size and different board data. They need a driver path and a test. A device tree in the kernel tree does not mean that the Mac is supported.

## 4. Layers

| Layer | Contents | Same on every distro? | How it ships |
|---|---|---|---|
| 1. Boot | m1n1 stage 2, U-Boot, device trees, in `boot.bin` on the EFI partition | Yes | Built per chip family |
| 2. Kernel | 16K-page kernel. M1 and M2: the Asahi kernel. M3: SiliconForest at a pinned commit plus our patches. | Yes | The kernel's own targets: `make bindeb-pkg` (.deb), `make binrpm-pkg` (.rpm), `make pacman-pkg` (Arch). Source = pinned commit + patches. |
| 3. Firmware loader | `asahi-scripts` (has dracut and mkinitcpio hooks) plus a new initramfs-tools hook for Debian, Ubuntu and Kali | Scripts yes, hook per initramfs system | Package |
| 4. Platform userspace | `asahi-audio`, `alsa-ucm-conf-asahi` (config files), `speakersafetyd`, `asahi-bless`, `asahi-nvram` (Rust) | Yes, from source | Built per distro family. Reuse the Ubuntu Asahi and asahi-alarm recipes. |
| 5. GPU | M1 and M2: the distro's Mesa. M3: SiliconForest Mesa built on the Mac into `/opt/mesa-agx`, turned on by the stage G selector. | Build per distro release | `agx build-mesa` |
| 6. Machine profiles | `machines/<board>.sh`, firmware pins, the T6030 memory floor | Yes | In the repo |
| 7. Desktop (optional) | Mac-like KDE profile (section 7) | Yes, KDE is on every distro | `agx desktop mac` |
| 8. Compute (optional) | llama.cpp on Vulkan, the GPU tests | Yes | `agx compute` |

The stage G selector already works with any desktop. It uses a systemd user environment generator and a linker cache entry. The login screen restart uses `display-manager`, so only `GREETER_USER` changes per login manager.

## 5. One tool: `agx`

| Command | What it does |
|---|---|
| `agx detect` | Reads the board, chip, firmware, distro family and initramfs system. Prints the plan. Refuses unsupported Macs. |
| `agx install` | Installs layers 1 to 6 with the distro's package manager. The stock kernel stays as the fallback boot. |
| `agx build-mesa` | M3 only. Builds Mesa on the Mac. |
| `agx desktop mac` | Applies the Mac-like desktop profile. |
| `agx status` / `agx undo` | Shows what is installed. Removes it. |

One backend file per distro family maps three jobs:

| Job | Debian family (Ubuntu, Debian, Kali) | Fedora | Arch |
|---|---|---|---|
| Install packages | apt | dnf | pacman |
| Update the boot menu | `update-grub` | `grub2-mkconfig` | `grub-mkconfig` |
| Build the initramfs | `update-initramfs` | `dracut` | `mkinitcpio` |

Stages A to K become steps inside `agx install`. Five scripts call Fedora tools today: `stage-a.sh`, `stage-b.sh`, `stage-f.sh`, `stage-k-default.sh` and `setup-macos-switch.sh`.

## 6. Install paths

### Path A: a fresh Mac (for other people)

1. In macOS, run the Asahi installer (Expert mode on M3). Pick "UEFI environment only (m1n1 + U-Boot + ESP)". The installer makes free space, the stub, the signed boot entry and the firmware copy.
2. Boot the pack's live USB (our kernel, the drivers and a small installer).
3. Pick a distro. The installer uses debootstrap or mmdebstrap for Ubuntu, Debian and Kali, `dnf --installroot` for Fedora, and `pacstrap` for Arch. It installs into the free space and runs `agx install`.

This is the method that the Asahi guidelines prefer for alternative distros. The UEFI entry has no chip limit and lists the 14.8.3 firmware, so it should appear on M3. Verify this on a real install.

### Path B: the Mac already runs Linux (this M3)

1. Make a new btrfs subvolume. Root has 425 GB free today. Or use the new partition from `docs/partition-resize.md`.
2. Install Ubuntu 26.04 arm64 into it with debootstrap.
3. In a chroot, run `agx install`. Add a GRUB entry. Fedora stays the default.

Undo: delete the subvolume and the GRUB entry.

### Path C: change an existing install

Example: Ubuntu Asahi on an M1. Add the pack repository and run `agx install`.

## 7. Mac-like, light desktop

Choice: KDE Plasma 6 on Wayland, on every distro.

- It is tested with the native GPU on the M3 (stage G).
- It is the desktop with the most settings, so the user can customize everything.
- Ubuntu (Kubuntu), Kali (`kali-desktop-kde`), Debian, Fedora and Arch all ship it. The desktop looks the same on every distro.

Profile contents:

| Mac feature | KDE setting |
|---|---|
| Menu bar | Top panel with the global menu and the clock |
| Dock | Floating bottom panel with app icons |
| Spotlight | KRunner on Meta+Space (the Cmd key is Meta) |
| Mission Control | Overview effect on a trackpad swipe |
| Cmd+C, Cmd+V and other shortcuts | Toshy (supports KDE on Wayland; not yet tested on Asahi or ARM) |
| Look | A community macOS-style theme (for example WhiteSur) and the Inter font |
| Trackpad | Natural scrolling, tap to click |
| AirDrop | LocalSend or KDE Connect |
| Apple-only tasks | `agx-os macos-once` starts macOS on the next boot |

Light settings: blur, background contrast and the wobbly and magic lamp effects off, fast animations. This keeps the GPU free for compute. Every item is a plain config file, so the user can change it.

Do not ship Apple fonts, icons or logos in a public pack.

## 8. GPU-heavy work

The newest numbers, with their dates and sources, are in `STATUS.md`.

| Works on the M3 Pro (tested) | Not available |
|---|---|
| OpenGL 4.6, GLES 3.2, Vulkan 1.4 | CUDA, ROCm, Metal |
| Vulkan compute with exact results | A usable PyTorch GPU backend |
| llama.cpp: Llama 3.1 8B at 22.7 tokens/s | Neural Engine (plan in `ane-linux`) |
| Memory 123 GB/s (CPU), 130 GB/s (GPU) with the T6030 floor patch | OpenCL (not tested) |

## 9. Before sharing with other people

- Remove the serial number, ECID, Tailscale address and user name from every document.
- Keep `private-dumps/` out of every repository.
- Choose a license for the scripts and documents. None is chosen yet.
- Kernel binaries are GPL: ship the pinned commit and the patches with them.
- Never ship M3 Mesa binaries or Apple firmware.
- A public GitHub repository or apt repository needs the user's go.

## 10. Phases

| Phase | Work | Done when | Needs the user |
|---|---|---|---|
| 0 | Backend files and `agx detect`. Stages A to K stop calling Fedora tools directly. | `agx detect` is correct on the M3 in Fedora. Scripts pass shellcheck. | No. Detect and backends done 2026-10-26 (correct on the M3, 12 of 12 tests, shellcheck clean). The stage port is next. |
| 1 | Kernel packages: .deb, .rpm and Arch from one tree | All three build. The .rpm installs on Fedora and boots. | One reboot |
| 2 | Ubuntu 26.04 on the M3 by Path B. initramfs-tools hook. Mesa build on Ubuntu. | Ubuntu boots on our kernel. GPU tests, Wi-Fi, Bluetooth, audio and keyboard pass. | Go for the subvolume, reboots |
| 3 | Kali by Path B | The same tests pass on Kali | Reboots |
| 4 | Mac-like desktop profile | One script gives the same desktop on Fedora, Ubuntu and Kali | Review the look |
| 5 | Live USB for Path A | A fresh install works from the UEFI environment | A test Mac or a spare partition |
| 6 | More boards: J514S first, then M1 and M2 packages | One tester per board passes the tests | Testers |
| 7 | Publish | After the privacy clean-up and a license | The user's go |

Other sessions also use the M3. The coordinator session approves reboots. Path B on a subvolume does not need the partition resize.

## Sources

- [Asahi M4 feature support](https://asahilinux.org/docs/platform/feature-support/m4/)
- [Linux Magazine: Asahi Linux runs into issues with M4 support](https://www.linux-magazine.com/Online/News/Asahi-Linux-Runs-into-Issues-with-M4-Support/(tagID)/39)
- [Phoronix: Asahi Linux officially supports M3](https://www.phoronix.com/news/Asahi-Linux-Official-M3)
- [Asahi guidelines for alternative distros](https://asahilinux.org/docs/alt/policy/)
- [asahi-installer (downstream variables)](https://github.com/AsahiLinux/asahi-installer)
- [asahi-installer-data (OS list)](https://github.com/AsahiLinux/asahi-installer-data)
- [asahi-scripts](https://github.com/AsahiLinux/asahi-scripts)
- [Ubuntu Asahi](https://github.com/UbuntuAsahi/ubuntu-asahi)
- [KDE Discuss: Toshy supports Wayland KDE](https://discuss.kde.org/t/toshy-v23-06-mac-like-per-app-keyboard-shortcuts-now-supports-wayland-kde/2380)
- Local: `agx-linux-kit/README.md`, `agx-linux-kit/docs/gpu-stack-review.md`, `agx-linux-kit/docs/gpu-firmware-investigation.md`, `docs/partition-resize.md`
