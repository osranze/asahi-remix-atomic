#!/usr/bin/env bash
set -xeuo pipefail

sed -i "s|enabled=1|enabled=0|" /etc/yum.repos.d/fedora-cisco-openh264.repo

dnf -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release terra-gpg-keys

dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf -y --setopt=install_weak_deps=False --nodocs install --allowerasing \
  ffmpeg
dnf -y install @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

cp -avf "/ctx/desktop/ext"/. /
