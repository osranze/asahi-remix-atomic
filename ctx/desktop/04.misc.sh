#!/usr/bin/env bash
#
# Stage 04: desktop integration tweaks, systemd presets and package manifest.
set -xeuo pipefail

. /ctx/desktop/lib/selinux-copyup.sh

# --- packages --------------------------------------------------------------
dnf -y --setopt=install_weak_deps=False --nodocs install \
    android-tools zig

# --- tweaks ----------------------------------------------------------------
printf 'NoDisplay=true\n' >> /usr/share/applications/panel-preferences.desktop

# Thunar's default "Open Terminal Here" action calls exo-open.
sed -i 's|exo-open --working-directory %f --launch TerminalEmulator|xdg-terminal-exec --dir=%f|' \
    /etc/xdg/Thunar/uca.xml

# Undo RPM scripts enabling units; the presets are authoritative.
rm -rf /etc/systemd/system/*
systemctl preset-all
rm -rf /etc/systemd/user/*
systemctl --user --global preset-all

# --- installed package manifest --------------------------------------------
{
    printf 'Package Arch Version Repository Size\n'
    dnf repoquery --installed \
        --qf '%{name} %{arch} %{evr} %{from_repo} %{installsize}\n' |
        sort | numfmt --field 5 --to=iec
} | column -t > /usr/share/installed_pkg_desktop.txt
