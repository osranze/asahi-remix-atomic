#!/usr/bin/env bash
#
# Stage 01: third-party repositories and base desktop packages.
set -xeuo pipefail

# --- repositories ----------------------------------------------------------
dnf -y install --nogpgcheck \
    --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release terra-gpg-keys

dnf -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# --- packages --------------------------------------------------------------
dnf -y --setopt=install_weak_deps=False --nodocs install --allowerasing \
    ffmpeg

dnf -y install --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin \
    @multimedia

# --- payload ---------------------------------------------------------------
cp -avf /ctx/desktop/ext/. /
