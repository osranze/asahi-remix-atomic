#!/usr/bin/env bash
set -xeuo pipefail

# i18n & Fonts
dnf -y --setopt=install_weak_deps=False --nodocs install \
  glibc-langpack-en glibc-langpack-zh \
  default-fonts-cjk-mono default-fonts-cjk-sans default-fonts-cjk-serif \
  default-fonts-core-emoji default-fonts-core-math default-fonts-core-mono default-fonts-core-sans default-fonts-core-serif \
  default-fonts-other-mono default-fonts-other-sans default-fonts-other-serif \
  aajohan-comfortaa-fonts adwaita-sans-fonts adwaita-mono-fonts cascadia-mono-nf-fonts \
  fontawesome-6-free-fonts fontawesome-6-brands-fonts open-sans-fonts terminus-fonts-console

# IME
dnf -y --setopt=install_weak_deps=False --nodocs install \
  fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-rime luajit

# Session & DM
dnf -y --setopt=install_weak_deps=False --nodocs install \
  polkit dbus-tools libsecret xdg-utils xdg-user-dirs xdg-terminal-exec \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
  uwsm greetd noctalia-greeter plymouth plymouth-system-theme \
  kmscon-gl kmscon-freetype kmscon-pango

# Wayland / Compositor 
dnf -y --setopt=install_weak_deps=False --nodocs install \
  umbriel-nightly noctalia xdg-desktop-portal-umbriel-nightly xwayland-satellite \
  wlr-randr kanshi

# Theming & Toolkit
dnf -y --setopt=install_weak_deps=False --nodocs install \
  qt6ct qt6-qtwayland qt5-qtwayland dconf nwg-look gtk-murrine-engine \
  bibata-cursor-theme papirus-icon-theme gtk3-theme-orchis gtk4-theme-orchis

# Desktop Utilities
dnf -y --setopt=install_weak_deps=False --nodocs install \
  fuzzel foot wl-clipboard cliphist wlogout \
  brightnessctl keyd tuned tuned-ppd tuned-switcher

# Apps
dnf -y --setopt=install_weak_deps=False --nodocs install \
  thunar thunar-volman thunar-archive-plugin xarchiver 7zip-standalone 7zip gvfs \
  chromium chromium-qt6-ui firefox firefox-langpacks keepassxc mpv imv
