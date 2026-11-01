#!/bin/bash
# Make the trackpad, mouse and keyboard feel like macOS (KDE Plasma 6 on Wayland). User level only.
# Usage: 70-input.sh            write the settings, then apply them live when a session runs
#        70-input.sh --offline  write the settings only
# Values come from a Mac (M5, macOS 26.7, defaults, read with ioreg on 2026-10-31):
#   key repeat delay 500 ms, repeat interval 83 ms (12 per second), double-click time 500 ms, tracking speed 0.6875 of the slider.
# Every number can be changed with the variables below or later with m3-input.
. "$(dirname "$0")/lib.sh"
OFFLINE=0; [ "${1:-}" = "--offline" ] && OFFLINE=1
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 70-input

TP_NAME="${TP_NAME:-Apple MTP multi-touch}"; TP_VENDOR="${TP_VENDOR:-1452}"; TP_PRODUCT="${TP_PRODUCT:-851}"
TP_SPEED="${TP_SPEED:-0.6}"            # -1 to 1. libinput adaptive curve. Mac default is about 0.69 of its own scale.
SCROLL_FACTOR="${SCROLL_FACTOR:-1.5}"  # 1 is libinput default. A Mac feels faster. Tune with: m3-input scroll 1.2
MOUSE_SPEED="${MOUSE_SPEED:-0.3}"
REPEAT_DELAY="${REPEAT_DELAY:-500}"    # ms
REPEAT_RATE="${REPEAT_RATE:-12}"       # per second
DOUBLE_CLICK_MS="${DOUBLE_CLICK_MS:-500}"

# Touchpad. Key names are the KWin libinput names (the same ones System Settings writes).
G=(Libinput "$TP_VENDOR" "$TP_PRODUCT" "$TP_NAME")
kwb kcminputrc NaturalScroll true "${G[@]}"
kwb kcminputrc TapToClick true "${G[@]}"
kwb kcminputrc TapAndDrag false "${G[@]}"          # macOS default: no tap-and-drag
kwb kcminputrc TapDragLock false "${G[@]}"
kwb kcminputrc LmrTapButtonMap false "${G[@]}"     # two-finger tap is a right click
kwb kcminputrc ClickMethodClickfinger true "${G[@]}"   # two-finger click is a right click, like macOS
kwb kcminputrc ClickMethodAreas false "${G[@]}"
kwb kcminputrc ScrollTwoFinger true "${G[@]}"
kwb kcminputrc ScrollEdge false "${G[@]}"
kwb kcminputrc DisableWhileTyping true "${G[@]}"
kwb kcminputrc PointerAccelerationProfileAdaptive true "${G[@]}"
kwb kcminputrc PointerAccelerationProfileFlat false "${G[@]}"
kw kcminputrc PointerAcceleration "$TP_SPEED" "${G[@]}"
kw kcminputrc ScrollFactor "$SCROLL_FACTOR" "${G[@]}"

# Keyboard repeat (read by KWin on Wayland)
kw kcminputrc KeyRepeat repeat Keyboard
kw kcminputrc RepeatDelay "$REPEAT_DELAY" Keyboard
kw kcminputrc RepeatRate "$REPEAT_RATE" Keyboard

# Double-click time, and double click to open files (Plasma opens with a single click by default)
kw kdeglobals DoubleClickInterval "$DOUBLE_CLICK_MS" KDE
kwb kdeglobals SingleClick false KDE
notify_change 3 || true

[ "$OFFLINE" = 1 ] && { say "Input settings written. Apply with a login, or run: m3-input apply"; exit 0; }
session_up || { say "No session. Settings are written and apply at the next login."; exit 0; }
"$HERE/m3-input" apply
