# shellcheck shell=bash
# GRUB helpers for distros without Boot Loader Spec entries (Debian family and Arch).

GRUB_CFG="${GRUB_CFG:-/boot/grub/grub.cfg}"

# Menu id of the entry for kernel name $1 (the part after "vmlinuz-"), in the form that
# grub-reboot and grub-set-default take: "<submenu id>><entry id>". Empty if grub.cfg has none.
grub_entry_id() {
	local cfg
	cfg="$(agx_path "$GRUB_CFG")"
	[ -r "$cfg" ] || return 0
	awk -v k="$1" -v q="'" '
		/^submenu / {
			i = index($0, q "gnulinux-advanced-")
			if (i) { s = substr($0, i + 1); sub_id = substr(s, 1, index(s, q) - 1) }
		}
		{
			i = index($0, q "gnulinux-" k "-advanced-")
			if (i) {
				s = substr($0, i + 1)
				id = substr(s, 1, index(s, q) - 1)
				print (sub_id != "" ? sub_id ">" : "") id
				exit
			}
		}' "$cfg"
}

# grub-reboot and grub-set-default work only with GRUB_DEFAULT=saved.
# Also stops kernel updates from moving the default entry.
grub_use_saved() {
	local f
	f="$(agx_path /etc/default/grub)"
	if grep -qs '^GRUB_DEFAULT=saved$' "$f"; then
		return 0
	elif grep -qs '^GRUB_DEFAULT=' "$f"; then
		run sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub
	else
		echo 'GRUB_DEFAULT=saved' | append_file /etc/default/grub
	fi
}

# Show the GRUB menu for 5 seconds on every boot, so the distro kernel can be picked by hand.
grub_show_menu() {
	run sed -i -e 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' -e 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
}

grub_backup() { # <backup dir>
	local f
	for f in "$GRUB_CFG" /etc/default/grub /boot/grub/grubenv; do
		[ ! -e "$(agx_path "$f")" ] || run cp -a "$f" "$1/"
	done
}
