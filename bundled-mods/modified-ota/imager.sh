set -e

if ! test "$#" -ge 1 -a -f "$1" ; then
	fatal "Invalid argument"
fi

OTA_PATH="$(mktemp -d)"
log "Extracting ota.zip to ${OTA_PATH}"
unzip -d "$OTA_PATH" "$1"

log "Flashing Kernel"
flash_mtd_partition kernel "${OTA_PATH}/boot.img"

log "Flashing System"
flash_mtd_partition rootfs "${OTA_PATH}/system.img"

# We do this to make sure we have enough space on temp to work on the sys image
log "Cleaning Up"
rm "${OTA_PATH}/boot.img"
rm "${OTA_PATH}/system.img"

log "Starting System Modification"
ROOTFS="$(begin_squashfs_edit 'rootfs')"

log "Replacing Stock Recovery"
rm "${ROOTFS}/boot/recovery.img"
dd if=/dev/mtdblock6 of="${ROOTFS}/boot/recovery.img" #Dirty but functional

log "Adding Busybox"
cp "./files/busybox" "${ROOTFS}/bin/"
chmod +x "${ROOTFS}/bin/busybox"

log "Enabling Telnet Access"
rm "${ROOTFS}/bin/sntpd"
echo -e '#!/bin/sh\n/system/bin/busybox telnetd -l /system/bin/sh\n' > "${ROOTFS}/bin/sntpd"

log "Enabling Startup Script Support"
echo -e 'if busybox test -f "/data/user_boot_script.sh"; then\n    /data/user_boot_script.sh &\nfi\n\n/bin/toolbox sntpd' >> "${ROOTFS}/bin/sntpd"
chmod +x "${ROOTFS}/bin/sntpd"

log "Enabling Custom DNS Server Support"
rm "${ROOTFS}/etc/dhcpcd/dhcpcd-hooks/20-dns.conf"
cp "./files/20-dns.conf" "${ROOTFS}/etc/dhcpcd/dhcpcd-hooks/20-dns.conf"
chmod 700 "${ROOTFS}/etc/dhcpcd/dhcpcd-hooks/20-dns.conf"

log "Done Editing, Writing Changes"
end_squashfs_edit "$ROOTFS"

log "OTA Complete!"