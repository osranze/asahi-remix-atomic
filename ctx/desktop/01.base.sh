#!/usr/bin/env bash
set -xeuo pipefail

sed -i "s|enabled=1|enabled=0|" /etc/yum.repos.d/fedora-cisco-openh264.repo

dnf -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release terra-release-multimedia terra-gpg-keys

cp -avf "/ctx/desktop/ext"/. /
