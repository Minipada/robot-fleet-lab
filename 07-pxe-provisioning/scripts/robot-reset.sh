#!/usr/bin/env bash
# Put the robot back to "blank disk, factory firmware settings". Run it once
# before the first `vagrant up robot`, and again before every repeat install.
set -euo pipefail
# shellcheck source=lib.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ -f "$VARS_TEMPLATE" ] || die "no OVMF variable template at $VARS_TEMPLATE"

cd "$LAB_DIR"
vagrant destroy -f robot

if ! virsh -c "$LIBVIRT_URI" vol-info --pool default "$VARS_VOLUME" >/dev/null 2>&1; then
	size="$(stat -c %s "$VARS_TEMPLATE")"
	virsh -c "$LIBVIRT_URI" vol-create-as default "$VARS_VOLUME" "$size" --format raw
fi
virsh -c "$LIBVIRT_URI" vol-upload --pool default "$VARS_VOLUME" "$VARS_TEMPLATE"
echo "robot reset; start it with: vagrant up robot"
