#!/usr/bin/env bash
# Check that this machine can run the lab. Prints every problem it finds.
set -uo pipefail
# shellcheck source=lib.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

problems=0
need() {
	echo "missing: $*" >&2
	problems=$((problems + 1))
}

for tool in vagrant virsh rsync curl sha256sum; do
	command -v "$tool" >/dev/null || need "$tool"
done

if command -v vagrant >/dev/null && ! vagrant plugin list | grep -q '^vagrant-libvirt '; then
	need "the vagrant-libvirt plugin (vagrant plugin install vagrant-libvirt)"
fi

if ! { [ -r /dev/kvm ] && [ -w /dev/kvm ]; }; then
	need "access to /dev/kvm (is KVM enabled, and are you in the kvm group?)"
fi
[ -f "$VARS_TEMPLATE" ] || need "OVMF variable template at $VARS_TEMPLATE (apt install ovmf, or set VARS_TEMPLATE)"
[ -f /usr/share/OVMF/OVMF_CODE_4M.fd ] || need "OVMF firmware /usr/share/OVMF/OVMF_CODE_4M.fd (apt install ovmf)"

if command -v virsh >/dev/null && ! virsh -c "$LIBVIRT_URI" list >/dev/null 2>&1; then
	need "access to libvirt at $LIBVIRT_URI (is libvirtd running, and are you in the libvirt group?)"
fi

if ! command -v docker >/dev/null && ! command -v podman >/dev/null; then
	echo "note: no docker or podman; fine if you only download the images, required to build them" >&2
fi

avail_gb=$(df --output=avail -BG "$LAB_DIR" | tail -1 | tr -dc '0-9')
if [ "${avail_gb:-0}" -lt 10 ]; then
	need "10 GB free next to the lab (only ${avail_gb}G); building the images needs about 50 GB"
fi

if [ "$problems" -gt 0 ]; then
	echo "$problems problem(s) found" >&2
	exit 1
fi
echo "prerequisites ok"
