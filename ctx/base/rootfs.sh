#!/usr/bin/env bash

set -xeuo pipefail

: "${REL_VER:?REL_VER must be set}"

TARGET=/target-rootfs

# --- repositories ----------------------------------------------------------
dnf -y install dnf5-plugins
dnf -y copr enable @asahi/fedora-remix-branding
dnf -y install asahi-repos

# --- native dnf bootstrap --------------------------------------------------
mkdir -p "${TARGET}"

mapfile -t BASE_PACKAGES < <(grep -vE '^[[:space:]]*(#|$)' /ctx/base/packages.txt)

dnf -y \
    --installroot="${TARGET}" \
    --releasever="${REL_VER}" \
    --use-host-config \
    --setopt=install_weak_deps=False \
    --setopt=protect_running_kernel=False \
    --nodocs \
    install "${BASE_PACKAGES[@]}"

# --- repository configuration for derived/updated images -------------------
# mkdir -p "${TARGET}/etc/yum.repos.d" "${TARGET}/etc/pki/rpm-gpg"
# cp -a /etc/yum.repos.d/. "${TARGET}/etc/yum.repos.d/"
# cp -a /etc/pki/rpm-gpg/. "${TARGET}/etc/pki/rpm-gpg/"

# --- non-RPM content ( base/asahi ) ------------------------
cp -avf /ctx/base/ext/. "${TARGET}/"

# --- postprocessing --------------------------------------------------------
mkdir -p "${TARGET}/tmp"
install -m 0755 /ctx/base/postprocess.sh "${TARGET}/tmp/postprocess.sh"

for d in dev proc sys; do
    mkdir -p "${TARGET}/${d}"
    mount --rbind "/${d}" "${TARGET}/${d}"
done

cleanup_mounts() {
    for d in sys proc dev; do
        umount -R "${TARGET}/${d}" 2>/dev/null || umount -l "${TARGET}/${d}" 2>/dev/null || true
    done
}

trap cleanup_mounts EXIT

chroot "${TARGET}" /tmp/postprocess.sh

rm -f "${TARGET}/tmp/postprocess.sh"
cleanup_mounts
trap - EXIT
