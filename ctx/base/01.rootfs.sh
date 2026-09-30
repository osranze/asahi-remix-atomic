#!/usr/bin/env bash
#
# Stage 01: bootstrap the base root filesystem at /target-rootfs (host side).
set -xeuo pipefail

: "${REL_VER:?REL_VER must be set}"

target=/target-rootfs

# --- repositories ----------------------------------------------------------
dnf -y install dnf5-plugins
dnf -y copr enable @asahi/fedora-remix-branding
dnf -y install asahi-repos

# --- native dnf bootstrap --------------------------------------------------
mkdir -p "${target}"

mapfile -t base_packages < <(grep -vE '^[[:space:]]*(#|$)' /ctx/base/packages.txt)

dnf -y \
    --installroot="${target}" \
    --releasever="${REL_VER}" \
    --use-host-config \
    --setopt=install_weak_deps=False \
    --setopt=protect_running_kernel=False \
    --nodocs \
    install "${base_packages[@]}"

# --- repository configuration for derived/updated images -------------------
# mkdir -p "${target}/etc/yum.repos.d" "${target}/etc/pki/rpm-gpg"
# cp -a /etc/yum.repos.d/. "${target}/etc/yum.repos.d/"
# cp -a /etc/pki/rpm-gpg/. "${target}/etc/pki/rpm-gpg/"

# --- payload ---------------------------------------------------------------
cp -avf /ctx/base/ext/. "${target}/"

# --- postprocessing --------------------------------------------------------
mkdir -p "${target}/tmp"
install -m 0755 /ctx/base/02.postprocess.sh "${target}/tmp/postprocess.sh"

for d in dev proc sys; do
    mkdir -p "${target}/${d}"
    mount --rbind "/${d}" "${target}/${d}"
done

cleanup_mounts() {
    for d in sys proc dev; do
        umount -R "${target}/${d}" 2>/dev/null || umount -l "${target}/${d}" 2>/dev/null || true
    done
}

trap cleanup_mounts EXIT

chroot "${target}" /tmp/postprocess.sh

rm -f "${target}/tmp/postprocess.sh"
cleanup_mounts
trap - EXIT
