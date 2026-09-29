#!/usr/bin/env bash
set -xeuo pipefail

. /ctx/desktop/selinux-copyup.sh

dnf -y --setopt=install_weak_deps=False --nodocs install \
  android-tools zig

printf "NoDisplay=true\n" >> /usr/share/applications/panel-preferences.desktop

# Thunar's default "Open Terminal Here" action calls
sed -i 's|exo-open --working-directory %f --launch TerminalEmulator|xdg-terminal-exec --dir=%f|' \
    /etc/xdg/Thunar/uca.xml

rm -rf /etc/systemd/system/*
systemctl preset-all
rm -rf /etc/systemd/user/*
systemctl --user --global preset-all

dnf repoquery --installed --qf "%{name} %{installsize}\n" | numfmt --field 2 --to=iec > /usr/share/installed_pkg_desktop.txt
