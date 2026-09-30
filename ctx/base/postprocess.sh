#!/usr/bin/env bash
#
# Postprocess the dnf-native base root filesystem.
set -xeuo pipefail

KERNEL_PREFIX="kernel-16k"

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

# Undo RPM scripts enabling units; the presets are authoritative.
# https://github.com/projectatomic/rpm-ostree/issues/1803
rm -rf /etc/systemd/system/*
systemctl preset-all
rm -rf /etc/systemd/user/*
systemctl --user --global preset-all

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

# SELinux - /nix/*
semodule -i /usr/share/selinux/custom/nix.pp

# dnf runs package scriptlets in a sandbox without /dev, /proc and /sys, so the
# systemd-udev trigger cannot compile the hardware database. Regenerate it here.
# `systemd-hwdb --usr` writes /usr/lib/udev/hwdb.bin; drop any /etc copy in its
# favour (the binaries are equivalent but mkosi keeps the /usr one only).
systemd-hwdb --usr update || echo "warning: systemd-hwdb update failed; hwdb.bin will be regenerated at boot"
rm -f /etc/udev/hwdb.bin

# initramfs
mkdir -p /var/roothome
dracut --reproducible -v -f "/usr/lib/modules/${KVER}/initramfs.img" --no-hostonly --kver "${KVER}"
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"
rm -rf /var/roothome

# Build-time state is recreated at runtime from tmpfiles.d/sysusers.
rm -rf /usr/etc /var/* /boot/*

# Normalize the rpm database into the bootc/ostree layout:
#   /usr/share/rpm          real directory holding the database
#   /usr/lib/sysimage/rpm   symlink to ../../share/rpm
#
# The rpm package ships /usr/lib/sysimage/rpm as a real directory, but
# `dnf --use-host-config` may resolve the builder's
# /usr/lib/sysimage/rpm -> ../../share/rpm compatibility symlink and end up
# writing the database to /usr/share/rpm instead, leaving both directories in
# place. Detect where the database actually is and normalize both cases.
RPM_MUT_DB="/usr/lib/sysimage/rpm-ostree-base-db"
RPM_DB="/usr/lib/sysimage/rpm"
RPM_OSTREE_DB="/usr/share/rpm"

if [ ! -f "${RPM_OSTREE_DB}/rpmdb.sqlite" ]; then
    if [ ! -f "${RPM_DB}/rpmdb.sqlite" ]; then
        printf 'Error: no rpm database found in %s or %s\n' "${RPM_DB}" "${RPM_OSTREE_DB}" >&2
        ls -la /usr/lib/sysimage /usr/share 2>/dev/null || true
        exit 1
    fi
    mkdir -p "${RPM_OSTREE_DB}"
    cp -a "${RPM_DB}/." "${RPM_OSTREE_DB}/"
fi

# Replace /usr/lib/sysimage/rpm with the compatibility symlink.
rm -rf "${RPM_DB}"
ln -s ../../share/rpm "${RPM_DB}"

# See: https://github.com/coreos/rpm-ostree/issues/4554
# https://forge.fedoraproject.org/atomic/tracker/issues/82
mkdir -p "${RPM_MUT_DB}"
for file in rpmdb.sqlite rpmdb.sqlite-shm rpmdb.sqlite-wal; do
    target="${RPM_OSTREE_DB}/${file}"
    link_path="${RPM_MUT_DB}/${file}"
    [ -e "${target}" ] || continue
    # Note, this needs to be a hardlink, not a symbolic link.
    ln -f "${target}" "${link_path}"
done

# https://gitlab.com/fedora/bootc/base-images/-/issues/28
ln -s ../run /var/run
# https://gitlab.com/fedora/bootc/tracker/-/issues/58
mkdir -p /var/lib/rpm-state
test -d /var/tmp || mkdir -m 1777 /var/tmp

# installed package manifest
{ printf "Package Arch Version Repository Size\n"
  dnf repoquery --installed --qf "%{name} %{arch} %{evr} %{from_repo} %{installsize}\n" \
  | sort | numfmt --field 5 --to=iec
} | column -t > /usr/share/installed_pkg_base.txt

# clean
find /target-rootfs/run/ -mindepth 1 -delete
find /target-rootfs/var/log/ -mindepth 1 -delete
