#!/bin/bash
# Needs root. Not run by apply-all.sh. Usage: sudo ./plasmalogin-flat.sh install|remove
# install: backs up nothing (it adds one new file). remove: deletes that file.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST=/etc/plasmalogin.conf.d/60-m3-flat.conf
case "${1:-}" in
install) install -D -m 0644 "$HERE/plasmalogin-flat.conf" "$DEST"; echo "Installed $DEST. Log out to see it." ;;
remove) rm -f "$DEST"; echo "Removed $DEST." ;;
*) echo "Usage: sudo $0 install|remove"; exit 2 ;;
esac
