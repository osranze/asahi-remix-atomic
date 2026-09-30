#!/usr/bin/env bash
#
# Stage 05: regenerate the initramfs for the Asahi kernel.
set -xeuo pipefail

# --- altfiles --------------------------------------------------------------
install -m 0644 -o root -g root /etc/passwd /usr/lib/passwd
install -m 0644 -o root -g root /etc/group /usr/lib/group

# kernel-install must not run the Asahi m1n1 hook; bootc owns kernel installs.
:> /usr/lib/kernel/install.d/15-update-m1n1.install

# --- initramfs -------------------------------------------------------------
mkdir -p /var/roothome

kver=$(ls /usr/lib/modules | tail -n1)

# sed -i '/^    if ((sysloglvl > 0)) || ((kmsgloglvl > 0)); then$/i\    if ((kmsgloglvl > 0)) \&\& ! { [[ -w /dev/kmsg ]] \&\& echo -n "" > /dev/kmsg 2> /dev/null; }; then\n        kmsgloglvl=0\n    fi' /usr/lib/dracut/dracut-logger.sh
dracut --reproducible -v -f --no-hostonly --kver "${kver}" \
    "/usr/lib/modules/${kver}/initramfs.img"
chmod 0600 "/usr/lib/modules/${kver}/initramfs.img"

rm -rf /var/roothome
