# Mac-like desktop for KDE Plasma 6 (distro-pack phase 4)

Goal: the desktop looks and feels like macOS Sonoma and Sequoia. It is flat. It has no blur, no see-through panels and no glass.
These scripts work at user level. They need no root and install no package.

## What you need first

- KDE Plasma 6 on Wayland. Tested on Fedora Asahi Remix 44 (Plasma 6.7.5).
- Fonts: Adwaita Sans and Hack are in Fedora. On other distros install Inter (or keep Adwaita Sans) and Hack. SF Pro cannot be shipped.
- `git`, `kwriteconfig6`, `plasma-apply-*` tools (part of Plasma).
- Network, one time: `fetch-themes.sh` downloads three GPL-3.0 repositories at pinned commits (about 180 MB).

## Run

```bash
./apply-all.sh light      # or dark
```

Each stage makes a dated backup and an undo script in `~/desktop-design-backups/` first. The panel stage needs a running Plasma session.
Close Dolphin and Konsole before stage 50.

| Stage | File | What it does |
|---|---|---|
| 0 | `backup.sh LABEL` | Backs up `~/.config` and the KDE data folders. Writes `*-undo.sh`. |
| 1 | `fetch-themes.sh` | Downloads WhiteSur-kde, WhiteSur-icon-theme and WhiteSur-cursors at pinned commits. |
| 2 | `10-themes.sh` | Copies the flat parts: opaque window decoration, a solid Plasma theme, colour schemes, icons, cursors. Runs no upstream script. |
| 3 | `20-appearance.sh [light\|dark]` | Fonts, colours, icons, cursor, window buttons on the left (close, minimize, zoom). |
| 4 | `40-search-and-overview.sh` | Meta+Space opens KRunner in the middle of the screen. Blur, wobbly windows and magic lamp are off. |
| 5 | `50-apps.sh` | Dolphin like Finder. Konsole like Terminal.app (Basic and Pro looks). |
| 6 | `60-notifications.sh` | Banners at the top right. |
| 7 | `30-panels.sh` | Top bar (launcher, global menu, tray, clock). Floating centred dock with icons only and Trash. |

Switch the look later with `m3-appearance light` or `m3-appearance dark`.

## Undo

Run the `*-undo.sh` of the stage in `~/desktop-design-backups/`. It restores the saved config files. Log out first, or run it from SSH.
`undo-10-themes.sh` removes the downloaded theme folders that stage 2 installed.

## Limits

- Cmd+C and Cmd+V need a key remap tool that needs root (for example keyd or kinto). This pack does not install one.
- Dolphin has no column view. It has icons, compact and details.
- A Mac keyboard sends the Cmd key as Meta (Super) on Linux.
- SDDM or the Plasma login screen is not changed. That needs root.
