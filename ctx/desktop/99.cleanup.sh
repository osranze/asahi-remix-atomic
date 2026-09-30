#!/usr/bin/env bash
#
# Stage 99: drop build-time state that must not ship in the image.
set -xeuo pipefail

rm -rf /boot/* /usr/etc
