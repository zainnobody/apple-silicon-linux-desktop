# distro-pack

Apple silicon drivers for any Linux distro. One tool, `agx`, installs the boot parts, the kernel, the drivers, the GPU stack and an optional Mac-like desktop on Ubuntu, Debian, Kali, Fedora or Arch.

Status (2026-10-26): plan and verified results only. No code yet.

| File | Contents |
|---|---|
| `PLAN.md` | Goal, hard limits, chip coverage, layers, install paths, desktop, phases |
| `STATUS.md` | Newest verified results on the reference Mac: OpenGL, Vulkan, memory, llama.cpp |

Reference Mac: MacBook Pro 16-inch M3 Pro (J516S), Fedora Asahi Remix 44, kernel `7.2.11-m3gpu+`.

The working code is in the sibling repository `agx-linux-kit`: install stages, machine profiles, patches and tests. Phase 0 of the plan brings it here.

## Never in this repository

- Apple firmware. The Asahi installer copies it from each Mac's own macOS.
- Binaries of the M3 Mesa. Its license is not clear. The pack builds it on each Mac.
- Device tree dumps, serial numbers, ECIDs, network addresses or user names.

## License

Not chosen yet. The kernel, m1n1 and Mesa sources keep their own licenses.
