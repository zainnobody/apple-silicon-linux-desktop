#!/bin/bash
# Notifications as banners at the top right, under the menu bar, like macOS.
. "$(dirname "$0")/lib.sh"
[ "${DESIGN_NO_BACKUP:-0}" = 1 ] || backup 60-notifications
kw plasmanotifyrc PopupPosition TopRight Notifications
kw plasmanotifyrc PopupTimeout 6000 Notifications
kwb plasmanotifyrc CriticalPopupsKeepOnScreen true Notifications
say "Notifications set. Restart plasmashell or log in again to move existing popups."
