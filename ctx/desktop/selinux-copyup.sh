#!/usr/bin/env bash
set -xeuo pipefail

# https://github.com/tuna-os/tunaOS/issues/1562
# Force copy-up of /etc/selinux/targeted into the top layer so libsemanage's
# atomic directory renames (tmp -> active) succeed on overlayfs.
if [[ -d /etc/selinux/targeted ]]; then
	rm -rf /etc/selinux/targeted/tmp /etc/selinux/targeted/previous
	cp -a /etc/selinux/targeted /etc/selinux/targeted.copyup
	rm -rf /etc/selinux/targeted
	mv /etc/selinux/targeted.copyup /etc/selinux/targeted
fi
