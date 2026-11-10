#!/usr/bin/env bash
# Print the partition layout of the robot image, without booting anything.
# Works on the downloaded image or a freshly built one: it reads the same
# image the edge server serves and the installer writes to the disk. The
# fetched image is compressed, so it is decompressed to a temporary file
# first and removed afterwards.
set -euo pipefail
# shellcheck source=lib.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v sfdisk >/dev/null || die "need sfdisk (util-linux) to read the partition table"
command -v gzip >/dev/null || die "need gzip to decompress the image"

RAW="$IMAGES_DIR/fleet-robot-image-qemux86-64.rootfs.wic"
GZ="$IMAGES_DIR/fleet-robot-image-qemux86-64.rootfs.wic.gz"

tmp=""
cleanup() {
	if [ -n "$tmp" ]; then
		rm -rf "${tmp:?}"
	fi
}
trap cleanup EXIT

if [ -f "$RAW" ]; then
	IMAGE="$RAW"
elif [ -f "$GZ" ]; then
	tmp="$(mktemp -d)"
	echo "decompressing $(basename "$GZ") to a temporary file"
	gzip -dc "$GZ" > "$tmp/image.wic"
	IMAGE="$tmp/image.wic"
else
	die "no image at $RAW or $GZ; run scripts/fetch-images.sh, or scripts/build.sh first"
fi

echo
echo "image file: fleet-robot-image ($(du -h "$IMAGE" | cut -f1) decompressed)"
echo
(cd "$(dirname "$IMAGE")" && sfdisk -d "$(basename "$IMAGE")")
echo
echo "layout: boot (ESP), roota and rootb (the A/B slots, equal size), data (persistent)."
echo "The slots carry the same build; nothing writes slot B until the update machinery lands."
