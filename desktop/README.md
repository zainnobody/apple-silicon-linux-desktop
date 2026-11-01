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
| 7 | `70-input.sh` | Trackpad, mouse and keyboard like macOS. Natural scrolling, tap to click, two-finger right click, key repeat 500 ms and 12 per second. Tune with `m3-input`. |
| 8 | `30-panels.sh` | Top bar (launcher, global menu, tray, clock). Floating centred dock with icons only and Trash. |

Switch the look later with `m3-appearance light` or `m3-appearance dark`.

## 16 inch fit (stage 90, optional)

`90-fit16.sh [SCALE]` sets the display scale to 2 (1728x1080 on the 3456x2160 panel), makes one flat gradient wallpaper for the desktop and the lock screen, and makes the dock 68 tall.
Undo the scale with `kscreen-doctor output.eDP-1.scale.2.7`. The other changes are in the backup.

## Lock screen (stage 80, optional, not part of apply-all.sh)

`80-lockscreen.sh` restyles the KDE lock screen: one flat colour, big clock, avatar, name, password field, a Touch ID hint. It has no blur, no shadow and no glass.
It needs no root. It does not change PAM, fprintd or the login screen. Fingerprint unlock keeps working the way PAM sets it up.

```bash
./80-lockscreen.sh build      # test packages only. The real lock screen does not change.
./80-lockscreen.sh test flat  # a test window for 20 seconds, no lock. Also: test stock
./80-lockscreen.sh install    # use it for real. Backup first.
./80-lockscreen.sh remove     # the stock lock screen is back
./80-lockscreen.sh colour '#0b3d91'   # or: image /path/to/file.png
```

In Plasma 6.7 the lock screen QML is part of the desktop shell package `org.kde.plasma.desktop`. `install` puts a full user copy of that package in
`~/.local/share/plasma/shells`. Plasma takes the user copy first. Only the `lockscreen` folder differs from the system package.
A guard script in `~/.config/plasma-workspace/env` removes the copy at login when the system package has changed (a Plasma update). The stock lock screen then comes back.
If the greeter cannot load the QML, Plasma falls back to its built-in locker. To get out of a stuck lock, run `loginctl unlock-session` over SSH.

Test windows need an unlocked session. A locked session gives blank screenshots.

The login screen (Plasma Login Manager) needs root. `root-options/plasmalogin-flat.sh` sets the same flat colour there. It is a draft and is not tested.

## Undo

Run the `*-undo.sh` of the stage in `~/desktop-design-backups/`. It restores the saved config files. Log out first, or run it from SSH.
`undo-10-themes.sh` removes the downloaded theme folders that stage 2 installed.

## Limits

- Cmd+C and Cmd+V need a key remap tool that needs root (for example keyd or kinto). This pack does not install one. A draft is in `root-options/keyd-cmd-as-ctrl.conf` (not applied, not tested).
- Two-finger swipe between pages has no system setting in KDE. It depends on the app.
- Dolphin has no column view. It has icons, compact and details.
- A Mac keyboard sends the Cmd key as Meta (Super) on Linux.
- The Plasma login screen is not changed. That needs root (see `root-options/plasmalogin-flat.sh`).
- The flat lock screen is a copy of a part of the Plasma shell. After a big Plasma update, run `80-lockscreen.sh install` again to see if it still fits.
