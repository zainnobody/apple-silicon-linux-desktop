#!/bin/bash
# Back up user-level desktop config to a dated tarball and write an undo script.
# Usage: backup.sh [label]   (no root needed)
set -eu
LABEL="${1:-desktop}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DIR="${DESIGN_BACKUP_DIR:-$HOME/desktop-design-backups}"
mkdir -p "$DIR"
TAR="$DIR/$STAMP-$LABEL.tar.gz"
cd "$HOME"
LIST=()
for p in .config .local/share/plasma .local/share/plasma_icons .local/share/plasmashell .local/share/konsole \
         .local/share/kxmlgui5 .local/share/color-schemes .local/share/dolphin .local/share/aurorae \
         .local/share/icons .local/share/fonts .local/share/user-places.xbel; do
  [ -e "$p" ] && LIST+=("$p")
done
# Skip big caches inside .config that do not hold settings.
tar -czf "$TAR" --warning=no-file-changed \
  --exclude='.config/google-chrome' --exclude='.config/chromium' --exclude='.config/mozilla' \
  --exclude='.config/Code' --exclude='.config/*/Cache' --exclude='.config/*/cache' \
  "${LIST[@]}" || [ $? -eq 1 ]
UNDO="$DIR/$STAMP-$LABEL-undo.sh"
cat > "$UNDO" <<UNDOEOF
#!/bin/bash
# Undo: restore the config saved in $TAR
# Log out of the desktop first (or run from a text console / SSH), then log in again.
set -eu
cd "\$HOME"
pkill -u "\$USER" plasmashell 2>/dev/null || true
tar -xzf "$TAR" -C "\$HOME"
echo "Restored $TAR. Log in again."
UNDOEOF
chmod +x "$UNDO"
sha256sum "$TAR" > "$TAR.sha256"
echo "$TAR"
echo "$UNDO"
