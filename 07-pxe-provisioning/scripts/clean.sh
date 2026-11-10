#!/usr/bin/env bash
# Remove both VMs and the firmware variable volume. Leaves the images and the
# Yocto caches alone.
set -euo pipefail
# shellcheck source=lib.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$LAB_DIR"
vagrant destroy -f
if virsh -c "$LIBVIRT_URI" vol-info --pool default "$VARS_VOLUME" >/dev/null 2>&1; then
	virsh -c "$LIBVIRT_URI" vol-delete --pool default "$VARS_VOLUME"
fi
echo "cleaned; images and caches are untouched"
