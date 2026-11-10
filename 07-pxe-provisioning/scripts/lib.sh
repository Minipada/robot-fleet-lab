#!/usr/bin/env bash
# Shared settings for the lab scripts. Source it; do not run it.
# shellcheck disable=SC2034

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="$LAB_DIR/build/tmp/deploy/images/qemux86-64"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
VARS_VOLUME="fleet-robot_VARS.fd"
VARS_TEMPLATE="${VARS_TEMPLATE:-/usr/share/OVMF/OVMF_VARS_4M.fd}"
ROBOT_DOMAIN="07-pxe-provisioning_robot"
RELEASE_TAG="${RELEASE_TAG:-07-images-v1}"
RELEASE_URL="https://github.com/Minipada/robot-fleet-lab/releases/download/$RELEASE_TAG"

# The four files the edge server serves, named as the Yocto build names them.
IMAGE_FILES=(
	bzImage
	fleet-installer-image-qemux86-64.rootfs.cpio.gz
	fleet-robot-image-qemux86-64.rootfs.wic.gz
	fleet-robot-image-qemux86-64.rootfs.wic.bmap
)

die() {
	echo "error: $*" >&2
	exit 1
}
