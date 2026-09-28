#!/usr/bin/env bash
#
# Postprocess the dnf-native base root filesystem.
#
# This runs with `/` set to the freshly assembled target rootfs (via chroot) and
# reproduces what mkosi applies to the image:
#
#   * mkosi.profiles/base/mkosi.postinst.chroot
#   * mkosi.postinst.chroot            (preset canonicalization)
#   * mkosi.profiles/asahi/mkosi.postinst.chroot
#   * [Content] RemoveFiles=           (/usr/etc, /var/*, /boot/*)
#   * mkosi.profiles/base/mkosi.finalize.chroot
#   * mkosi.finalize.chroot            (installed package manifest)
#
# Note that the asahi `systemctl mask wpa_supplicant.service` has to run after
# the preset canonicalization, otherwise the mask created in /etc/systemd/system
# would be removed again.
set -xeuo pipefail

KERNEL_PREFIX="kernel-16k"

# --- mkosi base postinst ---------------------------------------------------
# nss-altfiles reads /usr/lib/{passwd,group}; seed them from the mutable files.
install -m 0644 -o root -g root /etc/passwd /usr/lib/passwd
install -m 0644 -o root -g root /etc/group  /usr/lib/group

# bootc owns updates instead of the image-fetching timer.
sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --quiet|' \
    /usr/lib/systemd/system/bootc-fetch-apply-updates.service

# bootupd-compatible bootloader update payload.
bootupctl backend generate-update-metadata

# Image-mode systems expect HOME below /var.
sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

# Move mutable state under /var and replace the top-level directories with
# symlinks, matching the bootc/ostree layout.
rm -rf /home /root /usr/local /srv /opt /mnt /boot /media
mkdir -p /boot /var /sysroot/ostree
ln -s sysroot/ostree /ostree
ln -sT var/home /home
ln -sT run/media /media
ln -sT var/mnt /mnt
ln -sT var/opt /opt
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT ../var/usrlocal /usr/local

# Keep /tmp on tmpfs (undoes the RHEL-only basic.target change).
mkdir -p /usr/lib/systemd/system/local-fs.target.wants
test -f /usr/lib/systemd/system/local-fs.target.wants/tmp.mount ||
    ln -sf ../tmp.mount /usr/lib/systemd/system/local-fs.target.wants

# systemd-tmpfiles does not follow symlinks; provision /root via /var/roothome.
# https://github.com/containers/bootc/issues/358
sed -i -e 's, /root, /var/roothome,' /usr/lib/tmpfiles.d/provision.conf
# /var/roothome is also defined in rpm-ostree-0-integration.conf.
sed -i -e '/^d- \/var\/roothome /d' /usr/lib/tmpfiles.d/provision.conf

# Workaround for https://issues.redhat.com/browse/RHEL-106203
rm -f /usr/lib/tmpfiles.d/home.conf

# --- mkosi.postinst.chroot: canonicalize presets ---------------------------
# Undo RPM scripts enabling units; the presets are authoritative.
# https://github.com/projectatomic/rpm-ostree/issues/1803
rm -rf /etc/systemd/system/*
systemctl preset-all
rm -rf /etc/systemd/user/*
systemctl --user --global preset-all

# --- mkosi asahi postinst --------------------------------------------------
# kernel-install must not run the Asahi m1n1 hook; bootc owns kernel installs.
:> /usr/lib/kernel/install.d/15-update-m1n1.install

# Drop every kernel that is not the 16k Asahi kernel.
readarray -t REMOVE_PKGS < <(
    rpm -qa --qf '%{NAME}\n' \
        | grep -E '^kernel(-|$)' \
        | grep -v -E "^${KERNEL_PREFIX}(-|$)" \
        | sort -u
)

if [ "${#REMOVE_PKGS[@]}" -gt 0 ]; then
    printf 'Remove:\n - %s\n' "${REMOVE_PKGS[@]}"
    rpm --erase "${REMOVE_PKGS[@]}" --nodeps
fi

KERNEL_COUNT=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ "${KERNEL_COUNT}" -ne 1 ]; then
    printf 'Error: expected exactly one kernel, found %s:\n' "${KERNEL_COUNT}"
    ls /usr/lib/modules
    exit 1
fi

KVER="$(ls /usr/lib/modules | tail -n1)"

sed -i "s|^DTBS=.*|DTBS=\"/usr/lib/modules/${KVER}/dtb\"|" /etc/sysconfig/update-m1n1

# iwd is the WiFi backend on Asahi.
systemctl mask wpa_supplicant.service

# --- SELinux customization -------------------------------------------------
semodule -i /usr/share/selinux/custom/nix.pp

# --- mkosi asahi postinst: initramfs ---------------------------------------
mkdir -p /var/roothome
dracut --reproducible -v -f "/usr/lib/modules/${KVER}/initramfs.img" --no-hostonly --kver "${KVER}"
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"
rm -rf /var/roothome

# --- [Content] RemoveFiles=/usr/etc /var/* /boot/* -------------------------
# Build-time state is recreated at runtime from tmpfiles.d/sysusers.
rm -rf /usr/etc /var/* /boot/*

# --- mkosi base finalize ---------------------------------------------------
RPM_MUT_DB="/usr/lib/sysimage/rpm-ostree-base-db"
RPM_DB="/usr/lib/sysimage/rpm"
RPM_OSTREE_DB="/usr/share/rpm"

mkdir -p "${RPM_MUT_DB}"
mv -T "${RPM_DB}" "${RPM_OSTREE_DB}"
ln -srf "${RPM_OSTREE_DB}" "${RPM_DB}"

# See: https://github.com/coreos/rpm-ostree/issues/4554
# https://forge.fedoraproject.org/atomic/tracker/issues/82
for file in rpmdb.sqlite rpmdb.sqlite-shm rpmdb.sqlite-wal; do
    target="${RPM_DB}/${file}"
    link_path="${RPM_MUT_DB}/${file}"
    # Note, this needs to be a hardlink, not a symbolic link.
    ln -f "${target}" "${link_path}"
done

# https://gitlab.com/fedora/bootc/base-images/-/issues/28
ln -s ../run /var/run
# https://gitlab.com/fedora/bootc/tracker/-/issues/58
mkdir -p /var/lib/rpm-state
test -d /var/tmp || mkdir -m 1777 /var/tmp

# --- mkosi.finalize.chroot: installed package manifest ---------------------
dnf repoquery --installed --qf "%{name} %{installsize}\n" | numfmt --field 2 --to=iec > /usr/share/installed_pkg.txt
