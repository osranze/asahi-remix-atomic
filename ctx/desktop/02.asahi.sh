#!/usr/bin/env bash
set -xeuo pipefail

dnf -y copr enable @asahi/fedora-remix-branding
dnf -y install asahi-repos

dnf -y install \
  asahi-platform-metapackage-audio \
  asahi-platform-metapackage-desktop \
  pipewire-alsa pipewire-v4l2 pipewire-pulseaudio pipewire-gstreamer pipewire-plugin-jack \
  pavucontrol playerctl
